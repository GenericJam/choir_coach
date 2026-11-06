defmodule ChoirCoach.Pitch do
  @moduledoc """
  Pitch arithmetic: MIDI note numbers, frequencies, cents and note names.

  MIDI 69 is A4 = 440 Hz; middle C (C4) is 60. Fractional MIDI values are
  allowed everywhere, so a sung pitch can be placed exactly between lanes.
  """

  @names ~w(C C♯ D D♯ E F F♯ G G♯ A A♯ B)
  @letters %{"C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "B" => 11}
  @letter_steps %{"C" => 0, "D" => 1, "E" => 2, "F" => 3, "G" => 4, "A" => 5, "B" => 6}
  # Letter steps (C = 0) in the order sharps, then flats, join a key signature.
  @sharp_order [3, 0, 4, 1, 5, 2, 6]
  @flat_order Enum.reverse(@sharp_order)
  @major_keys ~w(C♭ G♭ D♭ A♭ E♭ B♭ F C G D A E B F♯ C♯)

  @doc "Frequency in Hz for a (possibly fractional) MIDI note."
  @spec hz(number()) :: float()
  def hz(midi), do: 440.0 * :math.pow(2.0, (midi - 69) / 12.0)

  @doc "Fractional MIDI note for a frequency in Hz."
  @spec midi(number()) :: float()
  def midi(hz) when hz > 0, do: 69.0 + 12.0 * :math.log2(hz / 440.0)

  @doc "Signed distance in cents from `target_midi` to `sung_midi`."
  @spec cents(number(), number()) :: float()
  def cents(sung_midi, target_midi), do: (sung_midi - target_midi) * 100.0

  @doc """
  Parse a note name such as `"G3"`, `"F#4"` or `"Bb2"` into a MIDI number.
  """
  @spec parse(String.t()) :: integer()
  def parse(name) do
    {letter, rest} = String.split_at(name, 1)
    {alter, octave} = parse_accidental(rest)
    (String.to_integer(octave) + 1) * 12 + Map.fetch!(@letters, letter) + alter
  end

  defp parse_accidental("#" <> octave), do: {1, octave}
  defp parse_accidental("b" <> octave), do: {-1, octave}
  defp parse_accidental(octave), do: {0, octave}

  @doc """
  A written note: MIDI pitch, staff step (see `staff_step/1`) of its letter
  and its alteration (-1 flat, 0 natural, 1 sharp). `"Bb2"` sits on the B
  line, where `staff_step(46)` would put the natural below (A).
  """
  @spec spell(String.t()) :: %{midi: integer(), step: integer(), alter: -1 | 0 | 1}
  def spell(name) do
    {letter, rest} = String.split_at(name, 1)
    {alter, octave} = parse_accidental(rest)
    octave = String.to_integer(octave)

    %{
      midi: (octave + 1) * 12 + Map.fetch!(@letters, letter) + alter,
      step: (octave + 1) * 7 + Map.fetch!(@letter_steps, letter),
      alter: alter
    }
  end

  @doc "Display name with octave, sharps spelled out, e.g. 60 → \"C4\"."
  @spec name(integer()) :: String.t()
  def name(midi) when is_integer(midi) do
    Enum.at(@names, Integer.mod(midi, 12)) <> Integer.to_string(div(midi, 12) - 1)
  end

  @doc "Display form of a written name: `\"Bb2\"` → `\"B♭2\"`, `\"F#3\"` → `\"F♯3\"`."
  @spec display(String.t()) :: String.t()
  def display(name), do: name |> String.replace("#", "♯") |> String.replace("b", "♭")

  @doc """
  Diatonic staff step of a MIDI note, counted from C-1 (step 0), with
  sharps placed on the natural below. Each step is half a staff space.
  """
  @spec staff_step(integer()) :: integer()
  def staff_step(midi) do
    octave = div(midi, 12)
    pc = Integer.mod(midi, 12)
    octave * 7 + Enum.at([0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6], pc)
  end

  @doc """
  The alteration a key signature gives a staff step. Keys count fifths:
  2 is two sharps (D major), -2 two flats (B♭ major).
  """
  @spec key_alter(integer(), integer()) :: -1 | 0 | 1
  def key_alter(fifths, step) do
    letter = Integer.mod(step, 7)

    cond do
      fifths > 0 and letter in Enum.take(@sharp_order, fifths) -> 1
      fifths < 0 and letter in Enum.take(@flat_order, -fifths) -> -1
      true -> 0
    end
  end

  @doc "Letter steps (C = 0) of a key signature's accidentals, in the order written."
  @spec key_letters(integer()) :: [0..6]
  def key_letters(fifths) when fifths >= 0, do: Enum.take(@sharp_order, fifths)
  def key_letters(fifths), do: Enum.take(@flat_order, -fifths)

  @doc "Name of the major key with `fifths` sharps (positive) or flats (negative)."
  @spec major_key_name(integer()) :: String.t()
  def major_key_name(fifths), do: Enum.at(@major_keys, fifths + 7) <> " major"
end
