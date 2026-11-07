defmodule ChoirCoach.Audio do
  @moduledoc """
  Playback and listening for the practice screen, behind an engine:

    * `ChoirCoach.Audio.Native` — the device: plays the rehearsal tracks and
      detects the singer's pitch from the microphone (`c_src/choir_audio.c`
      on Android, `plugins/choir_audio_ios` on iOS).
    * `ChoirCoach.Audio.Fake` — host tests: a monotonic clock and the
      scripted `ChoirCoach.FakeSinger`.

  The engine is chosen by `config :choir_coach, :audio_engine`. State is a
  value the screen keeps in its assigns; every call returns the new state.

  All times are song milliseconds (the `ChoirCoach.Song` timeline). Tracks
  whose bar 1 falls elsewhere are shifted by the engine.

  ## Loading and mixing

  `load/2` takes a spec: up to two source files on one timeline (same bar 1,
  same sample rate), each keeping its `:left` and/or `:right` channel. The
  kept channels become **lanes**, in order: the first source's, then the
  second's (at most four). `set_mix/2` gives each lane a `{left, right}`
  gain; right after a load the lanes play as recorded (`recorded_gains/1`).
  `guide_lane` is the lane test mode (`listen(state, :playback)`) analyses:
  what the singer should match; nil analyses every lane together.

  Loading is asynchronous, and stops listening. The calling process
  receives `{:choir_audio, :ready, info, load}` once playback can start,
  `{:choir_audio, :decoded, info, load}` when every source is in, or
  `{:choir_audio, :load_error, reason, load}` (`:mismatched_sources` when
  the sample rates differ). A microphone that fails while listening sends
  `{:choir_audio, :mic_error, reason, listen}`. An event can arrive after
  the state moved on: handle it only when `current?(state, event)` says it
  belongs to the state's own latest load, listening or holding.

  ## One holder at a time

  The device engine is one per app, and its calls aren't tied to a load:
  any call acts on whatever is loaded. So one process holds it at a time,
  and the engine itself enforces that: `acquire/2` takes it (`force` takes
  it from a live holder, whose music and microphone stop), `release/1`
  gives it back, and any other call from a process that doesn't hold it
  changes nothing and sends that process
  `{:choir_audio, :not_owner, nil, hold}`.

  The Audio screen borrows the engine (`ChoirCoach.Audio.Lease.borrow/1`,
  then a forced acquire) and releases it on closing. A practice screen that
  hands it over, can't get it (`:busy`) or loses it waits with
  `Lease.await/1`: the lease sends it `{:audio_engine_reset}` once the
  borrower has gone (popped, crashed or killed), and it acquires again and
  reloads.

  ## Readings

  `readings/1` gives `{song_ms, midi | nil, confidence}`: a fractional MIDI
  pitch, or nil when nothing confident is heard. `readings_with_level/1`
  adds the window's RMS level in dBFS. Both drain the same queue.

  ## Devices

  `devices/1` lists the connected outputs and inputs. `set_output/2` and
  `set_input/2` pick one (nil: the system default) and take effect at once;
  a device that can't be opened falls back to the system default. While the
  microphone is listening, `set_input/2` restarts it, which can fail like
  `listen/2` (listening then stops).
  `output_device/1` is the id the open output stream actually plays on.
  """

  alias ChoirCoach.Song

  @type state :: term()
  @type reading :: {float(), float() | nil, float()}
  @type level_reading :: {float(), float() | nil, float(), float()}
  @type channel :: :left | :right
  @typedoc "A track under `priv/audio/`, or a bundled sound under `priv/sounds/`."
  @type file :: String.t() | {:sound, String.t()}
  @type source :: %{file: file(), channels: [channel()]}
  @type spec :: %{bar1_ms: float(), sources: [source()], guide_lane: non_neg_integer() | nil}
  @type gains :: [{float(), float()}]
  @type event ::
          {:choir_audio, :ready | :decoded | :load_error | :mic_error | :not_owner, term(),
           term()}
  @type kind ::
          :speaker
          | :earpiece
          | :wired_headphones
          | :wired_headset
          | :bluetooth
          | :bluetooth_sco
          | :usb
          | :builtin_mic
          | :other
  @type device :: %{id: integer(), direction: :output | :input, kind: kind(), name: String.t()}

  @callback new(Song.t()) :: state()
  @doc "An engine on the bare file timeline (song time = track time), for sounds such as calibration clicks."
  @callback new_bare() :: state()
  @doc "Put later loads on another song's timeline (a part switch), keeping everything else."
  @callback set_song(state(), Song.t()) :: state()
  @doc """
  Take the engine: `force` takes it even from a live holder (stopping its
  music and microphone); otherwise `:busy` while someone else holds it.
  """
  @callback acquire(state(), boolean()) :: {:ok, state()} | {:error, :busy, state()}
  @doc "Give the engine back, music and microphone stopped (no-op unless held)."
  @callback release(state()) :: state()
  @callback load(state(), spec()) :: state()
  @doc "Whether a `{:choir_audio, …}` event belongs to the state's own load, listening or holding."
  @callback current?(state(), event()) :: boolean()
  @callback play(state(), float()) :: {:ok, state()} | {:error, term(), state()}
  @callback pause(state()) :: state()
  @doc "Stop playback and listening (the microphone goes off), keeping the engine."
  @callback stop(state()) :: state()
  @callback position(state()) :: {:playing | :paused | :loading, float()}
  @doc "Each lane's `{left, right}` gain (≥ 0), in lane order."
  @callback set_mix(state(), gains()) :: state()
  @callback listen(state(), :mic | :playback) :: {:ok, state()} | {:error, term(), state()}
  @doc "Stop listening (the microphone goes off, its analysis thread ends); playback goes on."
  @callback stop_listening(state()) :: state()
  @doc "How much earlier than their arrival mic readings were sung (headphone delay), in ms."
  @callback set_mic_delay(state(), number()) :: state()
  @callback readings(state()) :: {[reading()], state()}
  @callback readings_with_level(state()) :: {[level_reading()], state()}
  @doc "Connected audio devices: outputs, then inputs."
  @callback devices(state()) :: [device()]
  @callback set_output(state(), integer() | nil) :: state()
  @callback set_input(state(), integer() | nil) :: {:ok, state()} | {:error, term(), state()}
  @callback output_device(state()) :: integer() | nil

  @doc """
  The rule both engines' `current?/2` follow. Events carry a tag: a load's
  number (`:ready`, `:decoded`, `:load_error`), a listening's
  (`:mic_error`) or a holding's (`:not_owner`), matched against the state's
  `:load`, `:listen` or `:hold`.
  """
  @spec event_for?(map(), event()) :: boolean()
  def event_for?(state, {:choir_audio, kind, _payload, tag}) when tag != nil,
    do: Map.get(state, tag_field(kind)) == tag

  def event_for?(_state, _event), do: false

  defp tag_field(:mic_error), do: :listen
  defp tag_field(:not_owner), do: :hold
  defp tag_field(_load_event), do: :load

  @doc "The configured engine module."
  @spec engine() :: module()
  def engine, do: Application.get_env(:choir_coach, :audio_engine, ChoirCoach.Audio.Native)

  @doc "Absolute path of a bundled track file on this device (or the host)."
  @spec track_path(String.t()) :: String.t()
  def track_path(file), do: priv_path(["audio", file])

  @doc "Absolute path of a sound shipped in `priv/sounds/` (e.g. `\"clicks_90.mp3\"`)."
  @spec sound_path(String.t()) :: String.t()
  def sound_path(name), do: priv_path(["sounds", name])

  @doc "Absolute path of a spec's `file`."
  @spec file_path(file()) :: String.t()
  def file_path({:sound, name}), do: sound_path(name)
  def file_path(file) when is_binary(file), do: track_path(file)

  @doc """
  The gains that play a spec's lanes as recorded, which `load/2` starts
  with: a left channel to the left ear, a right channel to the right, and a
  source keeping one channel to both.
  """
  @spec recorded_gains(spec()) :: gains()
  def recorded_gains(%{sources: sources}) do
    Enum.flat_map(sources, fn
      %{channels: [_]} -> [{1.0, 1.0}]
      %{channels: channels} -> Enum.map(channels, &recorded_gain/1)
    end)
  end

  defp recorded_gain(:left), do: {1.0, 0.0}
  defp recorded_gain(:right), do: {0.0, 1.0}

  defp priv_path(parts) do
    root = System.get_env("MOB_BEAMS_DIR") || File.cwd!()
    Path.join([root, "priv" | parts])
  end
end
