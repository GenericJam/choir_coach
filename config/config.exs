import Config

# Register the Repo so Mix tasks (mix ecto.create, mix ecto.migrate) can
# discover it. The actual database path is configured at runtime in
# ChoirCoach.Repo.init/2 via the MOB_DATA_DIR environment variable.
config :choir_coach, ecto_repos: [ChoirCoach.Repo]

# Wire the Repo into Mob.ScreenState so screens using `vsn:` get automatic
# state persistence. Remove this line to disable screen state persistence.
config :mob, :repo, ChoirCoach.Repo

# Host tests run without the Mob NIF, so screens skip device calls
# (screen size, keep-awake) there and fall back to the reference artboard.
config :choir_coach, device_calls: config_env() != :test

# Playback and pitch: the NIF engine on the device; host tests use the fake
# clock and scripted singer.
config :choir_coach,
  audio_engine:
    if(config_env() == :test, do: ChoirCoach.Audio.Fake, else: ChoirCoach.Audio.Native)

# How late mic readings arrive after the singer is heard, in ms. Measured on
# the moto g power 2021 with scripts/device_check.exs: the phone hearing its
# own speaker (SOURCE=mic) fits the score 60 ms later than the track analysed
# directly (SOURCE=playback). Re-measure for another phone.
config :choir_coach, mic_latency_ms: 60
