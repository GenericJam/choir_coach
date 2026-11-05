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
