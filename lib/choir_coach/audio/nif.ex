defmodule ChoirCoach.Audio.Nif do
  @moduledoc """
  The `choir_audio` NIF (`c_src/choir_audio.c` over `c_src/choir_io.c`),
  statically linked into the app on both platforms: Choir Coach's DSP as
  `mob_audio_io` processors. The plugin owns the streams and the decoding;
  `ChoirCoach.Audio.Native.Io` opens and closes them and makes the calls
  that start or stop something, naming the holder (`pid`). Use it all
  through `ChoirCoach.Audio.Native`; times here are track milliseconds.

  Processors: `"choir_out"` (output: mixes the lanes, test mode's ring),
  `"choir_mic"` (input: the microphone's ring), `"choir_src0"` and
  `"choir_src1"` (a source file's decode into its lanes).

  One process holds the engine at a time (`acquire/2`, `release/1`). Every
  call that plays, listens or reads answers anyone else
  `{:error, :not_owner}`; `info/0` is open to all.

  Asynchronous results arrive at the holder as
  `{:choir_audio, event, payload, tag}`: `:ready` once the first seconds of
  every source are decoded, `:decoded` when all of them are, `:load_error`
  with a reason (`:not_found`, `:unsupported`, `:no_audio`, `:alloc`,
  `:decode_error` (the file stopped decoding part way),
  `:mismatched_sources`), all tagged with the load's number; and
  `:mic_error` (`:disconnected` or `:input_error`) tagged with the
  listening's number from `listen/2`.
  """

  @on_load :load_nif

  @doc false
  def load_nif, do: :erlang.load_nif(~c"choir_audio", 0)

  @doc """
  Make `pid` the engine's holder: `{:ok, epoch, changed}` or
  `{:error, :busy}`. Without `force` only when nobody holds it, `pid`
  already does, or the holder has died; with it, from anyone, whose music
  and microphone stop first (`changed`: the holder changed, so the streams
  are to close). `epoch` numbers the holding.
  """
  def acquire(_pid, _force), do: :erlang.nif_error(:nif_not_loaded)

  @doc "`pid` lets the engine go, music and microphone stopped: `{:ok, was_holder}`."
  def release(_pid), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Where notes for the stream owner go (`{:choir_audio_io, :load_failed, generation}`)."
  def attach(_pid), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Replace whatever was loaded: `sources` is the kept channels of each file,
  `[[:left | :right]]` (1–2 files, 1–2 channels each); they become lanes in
  order. `guide_lane` (a lane index or nil for all lanes) is what
  `listen(pid, :playback)` analyses. Every lane's gain is 0 until
  `set_mix/1`; listening and playback stop.

  `{:ok, generation}`, `{:error, :not_owner}`, or `{:error, :output_open |
  :decoding}` while the output stream or a decode could still touch the
  old load (the caller closes and waits for those first). The files are
  then decoded into `"choir_src<i>"`.
  """
  def load(_pid, _sources, _guide_lane), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Source `index` of load `generation` decoded to its end: `:ok`."
  def source_done(_generation, _index), do: :erlang.nif_error(:nif_not_loaded)

  @doc "A decode of load `generation` failed for `reason` (an atom): `:ok`; the first sends `:load_error`."
  def load_failed(_generation, _reason), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Play from `from_ms` once the output stream runs: `{:ok, track_rate}` or `{:error, :not_owner | :not_loaded}`."
  def play(_pid, _from_ms), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The holder pauses where it is heard: `:ok | {:error, :not_owner}`."
  def pause, do: :erlang.nif_error(:nif_not_loaded)

  @doc "Pause because the output went or moves: `{was_playing, ms}`, where it was heard."
  def halt, do: :erlang.nif_error(:nif_not_loaded)

  @doc "Whether it plays."
  def playing, do: :erlang.nif_error(:nif_not_loaded)

  @doc "`{:playing | :paused | :empty, ms}`: the track time being heard now; or `{:error, :not_owner}`."
  def position, do: :erlang.nif_error(:nif_not_loaded)

  @doc "`[{left, right}]`: each lane's gain into each ear (≥ 0); missing lanes are silent."
  def set_mix(_gains), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Start pitch detection on `:mic` (the `"choir_mic"` stream must be open,
  else `:microphone_unavailable`) or `:playback` (the guide lane):
  `{:ok, listen_number} | {:error, reason}`.
  """
  def listen(_pid, _source), do: :erlang.nif_error(:nif_not_loaded)

  @doc "`:ok | {:error, :not_owner}`."
  def stop_listening(_pid), do: :erlang.nif_error(:nif_not_loaded)

  @doc "`{:ok, :mic | :playback | :none, listen_number} | {:error, :not_owner}`."
  def listening(_pid), do: :erlang.nif_error(:nif_not_loaded)

  @doc "The microphone's stream failed: the holder listening to it gets `:mic_error` with `reason`."
  def mic_failed(_reason), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Drain readings: `[{track_ms, hz, confidence, rms_db}]`, oldest first; or `{:error, :not_owner}`."
  def readings, do: :erlang.nif_error(:nif_not_loaded)

  @doc "The engine's diagnostics (`ChoirCoach.Audio.Native.info/0` adds the streams')."
  def info, do: :erlang.nif_error(:nif_not_loaded)
end
