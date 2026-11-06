defmodule ChoirCoach.Song do
  @moduledoc """
  One voice part of a song as a time-ordered list of sung notes.

  Times are milliseconds on the rehearsal track's timeline, so the playback
  position is directly a song time. Gaps between notes are rests or breaths.
  A song is built from bars written the way they read on the page, so a
  transcription can be checked against the score bar by bar:

      Song.build(
        title: "What a Glorious Night",
        tempo_bpm: 105,
        beats_per_bar: 4,
        key: 0,
        first_bar: 20,
        start_ms: 358.0,
        bar_ms: %{112 => 3_280.0},
        bars: [
          [rest: 0.5, n: {"G3", 0.5, "The"}, n: {"A3", 0.5, "shep-"}, ...],
          ...
        ]
      )

  Durations are in beats. `{:n, {name, beats, lyric}}` is a sung note,
  `{:rest, beats}` a rest. A lyric starting with `~` continues the previous
  syllable (a slur or tie onto a new pitch). Names are written pitches with
  the key signature applied (`"F#3"` in D major, `"Bb2"` in B♭ major), so
  each note keeps its spelling for the staff.

  `start_ms` is where the first bar falls on the track (default 0). Every bar
  lasts its beat count at the current tempo unless `bar_ms` gives its length
  in ms (a ritardando, a fermata); its notes stretch proportionally.

  Changes take effect from the bar given and last until the next change:
  `key_changes: %{57 => 4}` (key in fifths: sharps positive, flats negative),
  `meter: %{30 => 2, 31 => 4}` (beats per bar), `tempo: %{61 => 96}`.
  """

  alias ChoirCoach.Pitch

  defmodule Note do
    @moduledoc """
    A sung note: absolute start, duration, MIDI pitch, lyric and bar, plus
    its spelling: `name` as written, `step` (staff position of its letter,
    see `ChoirCoach.Pitch.staff_step/1`) and the `accidental` the staff
    prints (nil when the key signature or an earlier note in the bar covers it).
    """
    @enforce_keys [:start_ms, :dur_ms, :midi, :lyric, :bar, :beats, :name, :step]
    defstruct [
      :start_ms,
      :dur_ms,
      :midi,
      :lyric,
      :bar,
      :beats,
      :name,
      :step,
      :accidental,
      slur: false
    ]

    @type t :: %__MODULE__{
            start_ms: float(),
            dur_ms: float(),
            midi: integer(),
            lyric: String.t(),
            bar: pos_integer(),
            beats: number(),
            name: String.t(),
            step: integer(),
            accidental: nil | :sharp | :flat | :natural,
            slur: boolean()
          }
  end

  @enforce_keys [:title, :part, :tempo_bpm, :beats_per_bar, :notes, :bars]
  defstruct [:title, :part, :clef, :key, :tempo_bpm, :beats_per_bar, :notes, :bars]

  @type bar :: %{
          number: pos_integer(),
          start_ms: float(),
          dur_ms: float(),
          beats: number(),
          key: integer()
        }
  @type t :: %__MODULE__{
          title: String.t(),
          part: atom(),
          clef: :bass | :treble,
          key: integer(),
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
    key = Keyword.get(opts, :key, 0)
    first_bar = Keyword.fetch!(opts, :first_bar)
    bar_ms = Keyword.get(opts, :bar_ms, %{})
    tempos = Keyword.get(opts, :tempo, %{})
    meters = Keyword.get(opts, :meter, %{})
    keys = Keyword.get(opts, :key_changes, %{})
    start = Keyword.get(opts, :start_ms, 0.0) * 1.0

    {notes, bars, _} =
      opts
      |> Keyword.fetch!(:bars)
      |> Enum.with_index(first_bar)
      |> Enum.reduce({[], [], {start, tempo, beats_per_bar, key}}, fn {events, number},
                                                                      {notes, bars,
                                                                       {bar_start, tempo, beats,
                                                                        key}} ->
        tempo = Map.get(tempos, number, tempo)
        beats = Map.get(meters, number, beats)
        key = Map.get(keys, number, key)
        check_bar!(events, number, beats)
        dur = Map.get(bar_ms, number, beats * 60_000.0 / tempo) * 1.0
        bar_notes = place_bar(events, number, bar_start, dur / beats, key)
        bar = %{number: number, start_ms: bar_start, dur_ms: dur, beats: beats, key: key}
        {[bar_notes | notes], [bar | bars], {bar_start + dur, tempo, beats, key}}
      end)

    %__MODULE__{
      title: Keyword.fetch!(opts, :title),
      part: Keyword.get(opts, :part, :bass),
      clef: Keyword.get(opts, :clef, :bass),
      key: key,
      tempo_bpm: tempo,
      beats_per_bar: beats_per_bar,
      notes: notes |> Enum.reverse() |> List.flatten(),
      bars: Enum.reverse(bars)
    }
  end

  @doc "The song's opening key as a name, e.g. \"D major\"."
  @spec key_name(t()) :: String.t()
  def key_name(%__MODULE__{key: key}), do: Pitch.major_key_name(key)

  defp check_bar!(events, number, beats) do
    total = events |> Enum.map(&event_beats/1) |> Enum.sum()

    if abs(total - beats) > 1.0e-6 do
      raise ArgumentError, "bar #{number} has #{total} beats, expected #{beats}"
    end
  end

  defp event_beats({:rest, beats}), do: beats
  defp event_beats({:n, {_name, beats, _lyric}}), do: beats

  # Notes of one bar. `shown` tracks the alteration in force on each staff
  # step, so an accidental prints once per bar, as on the page, and a return
  # to the key signature's note gets its natural (or sharp/flat) back.
  defp place_bar(events, number, bar_start, beat_ms, key) do
    {notes, _} =
      Enum.reduce(events, {[], {0.0, %{}}}, fn
        {:rest, beats}, {acc, {offset, shown}} ->
          {acc, {offset + beats, shown}}

        {:n, {name, beats, lyric}}, {acc, {offset, shown}} ->
          {slur, lyric} =
            case lyric do
              "~" <> rest -> {true, rest}
              lyric -> {false, lyric}
            end

          %{midi: midi, step: step, alter: alter} = Pitch.spell(name)
          in_force = Map.get_lazy(shown, step, fn -> Pitch.key_alter(key, step) end)

          note = %Note{
            start_ms: bar_start + offset * beat_ms,
            dur_ms: beats * beat_ms,
            midi: midi,
            lyric: lyric,
            bar: number,
            beats: beats,
            name: name,
            step: step,
            accidental: if(alter != in_force, do: accidental(alter)),
            slur: slur
          }

          {[note | acc], {offset + beats, Map.put(shown, step, alter)}}
      end)

    Enum.reverse(notes)
  end

  defp accidental(1), do: :sharp
  defp accidental(-1), do: :flat
  defp accidental(0), do: :natural

  @doc "End of the song in ms (end of its last bar)."
  @spec duration_ms(t()) :: float()
  def duration_ms(%__MODULE__{bars: bars}) do
    %{start_ms: start, dur_ms: dur} = List.last(bars)
    start + dur
  end

  @doc "Start of the song's first bar in ms."
  @spec start_ms(t()) :: float()
  def start_ms(%__MODULE__{bars: [%{start_ms: start} | _]}), do: start

  @doc "Song times of every beat that starts in `[from_ms, to_ms]`, flagged when it opens a bar."
  @spec beats_between(t(), number(), number()) :: [{float(), boolean()}]
  def beats_between(%__MODULE__{bars: bars}, from_ms, to_ms) do
    for %{start_ms: s, dur_ms: d, beats: n} <- bars,
        s <= to_ms and s + d >= from_ms,
        i <- 0..(n - 1),
        t = s + i * d / n,
        t >= from_ms and t <= to_ms,
        do: {t, i == 0}
  end

  @doc "Milliseconds per beat in the bar playing at `t_ms`."
  @spec beat_ms(t(), number()) :: float()
  def beat_ms(song, t_ms) do
    %{dur_ms: d, beats: n} = bar_at(song, t_ms)
    d / n
  end

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

  @doc "The bar before bar `number`, or nil for the first."
  @spec bar_before(t(), pos_integer()) :: bar() | nil
  def bar_before(%__MODULE__{bars: bars}, number), do: Enum.find(bars, &(&1.number == number - 1))

  @doc """
  The note sounding at `t_ms`, or else the nearest note starting or ending
  within `margin_ms` of it (an early or late entry); nil in a rest.
  """
  @spec note_near(t(), number(), number()) :: Note.t() | nil
  def note_near(%__MODULE__{notes: notes} = song, t_ms, margin_ms) do
    note_at(song, t_ms) ||
      notes
      |> Enum.map(&{&1, gap(&1, t_ms)})
      |> Enum.filter(fn {_n, d} -> d <= margin_ms end)
      |> Enum.min_by(&elem(&1, 1), fn -> {nil, nil} end)
      |> elem(0)
  end

  defp gap(note, t), do: max(note.start_ms - t, t - (note.start_ms + note.dur_ms))
end
