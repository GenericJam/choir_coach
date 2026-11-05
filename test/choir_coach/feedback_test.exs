defmodule ChoirCoach.FeedbackTest do
  use ExUnit.Case, async: true

  alias ChoirCoach.Feedback

  # Feed a constant reading every 33 ms for `ms`, starting at `t0`.
  defp hold(state, cents, t0, ms) do
    Enum.reduce(0..div(ms, 33), state, fn i, s -> Feedback.update(s, cents, t0 + i * 33) end)
  end

  test "settles on the band of a steady reading" do
    assert hold(Feedback.new(), -20.0, 0, 500).status == {:low, :slightly}
    assert hold(Feedback.new(), 45.0, 0, 500).status == {:high, :far}
    assert hold(Feedback.new(), 4.0, 0, 500).status == :on_pitch
  end

  test "silence reads as breathe" do
    s = hold(Feedback.new(), 2.0, 0, 500)
    assert hold(s, nil, 533, 400).status == :breathe
  end

  test "a quick scoop into the note doesn't change the wording" do
    s = hold(Feedback.new(), 2.0, 0, 600)
    # Two frames (~66 ms) at -30¢, then back on pitch: every frame keeps
    # "On pitch". (Held for longer, -30¢ rightly reads "a little low".)
    readings = [{-30.0, 633}, {-30.0, 666}] ++ Enum.map(0..9, &{2.0, 699 + &1 * 33})
    shown = Enum.scan(readings, s, fn {cents, t}, acc -> Feedback.update(acc, cents, t) end)

    assert Enum.all?(shown, &(&1.status == :on_pitch))
  end

  test "wording holds for 250 ms after it changes" do
    s = hold(Feedback.new(), 2.0, 0, 600)
    s = hold(s, -45.0, 633, 400)
    changed_at = s.status_since
    assert s.status != :on_pitch

    # Back on pitch, but read within 250 ms of the last change: still held.
    early = Feedback.update(%{s | color_cents: 0.0, cents: 0.0}, 0.0, changed_at + 100)
    assert early.status == s.status

    late = Feedback.update(%{s | color_cents: 0.0, cents: 0.0}, 0.0, changed_at + 260)
    assert late.status == :on_pitch
  end

  describe "classify/2 hysteresis" do
    test "on pitch holds out to 13¢" do
      assert Feedback.classify(12.5, :on_pitch) == :on_pitch
      assert Feedback.classify(13.5, :on_pitch) == {:high, :slightly}
    end

    test "a little off needs to come back inside 7¢" do
      assert Feedback.classify(-8.0, {:low, :slightly}) == {:low, :slightly}
      assert Feedback.classify(-6.5, {:low, :slightly}) == :on_pitch
    end

    test "far off needs to come back inside 27¢" do
      assert Feedback.classify(28.0, {:high, :far}) == {:high, :far}
      assert Feedback.classify(26.0, {:high, :far}) == {:high, :slightly}
    end
  end

  test "the glow breathes only after half a second far off" do
    s = hold(Feedback.new(), 45.0, 0, 300)
    assert Feedback.glow_radius(s, 300) == s.glow_r

    s = hold(s, 45.0, 330, 900)
    radii = for t <- [1300, 1700, 2100], do: Feedback.glow_radius(s, t)
    assert Enum.uniq(radii) |> length() == 3
  end

  test "after silence a scooped entry doesn't flash; a flat one shows once the hold allows" do
    s = hold(Feedback.new(), 40.0, 0, 600) |> hold(nil, 633, 300)

    scooped =
      s
      |> Feedback.update(-30.0, 966)
      |> Feedback.update(-12.0, 999)
      |> Feedback.update(2.0, 1032)

    assert scooped.status == :on_pitch

    # The entry shows "On pitch" first (eased from on-target), and the 250 ms
    # hold keeps it until the flat reading can take over.
    flat = hold(s, -30.0, 966, 200)
    assert flat.status == :on_pitch
    flat = hold(flat, -30.0, 1199, 100)
    assert flat.status == {:low, :slightly}
  end
end
