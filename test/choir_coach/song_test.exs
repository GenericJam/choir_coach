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
  end
end
