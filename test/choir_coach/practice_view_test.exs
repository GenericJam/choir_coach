defmodule ChoirCoach.PracticeViewTest do
  use ExUnit.Case, async: true

  alias ChoirCoach.{Feedback, PracticeView, Song, Style}

  # One bar in G major: the two notes the staff should put on its bottom and
  # top lines in `clef`.
  defp staff_ops(clef, bottom, top) do
    song =
      Song.build(
        title: "Test",
        clef: clef,
        key: 1,
        tempo_bpm: 120,
        beats_per_bar: 4,
        first_bar: 1,
        bars: [[n: {bottom, 1, "a"}, n: {top, 1, "b"}, rest: 2]]
      )

    PracticeView.ops(%{
      song: song,
      t_ms: 0,
      width: 400.0,
      height: 600.0,
      semitone: 40.0,
      center_midi: 60.0,
      trace: [],
      feedback: Feedback.new(),
      now_ms: 0
    })
    |> List.flatten()
  end

  # Staff line ys, top first: full-width horizontal staff-line strokes.
  defp staff_lines(ops) do
    alpha = Style.alpha(:staff_line)

    for(%{op: :line, x1: 0, y1: y, y2: y, x2: 400.0, opacity: ^alpha} <- ops, do: y)
    |> Enum.sort()
  end

  # Note-head centres (12-point ellipses), in note order.
  defp head_ys(ops) do
    for %{op: :path, points: pts} <- ops, Enum.count_until(pts, 13) == 12 do
      Float.round(Enum.sum(Enum.map(pts, fn [_x, y] -> y end)) / 12, 1)
    end
  end

  defp first_sharp(ops) do
    ops
    |> Enum.filter(&match?(%{op: :text, text: "♯"}, &1))
    |> Enum.min_by(& &1.x)
  end

  test "the treble staff runs E4 to F5 and puts its first sharp on the F5 line" do
    bass = staff_ops(:bass, "G2", "A3")
    treble = staff_ops(:treble, "E4", "F#5")
    [top, f_line, _, _, bottom] = lines = staff_lines(treble)

    assert staff_lines(bass) == lines
    assert head_ys(bass) == [bottom, top]
    assert head_ys(treble) == [bottom, top]

    # Bass F♯ sits on the F3 line (second from the top), treble on the top line.
    assert first_sharp(treble).y - top == first_sharp(bass).y - f_line
  end
end
