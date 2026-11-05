defmodule ChoirCoach.Audio.Nif do
  @moduledoc """
  The `choir_audio` NIF (`c_src/choir_audio.c`), statically linked into the
  Android app and registered through `mob.exs`'s `:static_nifs`. Use it
  through `ChoirCoach.Audio.Native`; times here are track milliseconds.

  Asynchronous results arrive at the process that called `load/1` as
  `{:choir_audio, event, payload}`: `:ready` once the first seconds are
  decoded, `:decoded` when the whole track is, `:load_error` with a reason.
  """

  @on_load :load_nif

  @doc false
  def load_nif, do: :erlang.load_nif(~c"choir_audio", 0)

  @doc "Start decoding the audio file at `path` (replaces any loaded track)."
  def load(_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Play from `from_ms` (a float). `:ok | {:error, reason}`."
  def play(_from_ms), do: :erlang.nif_error(:nif_not_loaded)

  def pause, do: :erlang.nif_error(:nif_not_loaded)

  @doc "`{:playing | :paused | :empty, ms}`: the track time being heard now."
  def position, do: :erlang.nif_error(:nif_not_loaded)

  @doc "Gains 0..1 and `:mixed | :voice_left | :voice_right`."
  def set_mix(_voice_gain, _accomp_gain, _layout), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Start pitch detection on `:mic` or `:playback` (the track itself)."
  def listen(_source), do: :erlang.nif_error(:nif_not_loaded)

  def stop_listening, do: :erlang.nif_error(:nif_not_loaded)

  @doc "Drain readings: `[{track_ms, hz, confidence, rms_db}]`, oldest first."
  def readings, do: :erlang.nif_error(:nif_not_loaded)

  @doc "Engine diagnostics."
  def info, do: :erlang.nif_error(:nif_not_loaded)
end
