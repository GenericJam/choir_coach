defmodule ChoirCoach.Songs.OComeAllYeFaithful.Piano do
  @moduledoc false
  # O Come, All Ye Faithful's piano accompaniment, for
  # `ChoirCoach.Songs.OComeAllYeFaithful.accompaniment/0` (the rendered
  # backing; never drawn): the score's piano part, read at 400 dpi. Each
  # score bar is written once (`s/1`, the score's bar number, chord symbols
  # in the comment) as its right-hand layers (top down) and left-hand layers
  # (top down); `layers/0` unrolls the repeats into performance order.
  # Layers 0–3 are the right hand, 4–7 the left: the right hand holds up to
  # four notes (s15, s24), the left up to four (s29). A tie is a `~` note
  # continuing the same layer. The refrain ("For You Alone Are Worthy",
  # page 4) prints no piano: `f/1` doubles the choir (soprano, alto in the
  # right hand; tenor, bass in the left), a unison sung by two voices played
  # once.

  @rh 4
  @lh 4

  @doc "Layers of the piano's chords, top voice first; each a full list of bars."
  def layers do
    bars =
      Enum.map(1..5, &s/1) ++
        verse(25..28) ++
        verse(25..28) ++ verse(29..32) ++ Enum.map(1..11, &f/1)

    for i <- 0..(@rh + @lh - 1), do: Enum.map(bars, &Enum.at(&1, i))
  end

  # A verse: s6–s24, then the ending's bars.
  defp verse(ending), do: Enum.map(Enum.concat(6..24, ending), &s/1)

  defp n(name, beats), do: {:n, {name, beats, ""}}
  defp t(name, beats), do: {:n, {name, beats, "~"}}
  defp r(beats) when is_number(beats), do: {:rest, beats}

  # One bar: right- and left-hand layers, padded with whole-bar rests.
  defp bar(beats, rh, lh), do: pad(rh, @rh, beats) ++ pad(lh, @lh, beats)

  defp pad(layers, count, beats),
    do: layers ++ List.duplicate([rest: beats], count - length(layers))

  # s1 (pickup)  G/D
  defp s(1), do: bar(1, [[n("B4", 1)], [n("G4", 1)], [n("D4", 1)]], [[n("D3", 1)], [n("D2", 1)]])

  # s2  C/E  G/D  Am/C  Am7
  defp s(2) do
    bar(
      4,
      [
        [n("C5", 1), n("B4", 1), n("A4", 1), n("G4", 1)],
        [n("G4", 1), n("G4", 1), n("E4", 0.5), n("F#4", 0.5), n("E4", 1)],
        [n("C4", 1), n("D4", 1), n("C4", 0.5), r(0.5), n("C4", 1)]
      ],
      [
        [n("E3", 1), n("D3", 1), n("C3", 1), n("A2", 1)],
        [n("E2", 1), n("D2", 1), n("C2", 1), n("A1", 1)]
      ]
    )
  end

  # s3  D  D7/C  G/B  C
  defp s(3) do
    bar(
      4,
      [
        [n("F#4", 2), n("G4", 0.5), n("G3", 0.5), n("C5", 1)],
        [
          n("D4", 0.5),
          n("A3", 0.5),
          n("D4", 0.5),
          n("C4", 0.5),
          n("D4", 0.5),
          r(0.5),
          n("E4", 1)
        ],
        [r(3), n("C4", 1)]
      ],
      [
        [n("D3", 1), n("C3", 1), n("B2", 1), n("C3", 1)],
        [n("D2", 1), n("C2", 1), n("B1", 1), n("C2", 1)]
      ]
    )
  end

  # s4  G  D7sus/G
  defp s(4) do
    bar(
      4,
      [
        [n("B4", 1), n("D4", 1), n("D4", 2)],
        [n("D4", 1), n("B3", 1), n("C4", 2)],
        [r(2), n("A3", 2)]
      ],
      [
        [n("G3", 1), n("G3", 1), n("G3", 1), n("G3", 1)],
        [n("D3", 1), n("D3", 1), t("D3", 2)],
        [n("G2", 1), r(3)]
      ]
    )
  end

  # s5  G  (voices' pickup on beat 4)
  defp s(5) do
    bar(
      4,
      [[n("D4", 4)], [n("B3", 1), n("B3", 0.5), n("A3", 0.5), n("B3", 2)]],
      [[n("D3", 1), n("D3", 0.5), n("C3", 0.5), n("D3", 2)], [n("G2", 4)]]
    )
  end

  # s6 (repeat start)  G
  defp s(6) do
    bar(
      4,
      [
        [n("D4", 4)],
        [n("B3", 1), n("B3", 0.5), n("A3", 0.5), n("B3", 1), n("A3", 0.5), n("B3", 0.5)]
      ],
      [[n("D3", 1), n("D3", 0.5), n("C3", 0.5), n("D3", 2)], [n("G2", 4)]]
    )
  end

  # s7  C(add2)/G
  defp s(7) do
    bar(
      4,
      [[n("D4", 4)], [n("C4", 1), n("C4", 0.5), n("B3", 0.5), n("C4", 2)]],
      [
        [n("E3", 1), n("E3", 0.5), n("D3", 0.5), n("E3", 1), n("E3", 0.5), n("F#3", 0.5)],
        [n("G2", 4)]
      ]
    )
  end

  # s8  G  (the eighth D4 on beat 2½ is tied into the lower voice's beat-3 D4)
  defp s(8) do
    bar(
      4,
      [
        [
          n("D4", 0.5),
          n("A3", 0.5),
          n("B3", 0.5),
          r(0.5),
          n("F#4", 0.5),
          n("D4", 0.5),
          n("E4", 0.5),
          n("G4", 0.5)
        ],
        [r(1.5), n("D4", 0.5), t("D4", 1), r(1)]
      ],
      [[n("G3", 1), n("G2", 1), n("G3", 1), n("G2", 1)]]
    )
  end

  # s9  D/G  D
  defp s(9) do
    bar(
      4,
      [
        [
          n("F#4", 0.5),
          n("G4", 0.5),
          n("A4", 0.5),
          n("G4", 0.5),
          n("F#4", 0.5),
          n("D4", 0.5),
          n("B3", 0.5),
          n("E4", 0.5)
        ],
        [n("D4", 2), n("A3", 2)]
      ],
      [[n("G3", 1), n("G2", 1), n("D3", 1), n("E3", 1)]]
    )
  end

  # s10  A9/E  D  A
  defp s(10) do
    bar(
      4,
      [
        [
          n("B3", 0.5),
          n("C#4", 0.5),
          n("E4", 0.5),
          n("C#4", 0.5),
          n("D4", 0.5),
          n("A3", 0.5),
          n("C#4", 0.5),
          n("A3", 0.5)
        ]
      ],
      [[r(1), n("A3", 1), n("D3", 1), n("A2", 1)], [n("E3", 2), r(2)]]
    )
  end

  # s11  D  Em7  D/F#  G
  defp s(11) do
    bar(
      4,
      [
        [
          n("D4", 0.5),
          n("A3", 0.5),
          n("D4", 0.5),
          n("G3", 0.5),
          n("D4", 0.5),
          n("A3", 0.5),
          n("D4", 1)
        ],
        [r(3), n("B3", 0.5), n("G3", 0.5)]
      ],
      [
        [n("D3", 1), n("D3", 1), n("D3", 1), n("D3", 1)],
        [n("D2", 1), n("E2", 1), n("F#2", 1), n("G2", 1)]
      ]
    )
  end

  # s12  D/A  A7
  defp s(12) do
    bar(
      4,
      [
        [
          n("A3", 0.5),
          n("D4", 0.5),
          n("C#4", 0.5),
          n("D4", 0.5),
          n("B3", 0.5),
          n("D4", 0.5),
          n("C#4", 1)
        ]
      ],
      [[n("D3", 2), n("G3", 2)], [n("A2", 2), n("A2", 2)]]
    )
  end

  # s13  D  (the middle chord of beat 3 prints C natural)
  defp s(13) do
    bar(
      4,
      [
        [n("A3", 2), n("F#4", 0.5), n("E4", 0.5), n("F#4", 1)],
        [n("F#3", 2), n("D4", 0.5), n("C4", 0.5), n("D4", 1)],
        [r(2), n("A3", 0.5), n("G3", 0.5), n("A3", 1)]
      ],
      [
        [n("D3", 1), n("D3", 1), n("D3", 2)],
        [n("A2", 1), n("D2", 1), n("A2", 2)],
        [n("D2", 1), r(1), n("D2", 2)]
      ]
    )
  end

  # s14  G/D  Am7/D  Gadd2/D
  defp s(14) do
    bar(
      4,
      [
        [n("G4", 2), n("G4", 0.5), n("C4", 0.5), n("G4", 1)],
        [n("D4", 2), n("E4", 0.5), r(0.5), n("D4", 1)],
        [n("B3", 2), r(2)]
      ],
      [
        [n("D3", 1), n("D2", 1), n("A3", 1), n("A3", 1)],
        [r(2), n("D3", 1), n("G3", 1)],
        [r(3), n("D3", 1)]
      ]
    )
  end

  # s15  Am11/D  G(add2)/D
  defp s(15) do
    bar(
      4,
      [
        [n("D5", 2), n("D5", 1), n("D6", 1)],
        [n("A4", 2), n("G4", 1), n("G5", 1)],
        [n("G4", 2), r(2)],
        [n("E4", 2), r(2)]
      ],
      [
        [n("A3", 1), n("D2", 1), n("B3", 2)],
        [n("G3", 1), r(1), n("A3", 2)],
        [n("D3", 1), r(1), n("D3", 2)]
      ]
    )
  end

  # s16  Am/D  D7  Em7  Am/C
  defp s(16) do
    bar(
      4,
      [
        [
          n("C6", 0.5),
          n("C5", 0.5),
          n("D6", 0.5),
          n("D5", 0.5),
          n("B5", 0.5),
          n("B4", 0.5),
          n("C6", 0.5),
          n("C5", 0.5)
        ],
        [
          n("E5", 0.5),
          r(0.5),
          n("F#5", 0.5),
          r(0.5),
          n("D5", 0.5),
          r(0.5),
          n("E5", 0.5),
          r(0.5)
        ]
      ],
      [[n("C4", 2), n("B3", 1), n("C3", 1)], [n("D3", 2), n("E3", 1), r(1)]]
    )
  end

  # s17  D  (left hand: D3 on beat 2 tied into beat 3)
  defp s(17) do
    bar(
      4,
      [
        [n("A5", 2), n("A5", 1), r(1)],
        [n("D5", 2), n("D5", 1), r(1)],
        [n("A4", 2), n("A4", 1), r(1)]
      ],
      [
        [n("A3", 1), r(1), n("D4", 1), r(1)],
        [r(2), n("A3", 1), r(1)],
        [n("D3", 1), n("D3", 1), t("D3", 1), r(1)]
      ]
    )
  end

  # s18  G/B  (left hand in the treble clef)
  defp s(18) do
    bar(
      4,
      [[n("D6", 2), n("D6", 2)], [n("G5", 2), n("G5", 2)]],
      [[n("B4", 1), n("A4", 1), n("B4", 1), n("C5", 1)]]
    )
  end

  # s19  (left hand in the treble clef)
  defp s(19) do
    bar(
      4,
      [[n("D6", 2), n("D6", 2)], [n("G5", 2), n("G5", 2)]],
      [[n("B4", 1), n("A4", 1), n("B4", 2)]]
    )
  end

  # s20  G
  defp s(20) do
    bar(
      4,
      [[n("D6", 2), n("D6", 2)], [n("G5", 2), n("G5", 2)], [n("D5", 2), n("D5", 2)]],
      [[n("G3", 1), n("F#3", 1), n("G3", 1), n("A3", 1)]]
    )
  end

  # s21  D  G
  defp s(21) do
    bar(
      4,
      [
        [n("D6", 2), n("D6", 1), n("D4", 1)],
        [n("G5", 2), n("F#5", 1), n("B3", 1)],
        [n("D5", 2), n("D5", 1), n("G3", 1)]
      ],
      [[n("G3", 1), n("D3", 2), n("G2", 1)], [r(3), n("G1", 1)]]
    )
  end

  # s22  D/A  G/B  C  Am7
  defp s(22) do
    bar(
      4,
      [
        [n("D4", 1), n("D4", 1), n("E4", 1), n("E4", 1)],
        [n("A3", 1), n("G3", 1), n("C4", 1), n("C4", 1)],
        [n("F#3", 1), r(1), n("G3", 1), n("G3", 1)]
      ],
      [
        [n("A2", 1), n("B2", 1), n("C3", 1), n("A2", 1)],
        [n("A1", 1), n("B1", 1), n("C2", 1), n("A1", 1)]
      ]
    )
  end

  # s23  D  D7/C  G/B  C
  defp s(23) do
    bar(
      4,
      [
        [n("D4", 2), n("D4", 1), n("E4", 1)],
        [n("A3", 2), n("G3", 1), n("C4", 1)],
        [n("F#3", 2), r(1), n("G3", 1)]
      ],
      [
        [n("D3", 1), n("C3", 1), n("B2", 1), n("C3", 1)],
        [n("D2", 1), n("C2", 1), n("B1", 1), n("C2", 1)]
      ]
    )
  end

  # s24  G/D  D7sus
  defp s(24) do
    bar(
      4,
      [
        [n("G4", 2), n("G4", 2)],
        [n("D4", 2), n("D4", 2)],
        [n("B3", 2), n("C4", 2)],
        [r(2), n("A3", 2)]
      ],
      [
        [n("G3", 1), n("D3", 1), n("D3", 1), n("D3", 1)],
        [n("D3", 1), n("D2", 1), r(1), n("D2", 1)]
      ]
    )
  end

  # s25 (1.2. ending)  G  C/G  D/F#
  defp s(25) do
    bar(
      4,
      [
        [n("D4", 1), n("D5", 1), n("C5", 1), n("A4", 1)],
        [n("B3", 1), n("G4", 1), n("E4", 1), n("D4", 1)],
        [n("G3", 1), r(3)]
      ],
      [
        [n("G2", 1), n("B3", 1), n("G3", 1), n("F#3", 1)],
        [n("G1", 1), r(1), n("C3", 2)],
        [r(2), n("G2", 2)]
      ]
    )
  end

  # s26  G  C/G  D/F#
  defp s(26) do
    bar(
      4,
      [
        [n("B4", 1), n("D5", 1), n("C5", 1), n("A4", 1)],
        [n("D4", 1), n("G4", 1), n("E4", 1), n("D4", 1)]
      ],
      [
        [n("G3", 1), n("B3", 1), n("G3", 1), n("F#3", 1)],
        [n("D3", 2), n("C3", 2)],
        [n("G2", 2), n("G2", 2)]
      ]
    )
  end

  # s27  G  D7sus/G  (D4 on beat 3 tied into s28)
  defp s(27) do
    bar(
      4,
      [
        [n("B4", 1), n("D4", 1), n("D4", 2)],
        [n("D4", 1), n("B3", 1), n("C4", 2)],
        [r(2), n("A3", 2)]
      ],
      [[n("G3", 1), n("G3", 1), n("G3", 1), n("G3", 1)], [n("D3", 4)], [n("G2", 4)]]
    )
  end

  # s28  G  (repeat sign; the voices' pickup on beat 4 in verses 1 and 2)
  defp s(28) do
    bar(
      4,
      [[t("D4", 4)], [n("B3", 1), n("B3", 0.5), n("A3", 0.5), n("B3", 2)]],
      [[n("D3", 1), n("D3", 0.5), n("C3", 0.5), n("D3", 2)], [n("G2", 4)]]
    )
  end

  # s29 (3. ending)  G  C/G  D/F#  (G1 held under the whole bar)
  defp s(29) do
    bar(
      4,
      [
        [n("D4", 1), n("D5", 1), n("C5", 1), n("A4", 1)],
        [n("B3", 1), n("G4", 1), n("E4", 1), n("D4", 1)],
        [n("G3", 1), r(3)]
      ],
      [
        [r(1), n("B3", 1), n("G3", 1), n("F#3", 1)],
        [n("G2", 2), n("C3", 2)],
        [n("G1", 4)],
        [r(2), n("G2", 2)]
      ]
    )
  end

  # s30  G  C/G  D/F#
  defp s(30), do: s(26)

  # s31  G  D7sus/G  (D4 on beat 3 tied into s32)
  defp s(31), do: s(27)

  # s32  G  (fermata)
  defp s(32), do: bar(4, [[t("D4", 4)], [n("B3", 4)]], [[n("D3", 4)], [n("G2", 4)]])

  # Refrain bars `f/1` (page 4's numbering), the choir doubled.
  # r1 (pickup)  For
  defp f(1), do: bar(1, [[n("G4", 1)], [n("D4", 1)]], [[n("B3", 1)], [n("G3", 1)]])

  # r2  You a-lone are
  defp f(2) do
    bar(
      4,
      [
        [n("G4", 1), n("F#4", 1), n("G4", 1), n("A4", 1)],
        [n("D4", 1), n("D4", 1), n("D4", 1), n("F#4", 1)]
      ],
      [
        [n("B3", 1), n("A3", 1), n("B3", 1), n("C4", 1)],
        [n("G3", 1), n("D3", 1), n("G3", 1), n("D3", 1)]
      ]
    )
  end

  # r3  wor-thy,  (soprano and alto in unison on beat 3)
  defp f(3) do
    bar(
      3,
      [[n("G4", 2), n("D4", 1)], [n("D4", 2), r(1)]],
      [[n("B3", 2), n("B3", 1)], [n("G2", 2), n("G2", 1)]]
    )
  end

  # r4 (pickup)  For
  defp f(4), do: bar(1, [[n("B4", 1)], [n("D4", 1)]], [[n("D4", 1)], [n("G3", 1)]])

  # r5  You a-lone are
  defp f(5) do
    bar(
      4,
      [
        [n("B4", 1), n("A4", 1), n("B4", 1), n("C5", 1)],
        [n("G4", 1), n("F#4", 1), n("G4", 1), n("G4", 1)]
      ],
      [
        [n("D4", 1), n("D4", 1), n("D4", 1), n("E4", 1)],
        [n("G3", 1), n("D3", 1), n("G3", 1), n("C3", 1)]
      ]
    )
  end

  # r6  wor-thy,
  defp f(6) do
    bar(
      3,
      [[n("B4", 2), n("A4", 1)], [n("G4", 2), n("D4", 1)]],
      [[n("D4", 2), n("D4", 1)], [n("G3", 2), n("F#3", 1)]]
    )
  end

  # r7 (pickup)  For
  defp f(7) do
    bar(1, [[n("B4", 1)], [n("G4", 0.5), n("F#4", 0.5)]], [[n("D4", 1)], [n("G3", 1)]])
  end

  # r8  You a-lone are
  defp f(8) do
    bar(
      4,
      [
        [n("C5", 1), n("B4", 1), n("A4", 1), n("G4", 1)],
        [n("E4", 0.5), n("F#4", 0.5), n("G4", 1), n("D4", 1), n("C#4", 1)]
      ],
      [
        [n("C4", 1), n("D4", 1), n("A3", 1), n("A3", 1)],
        [n("A3", 1), n("G3", 1), n("F#3", 1), n("E3", 1)]
      ]
    )
  end

  # r9  wor-thy,
  defp f(9) do
    bar(
      4,
      [
        [n("F#4", 2), n("G4", 1), n("C5", 1)],
        [n("D4", 2), n("D4", 1), n("E4", 1)]
      ],
      [
        [n("A3", 2), n("G3", 2)],
        [n("D3", 1), n("C3", 1), n("B2", 1), n("C3", 1)]
      ]
    )
  end

  # r10  Christ __ the  (bass D3 tied)
  defp f(10) do
    bar(
      4,
      [
        [n("B4", 2), n("A4", 1.5), n("G4", 0.5)],
        [n("G4", 2), n("F#4", 1.5), n("D4", 0.5)]
      ],
      [
        [n("D4", 2), n("C4", 1.5), n("B3", 0.5)],
        [n("D3", 2), t("D3", 1.5), n("G2", 0.5)]
      ]
    )
  end

  # r11  Lord!
  defp f(11), do: bar(3, [[n("G4", 3)], [n("D4", 3)]], [[n("B3", 3)], [n("G2", 3)]])
end
