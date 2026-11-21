defmodule ChoirCoach.Audio.Native.Io do
  @moduledoc """
  The engine's streams and decodes: one process, started by `ChoirCoach.App`,
  that owns the `mob_audio_io` output and input streams and the file decodes
  under the `choir_audio` NIF's processors, and makes the NIF calls that
  start or stop something on the holder's behalf. Being one process, it
  serializes them: a load closes the output and lets the last load's
  decodes end before the NIF frees what they used, and no stream opens for
  a holder that has just lost the engine.

  `ChoirCoach.Audio.Native` calls it; the frequent calls (position, mix,
  readings, pause) go to the NIF directly.

  The streams:

    * Output (`"choir_out"`): opened at the tracks' rate on `play`, kept open
      through a pause (a play right after starts at once) and closed once
      it has been paused 3 s, so nothing runs in the background. A load,
      a release or the engine changing hands closes it. Android plays on
      the preferred output (`set_output`), falling back to the system's; iOS
      routes itself, and only the speaker can be chosen (an override,
      applied again at every play).
    * Input (`"choir_mic"`, the plugin's default preset: Android's
      VOICE_RECOGNITION, iOS's default mode): open while listening to the
      microphone, on the preferred input.
    * Decodes: a source file each, chunks into `"choir_src<i>"`. Their end
      tells the NIF (`source_done/2`, `load_failed/2`).

  What the plugin reports becomes what the engine always did: a lost
  output device, an interruption or a media-services reset pauses where the
  music was heard (the next play reopens); iOS headphones unplugged (a route
  losing its device, from `ChoirCoach.Ios`) pause too. A microphone that
  goes with its device sends the listener `:mic_error` `:disconnected`;
  one interrupted, reset or failing to reopen, `:input_error`.
  """

  use GenServer

  require Logger

  alias ChoirCoach.Audio.Native

  @decode_end_ms 5_000
  @call_ms 15_000
  @ends [:decode_done, :decode_cancelled, :decode_error]

  defstruct platform: :android,
            out: nil,
            out_rate: nil,
            out_device: nil,
            out_pref: nil,
            in: nil,
            in_pref: nil,
            decodes: %{},
            idle: nil

  @doc false
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc false
  def child_spec(opts), do: %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}

  def acquire(force), do: call({:acquire, self(), force})
  def release, do: call({:release, self()})
  def load(sources, guide), do: call({:load, self(), sources, guide})
  def play(from_ms), do: call({:play, self(), from_ms})

  @doc "Pause (the holder, directly), then let the output close once idle."
  def pause do
    with :ok <- Native.nif().pause() do
      GenServer.cast(__MODULE__, :paused)
      :ok
    end
  end

  def listen(source), do: call({:listen, self(), source})
  def stop_listening, do: call({:stop_listening, self()})
  def set_output(id), do: call({:set_output, self(), id})
  def set_input(id), do: call({:set_input, self(), id})
  def output_device, do: call(:output_device)

  @doc "The open streams' `MobAudioIo.status/1` (nil when closed)."
  def streams, do: call(:streams)

  defp call(request), do: GenServer.call(__MODULE__, request, @call_ms)

  # ── Server ──────────────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    :ok = Native.nif().attach(self())
    platform = Native.platform()
    if platform == :ios, do: Native.ios().watch_route(self())
    {:ok, %__MODULE__{platform: platform}}
  end

  @impl true
  def handle_call({:acquire, pid, force}, _from, state) do
    case Native.nif().acquire(pid, force) do
      {:ok, epoch, true} -> {:reply, {:ok, epoch}, stop_all(state)}
      {:ok, epoch, false} -> {:reply, {:ok, epoch}, state}
      {:error, :busy} = busy -> {:reply, busy, state}
    end
  end

  def handle_call({:release, pid}, _from, state) do
    case Native.nif().release(pid) do
      {:ok, true} -> {:reply, :ok, stop_all(state)}
      {:ok, false} -> {:reply, :ok, state}
    end
  end

  def handle_call({:load, pid, sources, guide}, _from, state) do
    nif = Native.nif()

    with {:ok, _, _} <- nif.listening(pid),
         :ok <- nif.stop_listening(pid) do
      state = state |> close_input() |> close_output() |> end_decodes()

      case nif.load(pid, Enum.map(sources, &elem(&1, 1)), guide) do
        {:ok, generation} -> {:reply, {:ok, generation}, decode(state, sources, generation)}
        error -> {:reply, error, state}
      end
    else
      error -> {:reply, error, state}
    end
  end

  # The NIF plays once the stream runs; a stream (re)opened for it plays
  # from the same place again (closing one under the music pauses it).
  def handle_call({:play, pid, from_ms}, _from, state) do
    nif = Native.nif()

    with {:ok, rate} <- nif.play(pid, from_ms) do
      state = cancel_idle(state)

      case ensure_output(state, rate) do
        {:ok, ^state} ->
          {:reply, :ok, state}

        {:ok, state} ->
          {:reply, replay(nif.play(pid, from_ms)), state}

        {:error, state} ->
          nif.halt()
          {:reply, {:error, :output_unavailable}, state}
      end
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:listen, pid, source}, _from, state) do
    nif = Native.nif()

    with {:ok, _, _} <- nif.listening(pid),
         :ok <- nif.stop_listening(pid) do
      state = close_input(state)

      case listen(state, pid, source) do
        {:ok, number, state} -> {:reply, {:ok, number}, state}
        {:error, reason, state} -> {:reply, {:error, reason}, state}
      end
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:stop_listening, pid}, _from, state) do
    case Native.nif().stop_listening(pid) do
      :ok -> {:reply, :ok, close_input(state)}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:set_input, pid, id}, _from, state) do
    nif = Native.nif()

    case nif.listening(pid) do
      {:ok, :mic, _} ->
        :ok = nif.stop_listening(pid)
        state = close_input(%{state | in_pref: id})

        case listen(state, pid, :mic) do
          {:ok, number, state} -> {:reply, {:ok, number}, state}
          {:error, reason, state} -> {:reply, {:error, reason}, state}
        end

      {:ok, _source, number} ->
        {:reply, {:ok, number}, %{state | in_pref: id}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:set_output, pid, id}, _from, state) do
    case Native.nif().listening(pid) do
      {:ok, _, _} -> {:reply, :ok, move_output(%{state | out_pref: id}, pid)}
      error -> {:reply, error, state}
    end
  end

  def handle_call(:output_device, _from, %{platform: :ios, out_device: nil} = state),
    do: {:reply, nil, state}

  def handle_call(:output_device, _from, %{platform: :ios} = state),
    do: {:reply, Native.route_output_id(), state}

  def handle_call(:output_device, _from, state), do: {:reply, state.out_device, state}

  def handle_call(:streams, _from, state),
    do: {:reply, %{output: stream_status(state.out), input: stream_status(state.in)}, state}

  @impl true
  def handle_cast(:paused, state), do: {:noreply, close_when_idle(state)}

  @impl true
  def handle_info({:idle_close, ref}, %{idle: ref} = state) do
    state = %{state | idle: nil}
    if Native.nif().playing(), do: {:noreply, state}, else: {:noreply, close_stream(state, :out)}
  end

  def handle_info({:idle_close, _stale}, state), do: {:noreply, state}

  # The output: a lost device, an interruption, a reset or a reopen that
  # failed pauses where it was heard and closes it (the next play reopens).
  def handle_info({:mob_audio_io, kind, id, info}, %{out: id} = state)
      when kind in [:device_lost, :interrupted, :error] or
             (kind == :route_changed and info.reason == :media_reset) do
    Logger.warning("[choir_audio] output #{kind}: #{inspect(info)}; paused")
    Native.nif().halt()
    {:noreply, %{close_output(state) | out_device: nil}}
  end

  def handle_info({:mob_audio_io, :started, id, _info}, %{out: id} = state),
    do: {:noreply, %{state | out_device: device_of(state, id)}}

  # The microphone: its loss ends the listening with a mic_error.
  def handle_info({:mob_audio_io, kind, id, info}, %{in: id} = state)
      when kind in [:device_lost, :interrupted, :error] or
             (kind == :route_changed and info.reason == :media_reset) do
    reason = if kind == :device_lost, do: :disconnected, else: :input_error
    Logger.warning("[choir_audio] microphone #{kind}: #{inspect(info)}")
    Native.nif().mic_failed(reason)
    {:noreply, close_input(state)}
  end

  def handle_info({:mob_audio_io, :decode_done, decode, _info}, state) do
    case Map.pop(state.decodes, decode) do
      {{generation, index}, decodes} ->
        Native.nif().source_done(generation, index)
        {:noreply, %{state | decodes: decodes}}

      {nil, _} ->
        {:noreply, state}
    end
  end

  def handle_info({:mob_audio_io, :decode_error, decode, info}, state) do
    case Map.pop(state.decodes, decode) do
      {{generation, index}, decodes} ->
        Logger.warning("[choir_audio] source #{index} failed: #{inspect(info)}")
        Native.nif().load_failed(generation, load_error(info.reason))
        {:noreply, cancel_decodes(%{state | decodes: decodes}, generation)}

      {nil, _} ->
        {:noreply, state}
    end
  end

  def handle_info({:mob_audio_io, :decode_cancelled, decode, _info}, state),
    do: {:noreply, %{state | decodes: Map.delete(state.decodes, decode)}}

  # A source failed in the NIF (rates that differ, no memory): the others stop.
  def handle_info({:choir_audio_io, :load_failed, generation}, state),
    do: {:noreply, cancel_decodes(state, generation)}

  # iOS: the route lost its device (headphones unplugged, Bluetooth gone):
  # pause where it was heard rather than go on out loud, and end a
  # listening whose microphone went with it.
  def handle_info({:choir_ios, :route_lost, input_gone}, state) do
    Logger.info(
      "[choir_audio] the route lost its device#{if input_gone, do: " and its microphone"}"
    )

    {_was_playing, _ms} = Native.nif().halt()
    state = close_when_idle(state)

    if input_gone and state.in != nil do
      Native.nif().mic_failed(:disconnected)
      {:noreply, close_input(state)}
    else
      {:noreply, state}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  # ── Streams ─────────────────────────────────────────────────────────────

  defp stop_all(state) do
    state
    |> close_input()
    |> close_output()
    |> cancel_decodes(:all)
    |> Map.put(:out_device, nil)
  end

  defp close_output(state),
    do: state |> cancel_idle() |> close_stream(:out) |> Map.put(:out_device, nil)

  defp close_input(state), do: close_stream(state, :in)

  defp close_stream(state, key) do
    case Map.fetch!(state, key) do
      nil ->
        state

      id ->
        _ = MobAudioIo.close(id)
        Map.put(state, key, nil)
    end
  end

  # Paused: the output closes if it is still paused in 3 s.
  defp close_when_idle(%{out: nil} = state), do: state

  defp close_when_idle(state) do
    ref = make_ref()

    Process.send_after(
      self(),
      {:idle_close, ref},
      Application.get_env(:choir_coach, :audio_idle_ms, 3_000)
    )

    %{state | idle: ref}
  end

  defp cancel_idle(state), do: %{state | idle: nil}

  defp replay({:ok, _rate}), do: :ok
  defp replay(error), do: error

  defp ensure_output(%{out: id, out_rate: rate} = state, rate) when id != nil do
    apply_route(state)
    {:ok, state}
  end

  defp ensure_output(state, rate) do
    state = close_stream(state, :out)

    case open_output(state, rate) do
      {:ok, id} ->
        state = %{state | out: id, out_rate: rate, out_device: device_of(state, id)}
        apply_route(state)
        {:ok, state}

      {:error, reason} ->
        Logger.warning("[choir_audio] output open failed: #{inspect(reason)}")
        {:error, %{state | out_device: nil}}
    end
  end

  # On the preferred device, else (gone, refused) on the system's.
  defp open_output(state, rate) do
    opts = [
      processor: "choir_out",
      module: Native.nif(),
      rate: rate,
      channels: 2,
      session: :play_and_record,
      buffer: buffer(state.platform, rate)
    ]

    with {:error, reason} <- open(:output, opts, device(state, :out)) do
      if device(state, :out), do: open(:output, opts, nil), else: {:error, reason}
    end
  end

  defp open_input(state) do
    opts = [
      processor: "choir_mic",
      module: Native.nif(),
      input_channels: 1,
      preset: :default,
      buffer: buffer(state.platform, nil)
    ]

    with {:error, reason} <- open(:input, opts, device(state, :in)) do
      if device(state, :in), do: open(:input, opts, nil), else: {:error, reason}
    end
  end

  defp open(direction, opts, nil), do: MobAudioIo.open(self(), direction, opts)

  defp open(direction, opts, device),
    do: MobAudioIo.open(self(), direction, [{:device, device} | opts])

  # iOS: the 10 ms IO buffer the engine always asked for (the plugin's low
  # latency is 5 ms); Android: the plugin's low latency (two bursts, grown
  # after an underrun).
  defp buffer(:ios, rate), do: {:frames, div(rate || 48_000, 100)}
  defp buffer(_platform, _rate), do: :low_latency

  # The plugin's device for a preference: an Android device id; on iOS an
  # input's port UID (the output can't be chosen there).
  defp device(%{platform: :ios, in_pref: pref}, :in), do: Native.ios_port(pref)
  defp device(%{platform: :ios}, :out), do: nil
  defp device(state, :in), do: state.in_pref
  defp device(state, :out), do: state.out_pref

  defp device_of(%{platform: :ios}, _id), do: :route

  defp device_of(_state, id) do
    case MobAudioIo.status(id) do
      %{device_id: device} when is_integer(device) and device > 0 -> device
      _ -> nil
    end
  end

  # iOS clears the speaker override on route changes and interruptions:
  # set it again at every play.
  defp apply_route(%{platform: :ios} = state) do
    case Native.ios().set_speaker(state.out_pref == Native.speaker_id()) do
      :ok -> :ok
      {:error, detail} -> Logger.warning("[choir_audio] speaker override failed: #{detail}")
    end
  end

  defp apply_route(_state), do: :ok

  # A new preferred output. iOS: the override, at once. Android: an open
  # stream reopens there, playing again where it was heard if it was.
  defp move_output(%{platform: :ios} = state, _pid) do
    apply_route(state)
    state
  end

  defp move_output(%{out: nil} = state, _pid), do: state

  defp move_output(state, pid) do
    {was_playing, ms} = Native.nif().halt()
    rate = state.out_rate
    state = close_stream(state, :out)

    case ensure_output(state, rate) do
      {:ok, state} ->
        if was_playing, do: Native.nif().play(pid, ms)
        state

      {:error, state} ->
        state
    end
  end

  defp listen(state, pid, :mic) do
    case open_input(state) do
      {:ok, id} ->
        state = %{state | in: id}

        case Native.nif().listen(pid, :mic) do
          {:ok, number} -> {:ok, number, state}
          {:error, reason} -> {:error, reason, close_input(state)}
        end

      {:error, reason} ->
        Logger.warning("[choir_audio] microphone open failed: #{inspect(reason)}")
        {:error, :microphone_unavailable, state}
    end
  end

  defp listen(state, pid, :playback) do
    case Native.nif().listen(pid, :playback) do
      {:ok, number} -> {:ok, number, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp stream_status(nil), do: nil

  defp stream_status(id) do
    case MobAudioIo.status(id) do
      %{} = status -> status
      _ -> nil
    end
  end

  # ── Decodes ─────────────────────────────────────────────────────────────

  defp decode(state, sources, generation) do
    sources
    |> Enum.with_index()
    |> Enum.reduce_while(state, fn {{path, _channels}, index}, state ->
      opts = [processor: "choir_src#{index}", module: Native.nif()]

      case MobAudioIo.decode_stream(path, self(), opts) do
        {:ok, decode} ->
          {:cont, %{state | decodes: Map.put(state.decodes, decode, {generation, index})}}

        {:error, reason} ->
          Logger.warning("[choir_audio] decode #{Path.basename(path)} failed: #{inspect(reason)}")
          Native.nif().load_failed(generation, load_error(reason))
          {:halt, cancel_decodes(state, generation)}
      end
    end)
  end

  # The NIF's load_error reasons, as the engine always gave them.
  defp load_error(reason) when reason in [:not_found, :unsupported, :no_audio, :decode_error],
    do: reason

  defp load_error(:no_memory), do: :alloc
  defp load_error(:busy), do: :thread
  defp load_error({reason, _detail}), do: load_error(reason)
  defp load_error(_reason), do: :decode_error

  defp cancel_decodes(state, generation) do
    for {decode, {gen, _}} <- state.decodes, generation == :all or gen == generation do
      MobAudioIo.decode_cancel(decode)
    end

    state
  end

  # Before a load replaces what the decodes write into: cancel them and wait
  # for each one's end (its processor has stopped by then).
  defp end_decodes(state) do
    for {decode, _} <- state.decodes do
      MobAudioIo.decode_cancel(decode)

      receive do
        {:mob_audio_io, kind, ^decode, _info} when kind in @ends -> :ok
      after
        @decode_end_ms -> Logger.warning("[choir_audio] decode #{decode} didn't end")
      end
    end

    %{state | decodes: %{}}
  end
end
