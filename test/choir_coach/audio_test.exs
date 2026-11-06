defmodule ChoirCoach.AudioTest do
  use ExUnit.Case, async: true

  alias ChoirCoach.Audio

  describe "recorded_gains/1 (the mix right after a load)" do
    test "a stereo source plays as recorded, lanes in spec order" do
      spec = %{
        bar1_ms: 0.0,
        guide_lane: nil,
        sources: [%{file: "a.mp3", channels: [:right, :left]}]
      }

      assert Audio.recorded_gains(spec) == [{0.0, 1.0}, {1.0, 0.0}]
    end

    test "a source keeping one channel reaches both ears" do
      spec = %{
        bar1_ms: 0.0,
        guide_lane: 0,
        sources: [
          %{file: "piano.mp3", channels: [:left]},
          %{file: "bass.mp3", channels: [:left, :right]}
        ]
      }

      assert Audio.recorded_gains(spec) == [{1.0, 1.0}, {1.0, 0.0}, {0.0, 1.0}]
    end
  end

  test "the calibration clicks ship where the engine looks for them" do
    assert File.regular?(Audio.sound_path("clicks_90.mp3"))
  end
end
