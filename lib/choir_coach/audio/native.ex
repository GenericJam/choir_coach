defmodule ChoirCoach.Audio.Native do
  @moduledoc """
  The device engine: `ChoirCoach.Audio.Nif` with song-time conversion.

  The NIF speaks track time. `shift` is how far the tracks' bar 1 sits from
  the song's bar 1, so song time = track time − shift. A bare engine
  (`new_bare/0`) has song time = track time.

  Mic readings are also moved earlier by the headphone delay
  (`set_mic_delay/2`, from `ChoirCoach.Settings`): Android often can't
  timestamp a shared-mode input stream, so the NIF stamps a reading when it
  arrives, not when it was sung, and Bluetooth headphones add their own lag.

  Readings below `@min_db` or `@min_confidence` carry no pitch: the
  detector still answers on breath noise and room tone, just unconvincingly.
  Their level is still reported by `readings_with_level/1`.

  The NIF is one engine for the whole app, held by one process at a time
  (see `ChoirCoach.Audio`). A call the NIF refuses because another process
  holds it changes nothing and sends this process
  `{:choir_audio, :not_owner, nil, hold}`; the call itself returns as if
  nothing were loaded (`position/1` says `:loading`, no readings), or
  `{:error, :not_owner, state}` where the callback has an error result.
  """

  @behaviour ChoirCoach.Audio

  alias ChoirCoach.{Audio, Pitch, Song}
  alias ChoirCoach.Audio.Nif

  @min_db -45.0
  @min_confidence 0.5

  # `load`, `listen`, `hold`: the numbers of this state's load, listening and
  # holding, which its events carry (`Audio.event_for?/2`).
  defstruct song_start: 0.0,
            shift: 0.0,
            source: nil,
            mic_delay: 0.0,
            load: nil,
            listen: nil,
            hold: nil

  @impl true
  def new(%Song{} = song), do: %__MODULE__{song_start: Song.start_ms(song)}

  @impl true
  def new_bare, do: %__MODULE__{}

  @impl true
  def set_song(state, %Song{} = song), do: %{state | song_start: Song.start_ms(song)}

  @impl true
  def acquire(state, force) do
    case Nif.acquire(force) do
      {:ok, epoch} -> {:ok, %{state | hold: epoch}}
      {:error, :busy} -> {:error, :busy, state}
    end
  end

  @impl true
  def release(state) do
    :ok = Nif.release()
    %{state | source: nil}
  end

  # A load the NIF refuses (`:output_stuck`: the output stream wouldn't stop,
  # so the current track stays loaded) arrives like any other load error,
  # tagged with a reference of its own. Either way listening has stopped.
  @impl true
  def load(state, %{bar1_ms: bar1, sources: sources, guide_lane: guide} = spec) do
    case Nif.load(Enum.map(sources, &{Audio.file_path(&1.file), &1.channels}), guide) do
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
    case Nif.play((from_ms + state.shift) * 1.0) do
      :ok -> {:ok, state}
      {:error, :not_owner} -> {:error, :not_owner, lost(state)}
      {:error, reason} -> {:error, reason, state}
    end
  end

  @impl true
  def pause(state), do: owned(Nif.pause(), state)

  @impl true
  def stop(state) do
    with :ok <- Nif.pause(), :ok <- Nif.stop_listening() do
      %{state | source: nil}
    else
      {:error, :not_owner} -> lost(state)
    end
  end

  @impl true
  def stop_listening(state) do
    case Nif.stop_listening() do
      :ok -> %{state | source: nil}
      {:error, :not_owner} -> lost(state)
    end
  end

  @impl true
  def position(state) do
    case Nif.position() do
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
    do: owned(Nif.set_mix(Enum.map(gains, fn {l, r} -> {l * 1.0, r * 1.0} end)), state)

  @impl true
  def listen(state, source) do
    case Nif.listen(source) do
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
    case Nif.readings() do
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
  def devices(_state), do: Nif.devices()

  @impl true
  def set_output(state, id), do: owned(Nif.set_output(id), state)

  @impl true
  def set_input(state, id) do
    case Nif.set_input(id) do
      {:ok, listen} -> {:ok, %{state | listen: listen}}
      {:error, :not_owner} -> {:error, :not_owner, lost(state)}
      {:error, reason} -> {:error, reason, %{state | source: nil}}
    end
  end

  @impl true
  def output_device(_state), do: Nif.output_device()

  defp owned(:ok, state), do: state
  defp owned({:error, :not_owner}, state), do: lost(state)

  # Another process holds the engine: tell this one, which hands over.
  defp lost(state) do
    send(self(), {:choir_audio, :not_owner, nil, state.hold})
    state
  end
end
