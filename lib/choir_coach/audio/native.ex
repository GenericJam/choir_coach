defmodule ChoirCoach.Audio.Native do
  @moduledoc """
  The device engine: the `choir_audio` NIF's processors on `mob_audio_io`'s
  streams, with song-time conversion. `ChoirCoach.Audio.Native.Io` (one
  process) owns the streams and decodes and makes the calls that start or
  stop something; position, mix, readings and pause go to
  `ChoirCoach.Audio.Nif` directly.

  The NIF speaks track time. `shift` is how far the tracks' bar 1 sits from
  the song's bar 1, so song time = track time − shift. A bare engine
  (`new_bare/0`) has song time = track time.

  Mic readings are also moved earlier by the headphone delay
  (`set_mic_delay/2`, from `ChoirCoach.Settings`): a shared-mode input
  stream's timestamps don't include what the headphones add, and Bluetooth
  headphones add a lot.

  Readings below `@min_db` or `@min_confidence` carry no pitch: the
  detector still answers on breath noise and room tone, just unconvincingly.
  Their level is still reported by `readings_with_level/1`.

  The NIF is one engine for the whole app, held by one process at a time
  (see `ChoirCoach.Audio`). A call the NIF refuses because another process
  holds it changes nothing and sends this process
  `{:choir_audio, :not_owner, nil, hold}`; the call itself returns as if
  nothing were loaded (`position/1` says `:loading`, no readings), or
  `{:error, :not_owner, state}` where the callback has an error result.

  ## Devices

  `mob_audio_io`'s device lists, in the engine's kinds. Android: every
  output and input `AudioManager` lists (ids are its device ids); a
  Bluetooth output that has an A2DP sibling of the same name is that
  headset's call route (`:bluetooth_sco`), any other Bluetooth output LE
  audio (`:bluetooth`). iOS: the current route's outputs plus the speaker
  (`"speaker"`, the one output that can be chosen: an override), and the
  session's available inputs; ids are `"out:"` / `"in:"` and the port's
  UID, stable across runs.
  """

  @behaviour ChoirCoach.Audio

  alias ChoirCoach.{Audio, Pitch, Song}
  alias ChoirCoach.Audio.Native.Io

  @min_db -45.0
  @min_confidence 0.5
  @speaker "speaker"

  # `load`, `listen`, `hold`: the numbers of this state's load, listening and
  # holding, which its events carry (`Audio.event_for?/2`).
  defstruct song_start: 0.0,
            shift: 0.0,
            source: nil,
            mic_delay: 0.0,
            load: nil,
            listen: nil,
            hold: nil

  @doc false
  # The NIF module: `ChoirCoach.Audio.Nif`, or a double in host tests
  # (`config :choir_coach, :audio_nif`).
  def nif, do: Application.get_env(:choir_coach, :audio_nif, ChoirCoach.Audio.Nif)

  @doc false
  # Choir Coach's iOS native bits (`ChoirCoach.Ios`), or a double in host tests.
  def ios, do: Application.get_env(:choir_coach, :ios_nif, ChoirCoach.Ios)

  @doc false
  # :ios or :android (`config :choir_coach, :audio_platform` in host tests).
  def platform do
    Application.get_env(:choir_coach, :audio_platform) ||
      if match?({:unix, :darwin}, :os.type()), do: :ios, else: :android
  end

  @doc false
  def speaker_id, do: @speaker

  @impl true
  def new(%Song{} = song), do: %__MODULE__{song_start: Song.start_ms(song)}

  @impl true
  def new_bare, do: %__MODULE__{}

  @impl true
  def set_song(state, %Song{} = song), do: %{state | song_start: Song.start_ms(song)}

  @impl true
  def acquire(state, force) do
    case Io.acquire(force) do
      {:ok, epoch} -> {:ok, %{state | hold: epoch}}
      {:error, :busy} -> {:error, :busy, state}
    end
  end

  @impl true
  def release(state) do
    :ok = Io.release()
    %{state | source: nil}
  end

  # A load the NIF refuses arrives like any other load error, tagged with a
  # reference of its own. Either way listening has stopped.
  @impl true
  def load(state, %{bar1_ms: bar1, sources: sources, guide_lane: guide} = spec) do
    case Io.load(Enum.map(sources, &{Audio.file_path(&1.file), &1.channels}), guide) do
      {:ok, generation} ->
        state = %{state | shift: bar1 - state.song_start, load: generation, source: nil}
        set_mix(state, Audio.recorded_gains(spec))

      {:error, :not_owner} ->
        lost(state)

      {:error, reason} ->
        load = make_ref()
        send(self(), {:choir_audio, :load_error, reason, load})
        %{state | load: load, source: nil}
    end
  end

  @impl true
  def current?(state, event), do: Audio.event_for?(state, event)

  @impl true
  def play(state, from_ms) do
    case Io.play((from_ms + state.shift) * 1.0) do
      :ok -> {:ok, state}
      {:error, :not_owner} -> {:error, :not_owner, lost(state)}
      {:error, reason} -> {:error, reason, state}
    end
  end

  @impl true
  def pause(state), do: owned(Io.pause(), state)

  @impl true
  def stop(state) do
    with :ok <- Io.pause(), :ok <- Io.stop_listening() do
      %{state | source: nil}
    else
      {:error, :not_owner} -> lost(state)
    end
  end

  @impl true
  def stop_listening(state) do
    case Io.stop_listening() do
      :ok -> %{state | source: nil}
      {:error, :not_owner} -> lost(state)
    end
  end

  @impl true
  def position(state) do
    case nif().position() do
      {:empty, _} ->
        {:loading, 0.0}

      {:error, :not_owner} ->
        lost(state)
        {:loading, 0.0}

      {status, ms} ->
        {status, ms - state.shift}
    end
  end

  @impl true
  def set_mix(state, gains),
    do: owned(nif().set_mix(Enum.map(gains, fn {l, r} -> {l * 1.0, r * 1.0} end)), state)

  @impl true
  def listen(state, source) do
    case Io.listen(source) do
      {:ok, listen} -> {:ok, %{state | source: source, listen: listen}}
      {:error, :not_owner} -> {:error, :not_owner, lost(state)}
      {:error, reason} -> {:error, reason, %{state | source: nil}}
    end
  end

  @impl true
  def set_mic_delay(state, ms), do: %{state | mic_delay: ms * 1.0}

  @impl true
  def readings(state) do
    {readings, state} = readings_with_level(state)
    {Enum.map(readings, fn {t, midi, conf, _db} -> {t, midi, conf} end), state}
  end

  @impl true
  def readings_with_level(state) do
    case nif().readings() do
      {:error, :not_owner} -> {[], lost(state)}
      raw -> {Enum.map(raw, &reading(state, &1)), state}
    end
  end

  defp reading(state, {ms, hz, conf, db}) do
    t = ms - state.shift - if(state.source == :mic, do: state.mic_delay, else: 0.0)

    if hz > 0 and db >= @min_db and conf >= @min_confidence,
      do: {t, Pitch.midi(hz), conf, db},
      else: {t, nil, 0.0, db}
  end

  @impl true
  def devices(_state), do: device_list(platform())

  @impl true
  def set_output(state, id), do: owned(Io.set_output(id), state)

  @impl true
  def set_input(state, id) do
    case Io.set_input(id) do
      {:ok, listen} -> {:ok, %{state | listen: listen}}
      {:error, :not_owner} -> {:error, :not_owner, lost(state)}
      {:error, reason} -> {:error, reason, %{state | source: nil}}
    end
  end

  @impl true
  def output_device(_state), do: Io.output_device()

  @doc """
  Engine diagnostics for RPC: the NIF's (`track_rate`, `decoded_ms`,
  `listening`, `input_latency_ms`, ...) with the streams' from
  `MobAudioIo.status/1`: `output_buffer`, `output_xruns`, `output_device`,
  `input_device`, and the whole maps under `:output_stream` and
  `:input_stream` (nil when closed).
  """
  @spec info() :: map()
  def info do
    %{output: out, input: input} = Io.streams()

    Map.merge(nif().info(), %{
      output_buffer: out[:buffer] || 0,
      output_xruns: out[:xruns] || 0,
      output_device: out[:device_id],
      input_device: input[:device_id],
      output_stream: out,
      input_stream: input
    })
  end

  defp owned(:ok, state), do: state
  defp owned({:error, :not_owner}, state), do: lost(state)

  # Another process holds the engine: tell this one, which hands over.
  defp lost(state) do
    send(self(), {:choir_audio, :not_owner, nil, state.hold})
    state
  end

  # ── Devices ─────────────────────────────────────────────────────────────

  defp device_list(:android) do
    outputs = plugin_devices(:output)
    inputs = plugin_devices(:input)
    a2dp = for %{kind: :bluetooth_a2dp, name: name} <- outputs, into: MapSet.new(), do: name

    Enum.map(outputs, &android_device(&1, :output, a2dp)) ++
      Enum.map(inputs, &android_device(&1, :input, a2dp))
  end

  defp device_list(:ios) do
    inputs = plugin_devices(:input)
    route = plugin_devices(:output)
    headset_mic? = Enum.any?(inputs, &(&1.kind == :wired_headset))
    outputs = Enum.map(route, &ios_output(&1, headset_mic?))

    speaker =
      if Enum.any?(outputs, &(&1.id == @speaker)),
        do: [],
        else: [device(@speaker, :output, :speaker, "Speaker")]

    outputs ++ speaker ++ Enum.map(inputs, &ios_input/1)
  end

  defp plugin_devices(direction) do
    case MobAudioIo.devices(direction) do
      list when is_list(list) -> list
      {:error, _} -> []
    end
  end

  defp device(id, direction, kind, name),
    do: %{id: id, direction: direction, kind: kind, name: name}

  # The plugin's kinds as the engine always named them: a Bluetooth
  # headset's microphone is :bluetooth_sco whichever profile carries it; an
  # output, :bluetooth (A2DP, LE audio) unless it is a headset's call route.
  defp android_device(%{id: id, name: name, kind: kind}, direction, a2dp),
    do: device(id, direction, android_kind(kind, direction, name, a2dp), name)

  defp android_kind(:bluetooth, :input, _name, _a2dp), do: :bluetooth_sco

  defp android_kind(:bluetooth, :output, name, a2dp),
    do: if(MapSet.member?(a2dp, name), do: :bluetooth_sco, else: :bluetooth)

  defp android_kind(kind, _direction, _name, _a2dp), do: common_kind(kind)

  defp ios_output(%{kind: :builtin_speaker}, _headset_mic?),
    do: device(@speaker, :output, :speaker, "Speaker")

  defp ios_output(%{id: uid, name: name, kind: kind}, headset_mic?) do
    kind =
      case kind do
        :wired_headphones when headset_mic? -> :wired_headset
        :bluetooth -> :bluetooth
        kind -> common_kind(kind)
      end

    device("out:" <> uid, :output, kind, name)
  end

  defp ios_input(%{id: uid, name: name, kind: kind}) do
    kind = if kind == :bluetooth, do: :bluetooth_sco, else: common_kind(kind)
    device("in:" <> uid, :input, kind, name)
  end

  defp common_kind(:builtin_speaker), do: :speaker
  defp common_kind(:builtin_earpiece), do: :earpiece
  defp common_kind(:bluetooth_a2dp), do: :bluetooth

  defp common_kind(kind) when kind in [:wired_headset, :wired_headphones, :usb, :builtin_mic],
    do: kind

  defp common_kind(_kind), do: :other

  @doc false
  # iOS: the id of the output the current route plays on, or nil.
  def route_output_id do
    case plugin_devices(:output) do
      [first | _] -> ios_output(first, false).id
      [] -> nil
    end
  end

  @doc false
  # iOS: an input id's port UID, or nil.
  def ios_port("in:" <> uid), do: uid
  def ios_port(_id), do: nil
end
