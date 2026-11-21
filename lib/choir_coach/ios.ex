defmodule ChoirCoach.Ios do
  @moduledoc """
  Choir Coach's iOS-only native bits, the `choir_ios` NIF of the in-repo
  plugin `plugins/choir_ios` (Objective-C). Not loaded on Android or the
  host: call these on iOS only.

  None of it is the audio engine (that is `mob_audio_io` and
  `c_src/choir_audio.c`); these are what neither Mob nor `mob_audio_io` does
  yet:

    * `screen_size/0`: Mob's `:mob_nif.screen_info/0` is compiled out of iOS
      release builds.
    * `set_speaker/1`: `mob_audio_io` lets iOS route the output; the engine
      offers the speaker as a choice while headphones are connected.
    * `watch_route/1`: `mob_audio_io` reports a route change without its
      reason; the engine pauses when the route loses its device (headphones
      unplugged), as iOS apps do, instead of going on out loud.
  """

  @on_load :load_nif

  @doc false
  def load_nif, do: :erlang.load_nif(~c"choir_ios", 0)

  @doc """
  The main screen's `{width, height}` in points (`ChoirCoach.Window.current/0`).
  """
  def screen_size, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Route the output to the speaker (`true`), or let iOS route it (`false`:
  headphones when connected, else the speaker): `:ok` or
  `{:error, detail}`. iOS clears it on a route change or an interruption.
  """
  def set_speaker(_on), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Send `pid` `{:choir_ios, :route_lost, input_gone}` whenever the audio
  route loses its device (`AVAudioSessionRouteChangeReasonOldDeviceUnavailable`):
  `input_gone` when a microphone of the old route went with it. One
  watcher; a later call replaces it. `:ok`.
  """
  def watch_route(_pid), do: :erlang.nif_error(:nif_not_loaded)
end
