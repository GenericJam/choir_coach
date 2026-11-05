defmodule ChoirCoach.Audio.Fake do
  @moduledoc """
  Host engine: no sound. Playback is a monotonic clock and the voice is
  `ChoirCoach.FakeSinger`, sampled every 10 ms, so screen tests and host runs
  exercise the same trace, smoothing and drawing paths as the device.

  `load/2` sends `{:choir_audio, :ready, info}` straight away. Tests drive
  the clock with `at/2` instead of waiting.
  """

  @behaviour ChoirCoach.Audio

  alias ChoirCoach.{FakeSinger, Song}

  @sample_ms 10

  defstruct [:song, playing: false, base_ms: 0.0, started_at: nil, sampled_to: nil, now: nil]

  @impl true
  def new(%Song{} = song), do: %__MODULE__{song: song}

  @impl true
  def load(state, _track) do
    send(self(), {:choir_audio, :ready, %{duration_ms: Song.duration_ms(state.song)}})
    state
  end

  @impl true
  def play(state, from_ms) do
    {:ok,
     %{
       state
       | playing: true,
         base_ms: from_ms * 1.0,
         started_at: now(state),
         sampled_to: from_ms - @sample_ms
     }}
  end

  @impl true
  def pause(state) do
    {_, t} = position(state)
    %{state | playing: false, base_ms: t, started_at: nil}
  end

  @impl true
  def position(%{playing: true} = state),
    do: {:playing, state.base_ms + (now(state) - state.started_at)}

  def position(state), do: {:paused, state.base_ms}

  @impl true
  def set_mix(state, _voice, _accomp), do: state

  @impl true
  def listen(state, _source), do: {:ok, state}

  @impl true
  def readings(%{playing: false} = state), do: {[], state}

  def readings(state) do
    {_, t} = position(state)

    times =
      Stream.iterate(state.sampled_to + @sample_ms, &(&1 + @sample_ms))
      |> Enum.take_while(&(&1 <= t))

    readings =
      Enum.map(times, fn ts ->
        case FakeSinger.sample(state.song, ts) do
          nil -> {ts, nil, 0.0}
          %{midi: m, confidence: c} -> {ts, m, c}
        end
      end)

    {readings, %{state | sampled_to: List.last(times) || state.sampled_to}}
  end

  @doc "Pin the fake clock to `now` (ms) — for tests."
  @spec at(%__MODULE__{}, integer()) :: %__MODULE__{}
  def at(state, now), do: %{state | now: now}

  defp now(%{now: nil}), do: System.monotonic_time(:millisecond)
  defp now(%{now: now}), do: now
end
