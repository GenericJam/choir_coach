defmodule ChoirCoach.Audio.Fake do
  @moduledoc """
  Host engine: no sound. Playback is a monotonic clock and the voice is
  `ChoirCoach.FakeSinger`, sampled every 10 ms (level −20 dB where it
  sings, −70 dB elsewhere), so screen tests and host runs exercise the
  same trace, smoothing and drawing paths as the device. A bare engine
  (`new_bare/0`) has no singer.

  `load/2` sends `{:choir_audio, :ready, info, load}` straight away and
  starts the lanes as recorded; `set_mix/2` records the gains in `:gains`,
  and `listen/2` the source in `:source` (a load or `stop/1` ends it).
  `current?/2` follows `ChoirCoach.Audio.event_for?/2`. The devices are a
  phone speaker (id 2, the system default output), Bluetooth headphones
  (31), the phone microphone (9) and the headphones' call microphone (32);
  `set_output/2` and `set_input/2` record the choice in `:output` and
  `:input`.

  Like the device's, the fake engine has one holder at a time, a process:
  every screen in a Mob screen test runs in the test process, which holds
  it. `hold_elsewhere/1` hands it to another process, as another screen
  taking it would; then the test process's calls change nothing and send
  `{:choir_audio, :not_owner, nil, hold}`, and `acquire/2` without force
  is `:busy` until that process dies. (The holder is kept in the calling
  process's dictionary: one fake engine per test process.)

  Tests drive the clock with `at/2` instead of waiting, and script readings
  with `put_readings/2`.
  """

  @behaviour ChoirCoach.Audio

  alias ChoirCoach.{Audio, FakeSinger, Song}

  @sample_ms 10
  @voiced_db -20.0
  @silence_db -70.0
  # The length of priv/sounds/clicks_90.mp3, the sound a bare engine plays.
  @bare_duration_ms 7_333.3
  @default_output 2
  @devices [
    %{id: 2, direction: :output, kind: :speaker, name: "Pixel 8"},
    %{id: 31, direction: :output, kind: :bluetooth, name: "WH-1000XM4"},
    %{id: 9, direction: :input, kind: :builtin_mic, name: "Pixel 8"},
    %{id: 32, direction: :input, kind: :bluetooth_sco, name: "WH-1000XM4"}
  ]
  @holder {__MODULE__, :holder}

  defstruct [
    :song,
    :spec,
    :output,
    :input,
    :load,
    :listen,
    :hold,
    :source,
    playing: false,
    base_ms: 0.0,
    started_at: nil,
    sampled_to: nil,
    now: nil,
    gains: [],
    queued: []
  ]

  @impl true
  def new(%Song{} = song), do: %__MODULE__{song: song}

  @impl true
  def new_bare, do: %__MODULE__{}

  @impl true
  def set_song(state, %Song{} = song), do: %{state | song: song}

  @impl true
  def acquire(state, force) do
    case Process.get(@holder) do
      {pid, hold} when pid == self() ->
        {:ok, %{state | hold: hold}}

      {pid, _hold} when not force ->
        if Process.alive?(pid), do: {:error, :busy, state}, else: take(state)

      _nobody_or_forced ->
        take(state)
    end
  end

  defp take(state) do
    hold = make_ref()
    Process.put(@holder, {self(), hold})
    {:ok, %{state | hold: hold}}
  end

  @impl true
  def release(state) do
    if held?(state) do
      state = %{pause(state) | source: nil}
      Process.delete(@holder)
      state
    else
      state
    end
  end

  @doc """
  Hand the engine to `pid` (by default a fresh live process), as another
  screen taking it would — for tests.
  """
  @spec hold_elsewhere(pid()) :: pid()
  def hold_elsewhere(pid \\ spawn(fn -> Process.sleep(:infinity) end)) do
    Process.put(@holder, {pid, make_ref()})
    pid
  end

  @impl true
  def load(state, spec) do
    if held?(state) do
      duration = if state.song, do: Song.duration_ms(state.song), else: @bare_duration_ms
      load = make_ref()
      send(self(), {:choir_audio, :ready, %{duration_ms: duration}, load})
      %{state | spec: spec, gains: Audio.recorded_gains(spec), load: load, source: nil}
    else
      lost(state)
    end
  end

  @impl true
  def current?(state, event), do: Audio.event_for?(state, event)

  @impl true
  def play(state, from_ms) do
    if held?(state) do
      {:ok,
       %{
         state
         | playing: true,
           base_ms: from_ms * 1.0,
           started_at: now(state),
           sampled_to: from_ms - @sample_ms
       }}
    else
      {:error, :not_owner, lost(state)}
    end
  end

  @impl true
  def pause(state) do
    if held?(state) do
      {_, t} = position(state)
      %{state | playing: false, base_ms: t, started_at: nil}
    else
      lost(state)
    end
  end

  @impl true
  def stop(state) do
    if held?(state), do: %{pause(state) | source: nil}, else: lost(state)
  end

  @impl true
  def position(state) do
    cond do
      not held?(state) ->
        lost(state)
        {:loading, 0.0}

      state.playing ->
        {:playing, state.base_ms + (now(state) - state.started_at)}

      true ->
        {:paused, state.base_ms}
    end
  end

  @impl true
  def set_mix(state, gains), do: if(held?(state), do: %{state | gains: gains}, else: lost(state))

  @impl true
  def listen(state, source) do
    if held?(state),
      do: {:ok, %{state | source: source, listen: make_ref()}},
      else: {:error, :not_owner, lost(state)}
  end

  @impl true
  def stop_listening(state), do: if(held?(state), do: %{state | source: nil}, else: lost(state))

  @impl true
  def set_mic_delay(state, _ms), do: state

  @impl true
  def readings(state) do
    {readings, state} = readings_with_level(state)
    {Enum.map(readings, fn {t, midi, conf, _db} -> {t, midi, conf} end), state}
  end

  @impl true
  def readings_with_level(state) do
    if held?(state) do
      {sung, state} = sing(state)
      {state.queued ++ sung, %{state | queued: []}}
    else
      {[], lost(state)}
    end
  end

  @impl true
  def devices(_state), do: @devices

  @impl true
  def set_output(state, id), do: if(held?(state), do: %{state | output: id}, else: lost(state))

  # A listening microphone restarts on the new input: a new listening.
  @impl true
  def set_input(state, id) do
    cond do
      not held?(state) -> {:error, :not_owner, lost(state)}
      state.source == :mic -> {:ok, %{state | input: id, listen: make_ref()}}
      true -> {:ok, %{state | input: id}}
    end
  end

  @impl true
  def output_device(state), do: state.output || @default_output

  defp held?(_state) do
    case Process.get(@holder) do
      {pid, _hold} -> pid == self()
      nil -> false
    end
  end

  defp lost(state) do
    send(self(), {:choir_audio, :not_owner, nil, state.hold})
    state
  end

  @doc "Pin the fake clock to `now` (ms) — for tests."
  @spec at(%__MODULE__{}, integer()) :: %__MODULE__{}
  def at(state, now), do: %{state | now: now}

  @doc "Queue readings (oldest first) for the next `readings_with_level/1` or `readings/1` — for tests."
  @spec put_readings(%__MODULE__{}, [Audio.level_reading()]) :: %__MODULE__{}
  def put_readings(state, readings), do: %{state | queued: state.queued ++ readings}

  defp sing(%{playing: false} = state), do: {[], state}
  defp sing(%{song: nil} = state), do: {[], state}

  defp sing(state) do
    {_, t} = position(state)

    times =
      Stream.iterate(state.sampled_to + @sample_ms, &(&1 + @sample_ms))
      |> Enum.take_while(&(&1 <= t))

    readings =
      Enum.map(times, fn ts ->
        case FakeSinger.sample(state.song, ts) do
          nil -> {ts, nil, 0.0, @silence_db}
          %{midi: m, confidence: c} -> {ts, m, c, @voiced_db}
        end
      end)

    {readings, %{state | sampled_to: List.last(times) || state.sampled_to}}
  end

  defp now(%{now: nil}), do: System.monotonic_time(:millisecond)
  defp now(%{now: now}), do: now
end
