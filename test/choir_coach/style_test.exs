defmodule ChoirCoach.StyleTest do
  use ExUnit.Case, async: true

  alias ChoirCoach.{Pitch, Style}

  describe "cents_color/1" do
    test "hits every handoff stop exactly" do
      for {cents, argb} <- Style.cents_stops() do
        assert Style.cents_color(cents) == argb, "stop #{cents}¢"
      end
    end

    test "interpolates between neighbouring stops" do
      # Halfway from 0¢ mint (5E E0 A8) to +12¢ citrus (D6 D8 77).
      assert Style.cents_color(6) == 0xFF9ADC90
    end

    test "clamps beyond ±50¢" do
      assert Style.cents_color(-400) == Style.cents_color(-50)
      assert Style.cents_color(90) == Style.cents_color(50)
    end
  end

  test "glow grows with the error and saturates at 50¢" do
    assert Style.glow(0) == {30.0, 0.22}
    assert Style.glow(-20) == {44.0, 0.30}
    assert Style.glow(50) == Style.glow(120)
    {_r, a} = Style.glow(50)
    assert a == 0.42
  end

  describe "Pitch" do
    test "parses and names notes" do
      assert Pitch.parse("C4") == 60
      assert Pitch.parse("F#4") == 66
      assert Pitch.parse("Bb2") == 46
      assert Pitch.name(66) == "F♯4"
    end

    test "staff steps cross the octave between B and C" do
      assert Pitch.staff_step(60) - Pitch.staff_step(59) == 1
      assert Pitch.staff_step(61) == Pitch.staff_step(60)
    end

    test "hz and midi are inverses around A4" do
      assert Pitch.hz(69) == 440.0
      assert_in_delta Pitch.midi(Pitch.hz(55.37)), 55.37, 1.0e-9
    end
  end
end
