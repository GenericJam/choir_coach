defmodule ChoirCoach.Roles do
  @moduledoc """
  Marks each stretch of a part as following the melody or singing its own
  line, so the practice screen can say "Melody" (sing with everyone) or
  "Part" (your own notes).

  Note by note first: a note follows the melody when, for at least half
  its length, the melody sounds the same note in some octave (basses
  doubling the tune an octave down count). Then, within each phrase (a run
  of notes without a rest of a beat or more), the label only changes for a
  stretch of at least 2 beats and 2 notes: a shorter one (a shared chord
  tone, a held note under a moving tune) takes its neighbours' label. A
  phrase with no stretch that long ("Ho- ly!") goes by the majority of its
  time. A part often moves between the tune and a harmony inside one
  phrase, which a label per whole phrase got wrong.
  """

  alias ChoirCoach.Song

  # A note follows the tune when it shares its pitch class this much.
  @note_share 0.5
  # A rest at least this long (in beats) ends a phrase.
  @phrase_break_beats 1.0
  # The shortest stretch with a label of its own.
  @min_run_beats 2.0
  @min_run_notes 2

  @doc "The part with every note's `role` set against the melody."
  @spec mark(Song.t(), Song.t()) :: Song.t()
  def mark(%Song{} = part, %Song{} = melody) do
    tune = Enum.map(melody.notes, &{&1.start_ms, &1.start_ms + &1.dur_ms, rem(&1.midi, 12)})

    notes =
      part
      |> phrases()
      |> Enum.flat_map(fn phrase ->
        phrase |> Enum.map(&{follows?(&1, tune), &1}) |> runs() |> label()
      end)
      |> Enum.flat_map(fn {follows, notes} ->
        role = if follows, do: :melody, else: :part
        Enum.map(notes, &%{&1 | role: role})
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

  # Whether, for at least @note_share of the note, the melody sounds the
  # same pitch class (exact overlap in ms).
  defp follows?(note, tune) do
    s = note.start_ms
    e = s + note.dur_ms
    pc = rem(note.midi, 12)

    shared =
      for {ms, me, ^pc} <- tune, ms < e and me > s, reduce: 0.0 do
        acc -> acc + min(e, me) - max(s, ms)
      end

    shared >= @note_share * note.dur_ms
  end

  # Consecutive notes with the same verdict: [{follows, notes}].
  defp runs(marked) do
    marked
    |> Enum.chunk_by(&elem(&1, 0))
    |> Enum.map(fn [{follows, _} | _] = run -> {follows, Enum.map(run, &elem(&1, 1))} end)
  end

  # A phrase with a stretch long enough to stand: fold the short ones in.
  # Otherwise one label for it all: Melody when more than half its sounding
  # time follows the tune (slow and fast beats weigh by how long they last).
  defp label(runs) do
    if Enum.any?(runs, &stands?/1) do
      smooth(runs)
    else
      {on, off} = Enum.split_with(runs, &elem(&1, 0))
      ms = fn rs -> rs |> Enum.flat_map(&elem(&1, 1)) |> Enum.map(& &1.dur_ms) |> Enum.sum() end
      [{ms.(on) > ms.(off), Enum.flat_map(runs, &elem(&1, 1))}]
    end
  end

  # Turn the shortest run too short to stand into its neighbours' label
  # (runs alternate, so both neighbours share one), merge, and repeat until
  # every run stands.
  defp smooth([_] = runs), do: runs

  defp smooth(runs) do
    case runs |> Enum.with_index() |> Enum.reject(fn {run, _i} -> stands?(run) end) do
      [] ->
        runs

      short ->
        {{follows, notes}, i} = Enum.min_by(short, fn {run, _i} -> run_beats(run) end)

        runs
        |> List.replace_at(i, {not follows, notes})
        |> Enum.chunk_by(&elem(&1, 0))
        |> Enum.map(fn [{f, _} | _] = same -> {f, Enum.flat_map(same, &elem(&1, 1))} end)
        |> smooth()
    end
  end

  defp stands?({_follows, notes} = run),
    do: length(notes) >= @min_run_notes and run_beats(run) >= @min_run_beats - 0.01

  defp run_beats({_follows, notes}), do: notes |> Enum.map(& &1.beats) |> Enum.sum()
end
