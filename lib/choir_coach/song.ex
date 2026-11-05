defmodule ChoirCoach.Song do
  @moduledoc """
  One voice part of a song as a time-ordered list of sung notes.

  Times are milliseconds from the start of the playable section. Gaps between
  notes are rests or breaths. A song is built from bars written the way they
  read on the page, so a transcription can be checked against the score bar
  by bar:

      Song.build(
        title: "What a Glorious Night",
        tempo_bpm: 105,
        beats_per_bar: 4,
        first_bar: 20,
        bars: [
          [rest: 0.5, n: {"G3", 0.5, "The"}, n: {"A3", 0.5, "shep-"}, ...],
          ...
        ]
      )

  Durations are in beats. `{:n, {name, beats, lyric}}` is a sung note,
  `{:rest, beats}` a rest. A lyric starting with `~` continues the previous
  syllable (a slur or tie onto a new pitch).
  """

  alias ChoirCoach.Pitch

  defmodule Note do
    @moduledoc "A sung note: absolute start, duration, MIDI pitch, lyric and bar."
    @enforce_keys [:start_ms, :dur_ms, :midi, :lyric, :bar, :beats]
    defstruct [:start_ms, :dur_ms, :midi, :lyric, :bar, :beats, slur: false]

    @type t :: %__MODULE__{
            start_ms: float(),
            dur_ms: float(),
            midi: integer(),
            lyric: String.t(),
            bar: pos_integer(),
            beats: number(),
            slur: boolean()
          }
  end

  @enforce_keys [:title, :part, :tempo_bpm, :beats_per_bar, :notes, :bars]
  defstruct [:title, :part, :clef, :key_name, :tempo_bpm, :beats_per_bar, :notes, :bars]

  @type bar :: %{number: pos_integer(), start_ms: float()}
  @type t :: %__MODULE__{
          title: String.t(),
          part: atom(),
          clef: :bass | :treble,
          key_name: String.t(),
          tempo_bpm: number(),
          beats_per_bar: pos_integer(),
          notes: [Note.t()],
          bars: [bar()]
        }

  @doc "Build a song from bar-by-bar notation. Raises if a bar's beats don't add up."
  @spec build(keyword()) :: t()
  def build(opts) do
    tempo = Keyword.fetch!(opts, :tempo_bpm)
    beats_per_bar = Keyword.fetch!(opts, :beats_per_bar)
    first_bar = Keyword.fetch!(opts, :first_bar)
    beat_ms = 60_000.0 / tempo

    {notes, bars} =
      opts
      |> Keyword.fetch!(:bars)
      |> Enum.with_index(first_bar)
      |> Enum.reduce({[], []}, fn {events, number}, {notes, bars} ->
        bar_start = (number - first_bar) * beats_per_bar * beat_ms
        check_bar!(events, number, beats_per_bar)

        {bar_notes, _} =
          Enum.flat_map_reduce(events, 0.0, &place(&1, &2, number, bar_start, beat_ms))

        {notes ++ bar_notes, bars ++ [%{number: number, start_ms: bar_start}]}
      end)

    %__MODULE__{
      title: Keyword.fetch!(opts, :title),
      part: Keyword.get(opts, :part, :bass),
      clef: Keyword.get(opts, :clef, :bass),
      key_name: Keyword.get(opts, :key_name, "C major"),
      tempo_bpm: tempo,
      beats_per_bar: beats_per_bar,
      notes: notes,
      bars: bars
    }
  end

  defp check_bar!(events, number, beats_per_bar) do
    total = events |> Enum.map(&event_beats/1) |> Enum.sum()

    if abs(total - beats_per_bar) > 1.0e-6 do
      raise ArgumentError, "bar #{number} has #{total} beats, expected #{beats_per_bar}"
    end
  end

  defp event_beats({:rest, beats}), do: beats
  defp event_beats({:n, {_name, beats, _lyric}}), do: beats

  defp place({:rest, beats}, offset, _number, _bar_start, _beat_ms), do: {[], offset + beats}

  defp place({:n, {name, beats, lyric}}, offset, number, bar_start, beat_ms) do
    {slur, lyric} =
      case lyric do
        "~" <> rest -> {true, rest}
        lyric -> {false, lyric}
      end

    note = %Note{
      start_ms: bar_start + offset * beat_ms,
      dur_ms: beats * beat_ms,
      midi: Pitch.parse(name),
      lyric: lyric,
      bar: number,
      beats: beats,
      slur: slur
    }

    {[note], offset + beats}
  end

  @doc "Length of the song in ms (end of its last bar)."
  @spec duration_ms(t()) :: float()
  def duration_ms(%__MODULE__{bars: bars} = song) do
    %{start_ms: last} = List.last(bars)
    last + song.beats_per_bar * beat_ms(song)
  end

  @doc "Milliseconds per beat."
  @spec beat_ms(t()) :: float()
  def beat_ms(%__MODULE__{tempo_bpm: tempo}), do: 60_000.0 / tempo

  @doc "The note sounding at `t_ms`, or nil during a rest."
  @spec note_at(t(), number()) :: Note.t() | nil
  def note_at(%__MODULE__{notes: notes}, t_ms) do
    Enum.find(notes, fn n -> t_ms >= n.start_ms and t_ms < n.start_ms + n.dur_ms end)
  end

  @doc "The first note starting strictly after `t_ms`, or nil at the end."
  @spec next_note(t(), number()) :: Note.t() | nil
  def next_note(%__MODULE__{notes: notes}, t_ms), do: Enum.find(notes, &(&1.start_ms > t_ms))

  @doc "Notes overlapping the window `[from_ms, to_ms)`."
  @spec notes_between(t(), number(), number()) :: [Note.t()]
  def notes_between(%__MODULE__{notes: notes}, from_ms, to_ms) do
    Enum.filter(notes, fn n -> n.start_ms < to_ms and n.start_ms + n.dur_ms > from_ms end)
  end

  @doc "The bar containing `t_ms` (the last bar once past the end)."
  @spec bar_at(t(), number()) :: bar()
  def bar_at(%__MODULE__{bars: bars}, t_ms) do
    bars |> Enum.take_while(&(&1.start_ms <= t_ms)) |> List.last() || hd(bars)
  end

  @doc "Start time of a bar by its printed number."
  @spec bar_start(t(), pos_integer()) :: float()
  def bar_start(%__MODULE__{bars: bars}, number) do
    %{start_ms: start} = Enum.find(bars, &(&1.number == number)) || hd(bars)
    start
  end
end
