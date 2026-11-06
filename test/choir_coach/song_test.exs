defmodule ChoirCoach.SongTest do
  use ExUnit.Case, async: true

  alias ChoirCoach.{Feedback, PracticeScreen, PracticeView, Song}

  defp song do
    Song.build(
      title: "Test",
      tempo_bpm: 120,
      beats_per_bar: 4,
      first_bar: 10,
      bars: [
        [rest: 1, n: {"C3", 1, "Glo-"}, n: {"D3", 1, "~Glo-"}, n: {"E3", 1, "ri-"}],
        [n: {"G3", 2, "a"}, rest: 2]
      ]
    )
  end

  test "a bar that doesn't add up is rejected with its number" do
    assert_raise ArgumentError, ~r/bar 11 has 3.5 beats/, fn ->
      Song.build(
        title: "x",
        tempo_bpm: 100,
        beats_per_bar: 4,
        first_bar: 10,
        bars: [[n: {"C3", 4, "a"}], [n: {"C3", 3.5, "b"}]]
      )
    end
  end

  test "notes are placed by bar and beat" do
    [c, d, _e, g] = song().notes
    assert c.start_ms == 500.0 and c.dur_ms == 500.0
    assert d.slur and d.lyric == "Glo-"
    assert g.start_ms == 2000.0 and g.bar == 11
    assert Song.duration_ms(song()) == 4000.0
  end

  test "a track offset and a stretched bar place notes and beats on the track timeline" do
    s =
      Song.build(
        title: "Test",
        tempo_bpm: 120,
        beats_per_bar: 4,
        first_bar: 1,
        start_ms: 300.0,
        # Bar 2 slows to half speed (a ritardando).
        bar_ms: %{2 => 4000.0},
        bars: [[n: {"C3", 4, "a"}], [n: {"D3", 2, "b"}, n: {"E3", 2, "c"}], [n: {"F3", 4, "d"}]]
      )

    assert Enum.map(s.notes, &{&1.start_ms, &1.dur_ms}) ==
             [{300.0, 2000.0}, {2300.0, 2000.0}, {4300.0, 2000.0}, {6300.0, 2000.0}]

    assert Song.start_ms(s) == 300.0
    assert Song.duration_ms(s) == 8300.0
    assert Song.bar_before(s, 3).start_ms == 2300.0
    assert Song.bar_before(s, 1) == nil

    # Beats inside the stretched bar are 1 s apart; the bar line is flagged.
    assert Song.beats_between(s, 2000, 5500) == [
             {2300.0, true},
             {3300.0, false},
             {4300.0, false},
             {5300.0, false}
           ]
  end

  describe "accidentals the staff prints" do
    defp accidentals(opts) do
      opts
      |> Keyword.merge(title: "t", tempo_bpm: 60, beats_per_bar: 4, first_bar: 1)
      |> Song.build()
      |> Map.fetch!(:notes)
      |> Enum.map(&{&1.name, &1.accidental})
    end

    test "the key signature covers its notes; others print once per bar, then naturals" do
      # D major: F♯ and C♯ are in the key.
      assert accidentals(
               key: 2,
               bars: [
                 [n: {"F#3", 1, "a"}, n: {"C3", 1, "b"}, n: {"C3", 1, "c"}, n: {"C#3", 1, "d"}],
                 [n: {"C3", 4, "e"}]
               ]
             ) == [
               {"F#3", nil},
               {"C3", :natural},
               {"C3", nil},
               {"C#3", :sharp},
               {"C3", :natural}
             ]
    end

    test "a note tied over the barline keeps its accidental without reprinting it" do
      assert accidentals(
               key: -2,
               bars: [
                 [rest: 3, n: {"E3", 1, "a"}],
                 [n: {"E3", 2, "~a"}, n: {"E3", 2, "b"}]
               ]
             ) == [{"E3", :natural}, {"E3", nil}, {"E3", :natural}]
    end

    test "after a key change, notes are spelled against the new key" do
      s =
        Song.build(
          title: "t",
          tempo_bpm: 60,
          beats_per_bar: 4,
          first_bar: 1,
          key: 0,
          key_changes: %{2 => 2},
          bars: [[n: {"F#3", 4, "a"}], [n: {"F#3", 2, "b"}, n: {"F3", 2, "c"}]]
        )

      assert Enum.map(s.notes, & &1.accidental) == [:sharp, nil, :natural]
      assert Enum.map(s.bars, & &1.key) == [0, 2]
    end
  end

  test "lookups across notes and rests" do
    s = song()
    assert Song.note_at(s, 250) == nil
    assert Song.note_at(s, 600).lyric == "Glo-"
    assert Song.next_note(s, 600).midi == 50
    assert Song.note_at(s, 3500) == nil
    assert Song.next_note(s, 3500) == nil
    assert Song.bar_at(s, 2100).number == 11
    assert Song.bar_start(s, 11) == 2000.0
  end

  test "readings are folded onto the written octave and gated to the notes" do
    # C3 (48) sounds 500–1000 ms; 0–500 is a rest.
    [down, up, wrong, early, rest, silent] =
      PracticeScreen.align_readings(song(), [
        {600, 36.2, 0.9},
        {600, 60.3, 0.9},
        {600, 51.0, 0.9},
        # 80 ms before the C3: an early entry, kept and folded.
        {420, 36.0, 0.9},
        # 250 ms before it: not the part being sung.
        {250, 60.0, 0.9},
        {600, nil, 0.0}
      ])

    assert_in_delta elem(down, 1), 48.2, 1.0e-9
    assert_in_delta elem(up, 1), 48.3, 1.0e-9
    assert elem(wrong, 1) == 51.0
    assert elem(early, 1) == 48.0
    assert rest == {250, nil, 0.0}
    assert silent == {600, nil, 0.0}
  end

  describe "current_cents/3" do
    test "measures the latest reading against its own note" do
      assert PracticeScreen.current_cents(song(), [{600, 48.2, 0.9}], 610) |> Float.round(6) ==
               20.0
    end

    test "a reading from the previous note is stale, not a huge miss" do
      # Reading taken on C3, frame lands just after D3 starts.
      assert PracticeScreen.current_cents(song(), [{990, 48.0, 0.9}], 1005) == :stale
    end

    test "rests and unsure readings are silence" do
      assert PracticeScreen.current_cents(song(), [{250, 48.0, 0.9}], 250) == nil
      assert PracticeScreen.current_cents(song(), [{600, 48.0, 0.1}], 610) == nil
    end

    test "one dropout isn't a breath, but 150 ms of nothing is" do
      trace = [{600, 48.2, 0.9}, {610, nil, 0.0}, {620, nil, 0.0}]
      assert PracticeScreen.current_cents(song(), trace, 630) |> Float.round(6) == 20.0
      assert PracticeScreen.current_cents(song(), trace, 800) == nil
    end
  end

  describe "trace_runs/2" do
    defp runs(trace, t) do
      frame = %{
        song: song(),
        t_ms: t,
        width: 400.0,
        height: 600.0,
        semitone: 40.0,
        center_midi: 50.0,
        trace: trace,
        feedback: Feedback.new(),
        now_ms: t
      }

      PracticeView.trace_runs(frame, PracticeView.geometry(frame))
    end

    # One reading every 20 ms (every other 10 ms slot is drawn).
    defp readings(from, to, fun), do: for(t <- from..to//10, do: fun.(t))

    test "low confidence draws dotted, silence breaks the line" do
      trace =
        readings(600, 700, &{&1, 48.0, 0.9}) ++
          readings(710, 800, &{&1, 48.0, 0.3}) ++
          readings(810, 850, &{&1, nil, 0.0}) ++
          readings(860, 990, &{&1, 48.0, 0.9})

      assert Enum.map(runs(trace, 990), & &1.style) == [:solid, :dotted, :solid]
    end

    test "a colour change starts a new run sharing the joining point" do
      trace = readings(600, 700, &{&1, 48.0, 0.9}) ++ readings(710, 800, &{&1, 48.3, 0.9})
      [a, b] = runs(trace, 800)
      assert {a.bucket, b.bucket} == {0, 30}
      assert List.last(a.points) == hd(b.points)
    end

    test "a leap of more than 3 semitones breaks the line instead of drawing a spike" do
      trace = readings(600, 700, &{&1, 48.0, 0.9}) ++ readings(710, 800, &{&1, 52.0, 0.9})
      [a, b] = runs(trace, 800)
      refute List.last(a.points) == hd(b.points)
    end
  end
end
