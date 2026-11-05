# Measures the practice screen's frame rate on a connected device.
#
#   mix mob.connect --no-iex --android-only --device <serial>
#   SECS=10 NODE=choir_coach_android_<serial>@127.0.0.1 mix run --no-start scripts/frame_rate.exs
#
# Restarts playback, lets it run for SECS, then prints the screen's own frame
# count against wall time and Mob.RenderStats' BEAM and native timings. In the
# native summary, `recorded` is how many trees the UI thread applied and
# `dropped` is samples that scrolled out of its 240-entry buffer (not skipped
# frames).

node = String.to_atom(System.fetch_env!("NODE"))
{:ok, _} = Node.start(:"frame_rate_#{System.unique_integer([:positive])}@127.0.0.1")
Node.set_cookie(MobDev.DistCookie.for_project!())
true = Node.connect(node)

seconds = String.to_integer(System.get_env("SECS", "10"))

:rpc.call(node, Mob.RenderStats, :reset, [])
:rpc.call(node, Mob.RenderStats, :enable, [])
:rpc.call(node, Mob.RenderStats, :native_enable, [])

if Mob.Test.assigns(node).playing, do: Mob.Test.tap(node, :play_pause)
frames_before = Mob.Test.assigns(node).frames
Mob.Test.tap(node, :restart)
t0 = System.monotonic_time(:millisecond)
Process.sleep(seconds * 1000)
frames = Mob.Test.assigns(node).frames - frames_before
wall = System.monotonic_time(:millisecond) - t0
Mob.Test.tap(node, :play_pause)

IO.puts("screen ticks: #{frames} in #{wall} ms => #{Float.round(frames * 1000 / wall, 1)} fps")
IO.inspect(:rpc.call(node, Mob.RenderStats, :summary, []), label: "beam", limit: :infinity)
IO.inspect(:rpc.call(node, Mob.RenderStats, :native_summary, []), label: "native", limit: :infinity)

:rpc.call(node, Mob.RenderStats, :disable, [])
:rpc.call(node, Mob.RenderStats, :native_disable, [])
