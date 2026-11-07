# Drives every practice-screen control on a connected Android phone with REAL
# touches (`adb shell input`), not Mob.Test's synthetic taps: the bugs this
# guards against (taps lost while a song plays, MOB-509) live in the native
# layer that synthetic taps skip. Each step checks the screen's state.
#
#   mix mob.connect --no-iex --android-only --device <serial>
#   SERIAL=<serial> mix run --no-start scripts/controls_check.exs
#
# Controls are found by their `id` through `Mob.Test.element_frames/1` (dp),
# scaled to pixels from the phone's real width, so any screen size works.
# Plays through the phone speaker with the mic on; exits non-zero on a failure.

alias ChoirCoach.{Song, Songs}

defmodule Check do
  @moduledoc false

  def adb(serial, args), do: System.cmd("adb", ["-s", serial | args], stderr_to_stdout: true)

  # Pixels per dp: the phone's real width over the width the app lays out in.
  def scale(serial, node) do
    {out, 0} = adb(serial, ["shell", "wm", "size"])
    [_, w] = Regex.run(~r/(\d+)x\d+\s*$/, String.trim(out))
    String.to_integer(w) / Mob.Test.screen_info(node).width
  end

  def frame!(node, id) do
    case Mob.Test.frame(node, id) do
      {x, y, w, h} -> {x, y, w, h}
      other -> raise "no element #{inspect(id)} on screen (#{inspect(other)})"
    end
  end

  def tap(ctx, id) do
    {x, y, w, h} = frame!(ctx.node, id)
    px = fn v -> "#{round(v * ctx.scale)}" end
    adb(ctx.serial, ["shell", "input", "tap", px.(x + w / 2), px.(y + h / 2)])
  end

  # Drag across the progress track from fraction `a` to `b` over `ms`.
  def drag(ctx, id, a, b, ms) do
    {x, y, w, h} = frame!(ctx.node, id)
    px = fn v -> "#{round(v * ctx.scale)}" end
    yy = px.(y + h / 2)
    adb(ctx.serial, ["shell", "input", "swipe", px.(x + w * a), yy, px.(x + w * b), yy, "#{ms}"])
  end

  def a(ctx), do: Mob.Test.assigns(ctx.node)

  # Polls until `fun.(assigns)` is truthy, up to `ms`. A screen still
  # mounting (another screen's assigns, or none) counts as not yet.
  def until(ctx, ms, fun) do
    deadline = System.monotonic_time(:millisecond) + ms

    Stream.repeatedly(fn ->
      state = a(ctx)

      ok =
        try do
          is_map(state) and fun.(state) == true
        rescue
          _ -> false
        end

      if not ok, do: Process.sleep(100)
      {ok, state}
    end)
    |> Enum.find(fn {ok, _} -> ok or System.monotonic_time(:millisecond) > deadline end)
    |> elem(0)
  end

  def bar(state), do: Song.bar_at(state.song, state.t_ms).number

  def step(name, fun) do
    result =
      try do
        fun.()
      rescue
        e -> {:error, Exception.message(e)}
      end

    case result do
      true ->
        IO.puts("PASS  #{name}")
        :pass

      {:error, why} ->
        IO.puts("FAIL  #{name}: #{why}")
        :fail

      other ->
        IO.puts("FAIL  #{name}: #{inspect(other)}")
        :fail
    end
  end
end

serial = System.fetch_env!("SERIAL")
node = :"choir_coach_android_#{String.downcase(serial)}@127.0.0.1"
{:ok, _} = Node.start(:"controls_#{System.unique_integer([:positive])}@127.0.0.1")
Node.set_cookie(MobDev.DistCookie.for_project!())
true = Node.connect(node)

ctx = %{serial: serial, node: node, scale: Check.scale(serial, node)}

# Back to the song list, whatever screen the app is on.
for _ <- 1..3, Mob.Test.screen(node) != ChoirCoach.SongsScreen do
  Mob.Test.tap(node, :back)
  Process.sleep(700)
end

# The singer's part (PART=soprano|alto|tenor|bass, default bass), picked on
# the song list with a real tap; every song then opens on it.
mine = String.to_existing_atom(System.get_env("PART", "bass"))
IO.puts("== Your part: #{mine}")

picked =
  Check.step("the song list remembers the part picked", fn ->
    Check.tap(ctx, "my_part_#{mine}")
    Check.until(ctx, 1_500, &(&1.my_part == mine)) and
      :rpc.call(node, ChoirCoach.Settings, :my_part, []) == mine
  end)

