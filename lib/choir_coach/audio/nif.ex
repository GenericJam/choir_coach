defmodule ChoirCoach.Audio.Nif do
  @moduledoc """
  The `choir_audio` NIF (`c_src/choir_audio.c`), statically linked into the
  Android app and registered through `mob.exs`'s `:static_nifs`. Use it
  through `ChoirCoach.Audio.Native`; times here are track milliseconds.

  One process holds the engine at a time (`acquire/1`, `release/0`). Every
  call that plays, listens or reads answers anyone else
  `{:error, :not_owner}`; `devices/0`, `output_device/0` and `info/0` are
  open to all.

  Asynchronous results arrive at the holder as
  `{:choir_audio, event, payload, tag}`: `:ready` once the first seconds of
  every source are decoded, `:decoded` when all of them are, `:load_error`
  with a reason (`:not_found`, `:unsupported`, `:no_audio`, `:alloc`,
  `:mismatched_sources`), all tagged with the load's number; and
  `:mic_error` (`:disconnected` or `:input_error`) tagged with the
  listening's number from `listen/1` or `set_input/1`.
  """

  @on_load :load_nif

  @doc false
  def load_nif, do: :erlang.load_nif(~c"choir_audio", 0)

  @doc """
  Become the engine's holder: `{:ok, epoch}` or `{:error, :busy}`. Without
  `force` only when nobody holds it, the caller already does, or the holder
  has died; with it, from anyone, whose music and microphone stop first.
  `epoch` numbers the holding (unchanged while the same process holds it).
  """
  def acquire(_force), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Let the engine go, music and microphone stopped (holder only; else a no-op)."
  def release, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Replace whatever was loaded with `sources`, `[{path, [:left | :right]}]`
  (1–2 files, 1–2 channels each), and start decoding them. The kept
  channels become lanes in order; `guide_lane` (a lane index or nil for all
  lanes) is what `listen(:playback)` analyses. Every lane's gain is 0 until
  `set_mix/1`. Listening stops.

  `{:ok, generation}`, `{:error, :output_stuck}` (the output stream wouldn't
  stop: the current track stays loaded), `{:error, :thread}` or
  `{:error, :not_owner}`. Calls are serialized.
  """
  def load(_sources, _guide_lane), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Play from `from_ms` (a float). `:ok | {:error, reason}`."
  def play(_from_ms), do: :erlang.nif_error(:nif_not_loaded)

  @doc "`:ok | {:error, :not_owner}`."
  def pause, do: :erlang.nif_error(:nif_not_loaded)

  @doc "`{:playing | :paused | :empty, ms}`: the track time being heard now; or `{:error, :not_owner}`."
  def position, do: :erlang.nif_error(:nif_not_loaded)

  @doc "`[{left, right}]`: each lane's gain into each ear (≥ 0); missing lanes are silent."
  def set_mix(_gains), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Start pitch detection on `:mic` or `:playback` (the guide lane). `{:ok, listen_number} | {:error, reason}`."
  def listen(_source), do: :erlang.nif_error(:nif_not_loaded)

  def stop_listening, do: :erlang.nif_error(:nif_not_loaded)

  @doc "Drain readings: `[{track_ms, hz, confidence, rms_db}]`, oldest first; or `{:error, :not_owner}`."
  def readings, do: :erlang.nif_error(:nif_not_loaded)

  @doc "Connected audio devices, `[%{id, direction, kind, name}]`: outputs, then inputs."
  def devices, do: :erlang.nif_error(:nif_not_loaded)

  @doc "Preferred output device id, or nil for the system default; reopens an open stream."
  def set_output(_id), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Preferred microphone id, or nil; restarts mic analysis.
  `{:ok, listen_number} | {:error, reason}`.
  """
  def set_input(_id), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The device id the open output stream plays on, or nil."
  def output_device, do: :erlang.nif_error(:nif_not_loaded)

  @doc "Engine diagnostics."
  def info, do: :erlang.nif_error(:nif_not_loaded)
end
