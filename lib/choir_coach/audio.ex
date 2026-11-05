defmodule ChoirCoach.Audio do
  @moduledoc """
  Playback and listening for the practice screen, behind an engine:

    * `ChoirCoach.Audio.Native` — the device: plays the rehearsal track and
      detects the singer's pitch from the microphone (`c_src/choir_audio.c`).
    * `ChoirCoach.Audio.Fake` — host tests: a monotonic clock and the
      scripted `ChoirCoach.FakeSinger`.

  The engine is chosen by `config :choir_coach, :audio_engine`. State is a
  value the screen keeps in its assigns; every call returns the new state.

  All times are song milliseconds (the `ChoirCoach.Song` timeline). A track
  whose bar 1 falls elsewhere is shifted by the engine.

  Readings are `{song_ms, midi | nil, confidence}`: a fractional MIDI pitch,
  or nil when nothing confident is heard.

  Loading is asynchronous. The calling process receives
  `{:choir_audio, :ready, info}` once playback can start, `{:choir_audio,
  :decoded, info}` when the whole track is in, or `{:choir_audio,
  :load_error, reason}`.
  """

  alias ChoirCoach.Song

  @type state :: term()
  @type reading :: {float(), float() | nil, float()}
  @type track :: %{file: String.t(), bar1_ms: float(), voice: :left | :right | :mixed}

  @callback new(Song.t()) :: state()
  @callback load(state(), track()) :: state()
  @callback play(state(), float()) :: {:ok, state()} | {:error, term(), state()}
  @callback pause(state()) :: state()
  @callback position(state()) :: {:playing | :paused | :loading, float()}
  @callback set_mix(state(), float(), float()) :: state()
  @callback listen(state(), :mic | :playback) :: {:ok, state()} | {:error, term(), state()}
  @doc "How much earlier than their arrival mic readings were sung (headphone delay), in ms."
  @callback set_mic_delay(state(), number()) :: state()
  @callback readings(state()) :: {[reading()], state()}

  @doc "The configured engine module."
  @spec engine() :: module()
  def engine, do: Application.get_env(:choir_coach, :audio_engine, ChoirCoach.Audio.Native)

  @doc "Absolute path of a bundled track file on this device (or the host)."
  @spec track_path(String.t()) :: String.t()
  def track_path(file) do
    case System.get_env("MOB_BEAMS_DIR") do
      nil -> Path.join([File.cwd!(), "priv", "audio", file])
      beams -> Path.join([beams, "priv", "audio", file])
    end
  end
end