results =
  for mod <- Songs.all() do
    title = mod.bass().title
    IO.puts("\n== #{title}")
    Mob.Test.tap(node, {:open, mod})

    steps = [
      {"loads, on my part",
       fn ->
         Check.until(
           ctx,
           10_000,
           &(Mob.Test.screen(node) == ChoirCoach.PracticeScreen and &1.audio_status == :ready and
               &1.part == mine)
         )
       end},
      {"play starts playback (real tap)",
       fn ->
         Mob.Test.send_message(node, {:seek, Song.bar_start(Check.a(ctx).song, 20)})
         Process.sleep(300)
         Check.tap(ctx, "ctl_play")
         Check.until(ctx, 2_000, & &1.playing)
       end},
      {"the clock moves and the mic hears it",
       fn ->
         t0 = Check.a(ctx).t_ms
         Process.sleep(2_000)
         s = Check.a(ctx)
         s.t_ms - t0 > 1_500 and length(s.trace) > 0
       end},
      {"+1 bar and −1 bar while playing, five times each",
       fn ->
         results =
           for kind <- List.duplicate("ctl_forward_bar", 5) ++ List.duplicate("ctl_back_bar", 5) do
             before = Check.bar(Check.a(ctx))
             Check.tap(ctx, kind)
             want = if kind == "ctl_forward_bar", do: &(&1 >= before + 1), else: &(&1 <= before)
             Check.until(ctx, 1_500, &want.(Check.bar(&1)))
           end

         (Enum.all?(results) and Check.a(ctx).playing) or
           {:error, "taps that missed: #{Enum.count(results, &(!&1))} of 10"}
       end},
      {"scrubbing pauses, follows the finger and plays on",
       fn ->
         task = Task.async(fn -> Check.drag(ctx, "progress", 0.2, 0.6, 1_500) end)
         mid = Check.until(ctx, 1_800, &(&1.scrub != nil and not &1.playing))
         Task.await(task, 10_000)
         Process.sleep(400)
         s = Check.a(ctx)
         frac = s.t_ms / Song.duration_ms(s.song)

         (mid and s.playing and frac > 0.55 and frac < 0.65) or
           {:error, "mid paused=#{mid} after playing=#{s.playing} at #{Float.round(frac, 2)}"}
       end},
      {"loop toggles",
       fn ->
         before = Check.a(ctx).loop
         Check.tap(ctx, "ctl_loop")
         Check.until(ctx, 1_500, &(&1.loop != before))
       end},
      {"Mix opens, a preset applies, Done closes",
       fn ->
         Check.tap(ctx, "ctl_mix")
         opened = Check.until(ctx, 1_500, & &1.mix_open)
         Process.sleep(300)
         Check.tap(ctx, "preset_right_ear")
         preset = Check.until(ctx, 1_500, &(&1.mix.preset == :right_ear))
         Check.tap(ctx, "mix_done")
         closed = Check.until(ctx, 1_500, &(not &1.mix_open))

         (opened and preset and closed and Check.a(ctx).playing) or
           {:error, "opened=#{opened} preset=#{preset} closed=#{closed}"}
       end},
      {"Mix toggles closed again",
       fn ->
         Check.tap(ctx, "ctl_mix")

         Check.until(ctx, 1_500, & &1.mix_open) and
           (
             Check.tap(ctx, "ctl_mix")
             Check.until(ctx, 1_500, &(not &1.mix_open))
           )
       end},
      {"Melody and back to my part, playing on at the same place",
       fn ->
         s0 = Check.a(ctx)
         {t, mine} = {s0.t_ms, s0.part}
         Check.tap(ctx, "part_melody")
         melody = Check.until(ctx, 5_000, &(&1.part == :melody and &1.playing))
         Check.tap(ctx, "part_#{mine}")
         back = Check.until(ctx, 5_000, &(&1.part == mine and &1.playing))
         s = Check.a(ctx)

         (melody and back and abs(s.t_ms - t) < 8_000) or
           {:error, "melody=#{melody} #{mine}=#{back} moved #{round(s.t_ms - t)} ms"}
       end},
      {"restart goes back to the start",
       fn ->
         Check.tap(ctx, "ctl_restart")
         Check.until(ctx, 2_000, &(&1.t_ms < 3_000 and &1.playing))
       end},
      {"pause stops playback",
       fn ->
         Check.tap(ctx, "ctl_play")
         Check.until(ctx, 1_500, &(not &1.playing))
       end},
      {"the headphones icon opens Audio; back reloads the song",
       fn ->
         Check.tap(ctx, "audio_icon")

         audio =
           Check.until(ctx, 3_000, fn _ -> Mob.Test.screen(node) == ChoirCoach.AudioScreen end)

         Process.sleep(1_000)
         Mob.Test.tap(node, :back)

         back =
           Check.until(
             ctx,
             6_000,
             &(Mob.Test.screen(node) == ChoirCoach.PracticeScreen and &1.audio_status == :ready)
           )

         (audio and back) or {:error, "audio=#{audio} back=#{back}"}
       end},
      {"system back leaves the song and stops the engine",
       fn ->
         Check.adb(ctx.serial, ["shell", "input", "keyevent", "KEYCODE_BACK"])

         Check.until(ctx, 3_000, fn _ -> Mob.Test.screen(node) == ChoirCoach.SongsScreen end) and
           match?({:error, _}, :rpc.call(node, ChoirCoach.Audio.Nif, :position, []))
       end}
    ]

    for {name, fun} <- steps, do: Check.step(name, fun)
  end

all = List.flatten([picked | results])
failed = Enum.count(all, &(&1 == :fail))
IO.puts("\n#{length(all) - failed} passed, #{failed} failed")
if failed > 0, do: System.halt(1)
