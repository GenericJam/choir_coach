defmodule ChoirCoach.MixTest do
  use ExUnit.Case, async: true

  alias ChoirCoach.Mix

  @split %{file: "song/split.mp3", bar1_ms: 409.0, voice: :right, label: "Choir"}
  @demo %{file: "song/demo.mp3", bar1_ms: 18_449.0, voice: :mixed, label: "Demo"}
  @bass %{
    piano: %{file: "song/piano_bass.mp3", bar1_ms: 358.0, voice: :left, label: "Piano"},
    rehearsal: %{file: "song/bass.mp3", bar1_ms: 358.0, voice: :left, label: "Rehearsal"},
    split: @split,
    demo: @demo
  }
  @melody %{
    rehearsal: %{file: "song/soprano.mp3", bar1_ms: 358.0, voice: :left, label: "Rehearsal"},
    split: @split,
    demo: @demo
  }

  defp row(mix, id), do: Enum.find(mix.rows, &(&1.id == id))

  describe "row gains" do
    test "balance −100 / 0 / +100 places the row fully left, centre, fully right" do
      r = %{on: true, level: 80, balance: 0}
      assert Mix.row_gains(r, false) == {0.8, 0.8}
      assert Mix.row_gains(%{r | balance: -100}, false) == {0.8, 0.0}
      assert Mix.row_gains(%{r | balance: 100}, false) == {0.0, 0.8}
    end

    test "a partial balance only turns the far ear down" do
      {l, r} = Mix.row_gains(%{on: true, level: 60, balance: 70}, false)
      assert_in_delta l, 0.18, 1.0e-9
      assert r == 0.6
    end

    test "mono averages the two ears" do
      {l, r} = Mix.row_gains(%{on: true, level: 80, balance: 100}, true)
      assert {l, r} == {0.4, 0.4}
    end

    test "an off row is silent" do
      assert Mix.row_gains(%{on: false, level: 80, balance: 0}, false) == {0.0, 0.0}
    end
  end

  describe "rows" do
    test "bass has a piano row; melody (no piano track) does not" do
      assert Enum.map(Mix.new(:bass, @bass).rows, & &1.id) == [:part_piano, :voices, :band]
      assert Enum.map(Mix.new(:melody, @melody).rows, & &1.id) == [:voices, :band]
      assert row(Mix.new(:bass, @bass), :part_piano).label == "Bass on piano"
      assert row(Mix.new(:melody, @melody), :voices).label == "Soprano rehearsal"
    end

    test "the default is Rehearsal: the part 80 C, band 70 C, the rest off" do
      bass = Mix.new(:bass, @bass)
      assert Mix.caption(bass) == "Rehearsal"
      assert %{on: true, level: 80, balance: 0} = row(bass, :part_piano)
      assert %{on: true, level: 70, balance: 0} = row(bass, :band)
      assert %{on: false} = row(bass, :voices)

      melody = Mix.new(:melody, @melody)
      assert %{on: true, level: 80, balance: 0} = row(melody, :voices)
      assert %{on: true, level: 70, balance: 0} = row(melody, :band)
    end
  end

  describe "presets and caption" do
    test "chips in order; My mix only when one is saved" do
      mix = Mix.new(:bass, @bass)
      ids = mix |> Mix.presets() |> Enum.map(& &1.id)
      assert ids == [:rehearsal, :right_ear, :full_choir, :demo]

      labels = mix |> Mix.presets(mix) |> Enum.map(& &1.label)
      assert labels == ["Rehearsal", "Me in right ear", "Full choir", "Demo", "My mix"]
    end

    test "Me in right ear puts the part right and the band left" do
      mix = Mix.apply_preset(Mix.new(:bass, @bass), :right_ear)
      # The transport's caption is short: it must fit a 48 dp control.
      assert Mix.caption(mix) == "Right ear"
      assert %{on: true, level: 75, balance: 80} = row(mix, :part_piano)
      assert %{on: true, level: 60, balance: -60} = row(mix, :band)
      assert Mix.value_label(row(mix, :part_piano), false) == "75 · R 80"
      assert Mix.value_label(row(mix, :band), false) == "60 · L 60"
    end

    test "touching a row makes it Custom and leaves a recording" do
      mix = Mix.new(:bass, @bass) |> Mix.apply_preset(:full_choir)
      assert Mix.caption(mix) == "Full choir"

      mix = Mix.set_row(mix, :band, :level, 42.6)
      assert Mix.caption(mix) == "Custom"
      assert mix.recording == nil
      assert row(mix, :band).level == 43

      mix = Mix.apply_preset(mix, :rehearsal) |> Mix.toggle_row(:voices)
      assert Mix.caption(mix) == "Custom"
      assert row(mix, :voices).on
    end

    test "levels and balances are clamped" do
      mix = Mix.new(:bass, @bass)
      assert row(Mix.set_row(mix, :band, :level, 140), :band).level == 100
      assert row(Mix.set_row(mix, :band, :balance, -300), :band).balance == -100
    end

    test "My mix restores the saved rows" do
      saved =
        Mix.new(:bass, @bass) |> Mix.set_row(:band, :balance, -40) |> Mix.toggle_row(:voices)

      mix = Mix.apply_preset(Mix.new(:bass, @bass), :my_mix, saved)

      assert Mix.caption(mix) == "My mix"
      assert row(mix, :band).balance == -40
      assert row(mix, :voices).on

      assert Mix.apply_preset(mix, :rehearsal) |> Mix.apply_preset(:my_mix) |> Mix.caption() ==
               "Rehearsal"
    end
  end

  describe "load_spec and lane gains" do
    test "bass: piano left, then rehearsal left and right; guide is the piano" do
      mix = Mix.new(:bass, @bass)

      assert Mix.load_spec(mix, @bass) == %{
               bar1_ms: 358.0,
               sources: [
                 %{file: "song/piano_bass.mp3", channels: [:left]},
                 %{file: "song/bass.mp3", channels: [:left, :right]}
               ],
               guide_lane: 0
             }

      # piano 80 C, voices off, band 70 C
      assert Mix.lane_gains(mix, false) == [{0.8, 0.8}, {0.0, 0.0}, {0.7, 0.7}]
    end

    test "melody: rehearsal left (voices) and right (band); guide is the voices" do
      mix = Mix.new(:melody, @melody) |> Mix.apply_preset(:right_ear)

      assert Mix.load_spec(mix, @melody) == %{
               bar1_ms: 358.0,
               sources: [%{file: "song/soprano.mp3", channels: [:left, :right]}],
               guide_lane: 0
             }

      [{vl, vr}, {bl, br}] = Mix.lane_gains(mix, false)
      assert_in_delta vl, 0.15, 1.0e-9
      assert vr == 0.75
      assert bl == 0.6
      assert_in_delta br, 0.24, 1.0e-9
    end

    test "a recording plays its own file as recorded" do
      mix = Mix.new(:bass, @bass) |> Mix.apply_preset(:demo)

      assert Mix.load_spec(mix, @bass) == %{
               bar1_ms: 18_449.0,
               sources: [%{file: "song/demo.mp3", channels: [:left, :right]}],
               guide_lane: nil
             }

      assert Mix.lane_gains(mix, false) == [{1.0, 0.0}, {0.0, 1.0}]
      assert Mix.lane_gains(mix, true) == [{0.5, 0.5}, {0.5, 0.5}]

      assert Mix.load_spec(Mix.apply_preset(mix, :full_choir), @bass).sources ==
               [%{file: "song/split.mp3", channels: [:left, :right]}]
    end
  end

  test "same_load?: row changes and row presets need only set_mix" do
    bass = Mix.new(:bass, @bass)
    choir = Mix.apply_preset(bass, :full_choir)

    assert Mix.same_load?(bass, Mix.apply_preset(bass, :right_ear))
    assert Mix.same_load?(bass, Mix.set_row(bass, :voices, :level, 10))
    assert Mix.same_load?(choir, Mix.apply_preset(Mix.new(:melody, @melody), :full_choir))
    refute Mix.same_load?(bass, choir)
    refute Mix.same_load?(choir, Mix.apply_preset(bass, :demo))
    refute Mix.same_load?(bass, Mix.new(:melody, @melody))
  end

  test "value labels show the balance side, or a dash on mono" do
    assert Mix.value_label(%{level: 80, balance: 0}, false) == "80 · C"
    assert Mix.value_label(%{level: 40, balance: -60}, false) == "40 · L 60"
    assert Mix.value_label(%{level: 60, balance: 70}, true) == "60 · —"
  end

  test "ear levels are the loudest row in each ear" do
    mix = Mix.new(:bass, @bass) |> Mix.apply_preset(:right_ear)
    assert Mix.ear_levels(mix, false) == {0.6, 0.75}
    {l, r} = Mix.ear_levels(mix, true)
    assert l == r
    assert Mix.ear_levels(Mix.apply_preset(mix, :demo), false) == {1.0, 1.0}
  end
end
