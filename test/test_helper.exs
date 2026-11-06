# The app's on_start doesn't run under mix test; screens need the lease.
{:ok, _} = ChoirCoach.Audio.Lease.start_link()

ExUnit.start()
