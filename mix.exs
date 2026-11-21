defmodule ChoirCoach.MixProject do
  use Mix.Project

  def project do
    [
      app: :choir_coach,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: false,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      erlc_paths: ["src"],
      erlc_options: [:debug_info]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # Test doubles (the audio NIF's) compile in test only.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      # mob_audio_io needs 0.9.31 or later.
      {:mob, "~> 0.9.31"},
      # The audio streams, devices and file decoding under the app's DSP
      # (c_src/choir_audio.c's processors). Temporary: main's commit until
      # 0.1.0 is on Hex, then {:mob_audio_io, "~> 0.1"} (and its mob.exs
      # entry moves to :trusted_plugins).
      {:mob_audio_io,
       github: "GenericJam/mob_audio_io", ref: "faf1de89b969f5d43a0bf43ff2740008cd35039b"},
      # Choir Coach's iOS-only native bits (the screen size, the speaker
      # route, pausing when the route loses its device), an in-repo Mob
      # plugin activated in mob.exs.
      {:choir_ios, path: "plugins/choir_ios"},
      {:mob_dev, "~> 0.7.31", only: :dev, runtime: false},
      # `mix mob.icon --source` resizes the app icon with it (host only).
      {:image, "~> 0.54", only: :dev, runtime: false},
      {:ecto_sqlite3, "~> 0.18"},
      # Code quality — Credo + ex_slop (catches AI-generated patterns
      # like blanket rescue, narrator docs, redundant Enum chains, etc).
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4.2", only: [:dev, :test], runtime: false}
    ]
  end

  # Shorthands for the common mob workflows — `mix deploy` is `mix mob.deploy`,
  # etc. Extra args pass through to the underlying task, so `mix deploy
  # --device <udid>` works as expected.
  defp aliases do
    [
      connect: ["mob.connect"],
      deploy: ["mob.deploy"],
      watch: ["mob.watch"],
      icon: ["mob.icon"],
      ios: ["mob.deploy --ios"],
      "ios.native": ["mob.deploy --native --ios"],
      android: ["mob.deploy --android"],
      "android.native": ["mob.deploy --native --android"]
    ]
  end
end
