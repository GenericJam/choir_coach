defmodule ChoirCoach.Audio.Native do
  @moduledoc """
  The device engine: `ChoirCoach.Audio.Nif` with song-time conversion.

  The NIF speaks track time. `shift` is how far a track's bar 1 sits from the
  song's bar 1, so song time = track time − shift.

  Mic readings are also moved earlier by the headphone delay
  (`set_mic_delay/2`, from `ChoirCoach.Settings`): Android often can't
  timestamp a shared-mode input stream, so the NIF stamps a reading when it
  arrives, not when it was sung, and Bluetooth headphones add their own lag.

  Readings below `@min_db` or `@min_confidence` are reported as silence: the
  detector still answers on breath noise and room tone, just unconvincingly.
  """

  @behaviour ChoirCoach.Audio

  alias ChoirCoach.{Audio, Pitch, Song}
  alias ChoirCoach.Audio.Nif

  @min_db -45.0
  @min_confidence 0.5

  defstruct song_start: 0.0, shift: 0.0, layout: :mixed, source: nil, mic_delay: 0.0

  @impl true
  def new(%Song{} = song), do: %__MODULE__{song_start: Song.start_ms(song)}

  @impl true
  def load(state, %{file: file, bar1_ms: bar1, voice: voice}) do
    :ok = Nif.load(Audio.track_path(file))
    %{state | shift: bar1 - state.song_start, layout: layout(voice)}
  end

  @impl true
  def play(state, from_ms) do
    case Nif.play((from_ms + state.shift) * 1.0) do
      :ok -> {:ok, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  @impl true
  def pause(state) do
    Nif.pause()
    state
  end

  @impl true
  def stop(state) do
    Nif.pause()
    Nif.stop_listening()
    %{state | source: nil}
  end

  @impl true
  def position(state) do
    case Nif.position() do
      {:empty, _} -> {:loading, 0.0}
      {status, ms} -> {status, ms - state.shift}
    end
  end

  @impl true
  def set_mix(state, voice_gain, accomp_gain) do
    Nif.set_mix(voice_gain * 1.0, accomp_gain * 1.0, state.layout)
    state
  end

  @impl true
  def listen(state, source) do
    case Nif.listen(source) do
      :ok -> {:ok, %{state | source: source}}
      {:error, reason} -> {:error, reason, state}
    end
  end

  @impl true
  def set_mic_delay(state, ms), do: %{state | mic_delay: ms * 1.0}

  @impl true
  def readings(state) do
    readings =
      for {ms, hz, conf, db} <- Nif.readings() do
        t = ms - state.shift - if(state.source == :mic, do: state.mic_delay, else: 0.0)

        if hz > 0 and db >= @min_db and conf >= @min_confidence,
          do: {t, Pitch.midi(hz), conf},
          else: {t, nil, 0.0}
      end

    {readings, state}
  end

  defp layout(:left), do: :voice_left
  defp layout(:right), do: :voice_right
  defp layout(:mixed), do: :mixed
end
