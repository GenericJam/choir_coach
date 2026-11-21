defmodule ChoirIos.MixProject do
  use Mix.Project

  # Choir Coach's iOS-only native bits (Objective-C, AVFoundation and UIKit),
  # carried as an in-repo Mob plugin: a project static NIF can only be C
  # (`c_src/<name>.c`), while a plugin NIF may be `lang: :objc`. Native only:
  # the Elixir side is `ChoirCoach.Ios` in the app. See priv/mob_plugin.exs.
  # The audio itself is mob_audio_io's streams and the app's
  # c_src/choir_audio.c.
  def project do
    [
      app: :choir_ios,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: []
    ]
  end

  def application, do: []
end
