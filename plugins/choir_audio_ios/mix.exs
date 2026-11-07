defmodule ChoirAudioIos.MixProject do
  use Mix.Project

  # The iOS build of the app's `choir_audio` NIF (Objective-C, AVFoundation and
  # AudioToolbox), carried as an in-repo Mob plugin: a project static NIF can
  # only be C (`c_src/<name>.c`), while a plugin NIF may be `lang: :objc` and
  # bring iOS frameworks. Native only: the Elixir side is
  # `ChoirCoach.Audio.Nif` in the app. See priv/mob_plugin.exs.
  def project do
    [
      app: :choir_audio_ios,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: []
    ]
  end

  def application, do: []
end
