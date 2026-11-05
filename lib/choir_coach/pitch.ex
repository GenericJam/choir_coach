defmodule ChoirCoach.Pitch do
  @moduledoc """
  Pitch arithmetic: MIDI note numbers, frequencies, cents and note names.

  MIDI 69 is A4 = 440 Hz; middle C (C4) is 60. Fractional MIDI values are
  allowed everywhere, so a sung pitch can be placed exactly between lanes.
  """

  @names ~w(C C♯ D D♯ E F F♯ G G♯ A A♯ B)
  @letters %{"C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "B" => 11}

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

  @doc "Display name with octave, sharps spelled out, e.g. 60 → \"C4\"."
  @spec name(integer()) :: String.t()
  def name(midi) when is_integer(midi) do
    Enum.at(@names, Integer.mod(midi, 12)) <> Integer.to_string(div(midi, 12) - 1)
  end

  @doc """
  Diatonic staff step of a MIDI note in C major, counted from C-1 (step 0),
  with sharps placed on the natural below. Each step is half a staff space.
  """
  @spec staff_step(integer()) :: integer()
  def staff_step(midi) do
    octave = div(midi, 12)
    pc = Integer.mod(midi, 12)
    octave * 7 + Enum.at([0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6], pc)
  end

  @doc "True when the pitch class needs an accidental in C major."
  @spec accidental?(integer()) :: boolean()
  def accidental?(midi), do: Integer.mod(midi, 12) in [1, 3, 6, 8, 10]
end
