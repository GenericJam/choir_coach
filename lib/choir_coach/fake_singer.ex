defmodule ChoirCoach.FakeSinger do
  @moduledoc """
  A deterministic stand-in for the pitch detector, so the practice screen can
  be built and reviewed before the audio engine exists.

  `sample/2` is a pure function of song time. Each sung note gets an error
  from `@script`, written phrase by phrase so every feedback state lasts long
  enough to read: on pitch, a little low, drifting high, far low with a
  correction mid-note, and silence during rests. On top of that, like a real
  voice: a short scoop up into each new syllable, gentle vibrato on long
  notes, low confidence while the onset settles, and a glide across slurred
  notes.
  """

  alias ChoirCoach.Song

  @type sample :: %{midi: float(), confidence: float()} | nil

  # Cents error per note, by note index; a {from, to} pair corrects across the
  # note. Notes past the end of the script are sung on pitch.
  @script [
    # The shepherds came to — on pitch
    2,
    4,
    3,
    1,
    5,
    # see the Ba-by — a little low
    -18,
    -20,
    -22,
    -16,
    -20,
    # stood by His mother's side — drifting high, corrected on the held "side"
    6,
    14,
    20,
    26,
    34,
    40,
    {45, 6},
    # Here laid the Savior — low, corrected on "ior"
    -30,
    -36,
    -40,
    -42,
    {-45, -5},
    # inside a manger — on pitch with a little wobble
    3,
    -4,
    5,
    -2,
    2,
    0,
    # Oh, what a glorious night — a little high, settling
    16,
    18,
    20,
    14,
    8,
    4,
    2
  ]

  @scoop_ms 90
  @scoop_cents -30
  @onset_unsure_ms 40
  @vibrato_delay_ms 250
  @vibrato_cents 6.0
  @vibrato_hz 5.2
  @release_ms 50

  @doc """
  The fake detector's reading at `t_ms`: fractional MIDI pitch and confidence
  (0..1), or nil when nothing is being sung.
  """
  @spec sample(Song.t(), number()) :: sample()
  def sample(%Song{notes: notes} = song, t_ms) do
    case Enum.find_index(notes, &(t_ms >= &1.start_ms and t_ms < &1.start_ms + &1.dur_ms)) do
      nil -> nil
      index -> voice(song, Enum.at(notes, index), index, t_ms)
    end
  end

  defp voice(song, note, index, t_ms) do
    into = t_ms - note.start_ms
    left = note.start_ms + note.dur_ms - t_ms
    previous = if index > 0, do: Enum.at(song.notes, index - 1)

    if left < @release_ms and breath_after?(song, note) do
      nil
    else
      cents =
        error_cents(index, into / note.dur_ms) + onset(note, previous, into) + vibrato(note, into) +
          jitter(t_ms)

      %{midi: note.midi + cents / 100.0, confidence: confidence(note, into)}
    end
  end

  @doc "The scripted error in cents for note `index`, `progress` (0..1) through it."
  @spec error_cents(non_neg_integer(), number()) :: float()
  def error_cents(index, progress) do
    case Enum.at(@script, index, 0) do
      {from, to} -> from + (to - from) * smoothstep(progress)
      cents -> cents * 1.0
    end
  end

  # A new syllable scoops up from below; a slur glides from the previous pitch.
  defp onset(%{slur: true} = note, %{} = previous, into) when into < @scoop_ms do
    (previous.midi - note.midi) * 100.0 * (1.0 - smoothstep(into / @scoop_ms))
  end

  defp onset(_note, _previous, into) when into < @scoop_ms do
    @scoop_cents * (1.0 - smoothstep(into / @scoop_ms))
  end

  defp onset(_note, _previous, _into), do: 0.0

  defp vibrato(note, into) when note.dur_ms > 600 and into > @vibrato_delay_ms do
    ramp = min(1.0, (into - @vibrato_delay_ms) / 300.0)
    ramp * @vibrato_cents * :math.sin(2 * :math.pi() * @vibrato_hz * into / 1000.0)
  end

  defp vibrato(_note, _into), do: 0.0

  defp confidence(%{slur: false}, into) when into < @onset_unsure_ms, do: 0.4
  defp confidence(_note, _into), do: 0.95

  # Small deterministic wobble so the trace isn't ruler-straight.
  defp jitter(t_ms) do
    1.2 * :math.sin(t_ms / 37.0) + 0.8 * :math.sin(t_ms / 13.0)
  end

  defp breath_after?(song, note) do
    case Song.next_note(song, note.start_ms) do
      nil -> true
      next -> next.start_ms - (note.start_ms + note.dur_ms) > 1.0
    end
  end

  defp smoothstep(x) do
    x = x |> max(0.0) |> min(1.0)
    x * x * (3 - 2 * x)
  end
end
