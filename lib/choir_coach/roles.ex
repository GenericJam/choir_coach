defmodule ChoirCoach.Roles do
  @moduledoc """
  Marks each phrase of a part as following the melody or singing its own
  line, so the practice screen can say "Melody" (sing with everyone) or
  "Part" (your own notes).

  A phrase is a run of notes without a rest of a beat or more. It follows
  the melody when, for at least #{round(0.75 * 100)}% of the time it sounds, the melody
  sounds the same note in some octave (basses doubling the tune an octave
  down count). Judging whole phrases keeps one shared chord tone in a
  harmony passage from flipping the label for a single note.
  """

  alias ChoirCoach.Song

  @share 0.75
  # A rest at least this long (in beats) ends a phrase.
  @phrase_break_beats 1.0

  @doc "The part with every note's `role` set against the melody."
  @spec mark(Song.t(), Song.t()) :: Song.t()
  def mark(%Song{} = part, %Song{} = melody) do
    tune = Enum.map(melody.notes, &{&1.start_ms, &1.start_ms + &1.dur_ms, rem(&1.midi, 12)})

    notes =
      part
      |> phrases()
      |> Enum.flat_map(fn phrase ->
        role = if follows?(phrase, tune), do: :melody, else: :part
        Enum.map(phrase, &%{&1 | role: role})
      end)

    %{part | notes: notes}
  end

  @doc "The role of the note sounding at `t_ms`, else of the next one; nil when unmarked."
  @spec at(Song.t(), number()) :: :melody | :part | nil
  def at(song, t_ms) do
    case Song.note_at(song, t_ms) || Song.next_note(song, t_ms) do
      nil -> nil
      note -> note.role
    end
  end

  defp phrases(%Song{notes: notes} = song) do
    notes
    |> Enum.chunk_while(
      [],
      fn
        note, [] ->
          {:cont, [note]}

        note, [prev | _] = acc ->
          rest_beats = beats_between(song, prev.start_ms + prev.dur_ms, note.start_ms)

          if rest_beats >= @phrase_break_beats - 0.01,
            do: {:cont, Enum.reverse(acc), [note]},
            else: {:cont, [note | acc]}
      end,
      fn
        [] -> {:cont, []}
        acc -> {:cont, Enum.reverse(acc), []}
      end
    )
  end

  # Beats in `[from, to)`, bar by bar, so a rest across a tempo change or a
  # stretched bar is counted in the beats it actually spans.
  defp beats_between(_song, from, to) when to <= from, do: 0.0

  defp beats_between(%Song{bars: bars}, from, to) do
    bars
    |> Enum.map(fn %{start_ms: s, dur_ms: d, beats: n} ->
      overlap = min(to, s + d) - max(from, s)
      if overlap > 0, do: overlap / (d / n), else: 0.0
    end)
    |> Enum.sum()
  end

  # Whether, for at least @share of the phrase's sounding time, the melody
  # sounds the same pitch class: measured as exact overlap in ms, so slow
  # and fast beats weigh by how long they last.
  defp follows?(phrase, tune) do
    {same, total} =
      Enum.reduce(phrase, {0.0, 0.0}, fn note, {same, total} ->
        s = note.start_ms
        e = s + note.dur_ms
        pc = rem(note.midi, 12)

        shared =
          for {ms, me, ^pc} <- tune, ms < e and me > s, reduce: 0.0 do
            acc -> acc + min(e, me) - max(s, ms)
          end

        {same + shared, total + note.dur_ms}
      end)

    total > 0 and same / total >= @share
  end
end
