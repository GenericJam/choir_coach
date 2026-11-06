defmodule ChoirCoach.Songs.GloriousNight do
  @moduledoc """
  "What a Glorious Night" (with "Angels We Have Heard on High"), arr. Russell
  Mauldin, bass part and melody, bars 1–113.

  Transcribed from the Drive score, bar by bar, and checked against the Bass
  rehearsal track with the pitch detector: in unison passages the detector
  agrees with every written note; in four-part passages it hears the same
  pitches where it is confident (the rehearsal channel carries the other
  voices too).

  Timing is the rehearsal track's: bar 1 starts 358 ms in, ♩ = 105 steady
  through bar 111, then a ritardando over bar 112 and a fermata on the last
  note (both measured from the track). Bars 1–12 are the instrumental intro.

  The melody is the tune wherever a voice sings it, in the women's register:
  the alto line where the score marks it "mel." (the Gloria refrains), the
  soprano elsewhere, the men's line an octave up where they sing it alone.
  Checked against the Soprano and Alto rehearsal tracks with the detector;
  the notes no recording confirms were re-read at 400 dpi and match the score.
  """

  alias ChoirCoach.Song

  @doc "The parts, in the order the practice screen offers them."
  def parts, do: [:bass, :melody]

  @doc """
  Each part's recordings: where bar 1 falls on each (ms), and which channel
  holds the voices. The part rehearsal tracks share one timeline.
  """
  def tracks(part) do
    Map.merge(
      %{
        split: %{
          file: "glorious_night/split.mp3",
          bar1_ms: 409.0,
          voice: :right,
          label: "Split track"
        },
        demo: %{file: "glorious_night/demo.mp3", bar1_ms: 18_449.0, voice: :mixed, label: "Demo"}
      },
      part_tracks(part)
    )
  end

  defp part_tracks(:bass) do
    %{
      piano: %{
        file: "glorious_night/piano_bass.mp3",
        bar1_ms: 358.0,
        voice: :left,
        label: "Piano"
      },
      rehearsal: %{
        file: "glorious_night/bass.mp3",
        bar1_ms: 358.0,
        voice: :left,
        label: "Bass rehearsal"
      }
    }
  end

  defp part_tracks(:melody) do
    %{
      rehearsal: %{
        file: "glorious_night/soprano.mp3",
        bar1_ms: 358.0,
        voice: :left,
        label: "Soprano rehearsal"
      }
    }
  end

  # Every part shares the bar timeline (and so every track's offsets).
  defp timing do
    [
      title: "What a Glorious Night",
      key: 0,
      tempo_bpm: 105,
      beats_per_bar: 4,
      first_bar: 1,
      start_ms: 358.0,
      bar_ms: %{112 => 3_280.0, 113 => 5_200.0}
    ]
  end

  @spec bass() :: Song.t()
  def bass, do: Song.build(timing() ++ [part: :bass, clef: :bass, bars: bass_bars()])

  @spec melody() :: Song.t()
  def melody, do: Song.build(timing() ++ [part: :melody, clef: :treble, bars: melody_bars()])

  defp bass_bars do
    [
      # 1  (instrumental intro)
      [rest: 4],
      # 2  (instrumental intro)
      [rest: 4],
      # 3  (instrumental intro)
      [rest: 4],
      # 4  (instrumental intro)
      [rest: 4],
      # 5  (instrumental intro)
      [rest: 4],
      # 6  (instrumental intro)
      [rest: 4],
      # 7  (instrumental intro)
      [rest: 4],
      # 8  (instrumental intro)
      [rest: 4],
      # 9  (instrumental intro)
      [rest: 4],
      # 10  (instrumental intro)
      [rest: 4],
      # 11  (instrumental intro)
      [rest: 4],
      # 12  (instrumental intro)
      [rest: 4],
      # 13  Glo-
      [
        n: {"G3", 2, "Glo-"},
        n: {"F3", 0.5, "~Glo-"},
        n: {"E3", 0.5, "~Glo-"},
        n: {"F3", 0.5, "~Glo-"},
        n: {"G3", 0.5, "~Glo-"}
      ],
      # 14  (Glo-)
      [
        n: {"F3", 2, "~Glo-"},
        n: {"G3", 0.5, "~Glo-"},
        n: {"F3", 0.5, "~Glo-"},
        n: {"E3", 0.5, "~Glo-"},
        n: {"D3", 0.5, "~Glo-"}
      ],
      # 15  (Glo-)
      [
        n: {"E3", 2, "~Glo-"},
        n: {"F3", 0.5, "~Glo-"},
        n: {"E3", 0.5, "~Glo-"},
        n: {"D3", 0.5, "~Glo-"},
        n: {"C3", 0.5, "~Glo-"}
      ],
      # 16  (Glo-) ri-a
      [n: {"D3", 1.5, "~Glo-"}, n: {"G3", 0.5, "ri-"}, n: {"G3", 1, "a"}, rest: 1],
      # 17  in excelsis
      [n: {"G3", 1, "in"}, n: {"A3", 1, "ex-"}, n: {"G3", 1, "cel-"}, n: {"A3", 1, "sis"}],
      # 18  De-
      [n: {"G3", 2, "De-"}, n: {"G2", 2, "~De-"}],
      # 19  o!
      [n: {"C3", 4, "o!"}],
      # 20  The shepherds came to
      [
        rest: 0.5,
        n: {"G3", 0.5, "The"},
        n: {"A3", 0.5, "shep-"},
        n: {"G3", 0.5, "herds"},
        n: {"G3", 1, "came"},
        n: {"C4", 1, "to"}
      ],
      # 21  see the Baby,
      [
        rest: 1,
        n: {"D3", 0.5, "see"},
        n: {"E3", 0.5, "the"},
        n: {"D3", 0.5, "Ba-"},
        n: {"C3", 0.5, "~Ba-"},
        n: {"C3", 1, "by,"}
      ],
      # 22  stood by His mother's side
      [
        rest: 0.5,
        n: {"G3", 0.5, "stood"},
        n: {"A3", 0.5, "by"},
        n: {"G3", 0.5, "His"},
        n: {"G3", 0.75, "moth-"},
        n: {"E3", 0.75, "er's"},
        n: {"E3", 0.5, "side"}
      ],
      # 23  (side)
      [n: {"E3", 2, "~side"}, rest: 2],
      # 24  Here laid the Savior
      [
        rest: 0.5,
        n: {"G3", 0.5, "Here"},
        n: {"A3", 0.5, "laid"},
        n: {"G3", 0.5, "the"},
        n: {"G3", 1, "Sav-"},
        n: {"C4", 1, "ior"}
      ],
      # 25  inside a manger.
      [
        rest: 0.5,
        n: {"D3", 0.5, "in-"},
        n: {"D3", 0.5, "side"},
        n: {"E3", 0.5, "a"},
        n: {"D3", 0.5, "man-"},
        n: {"C3", 0.5, "~man-"},
        n: {"C3", 0.5, "ger."},
        rest: 0.5
      ],
      # 26  Oh, what a glorious
      [
        n: {"E3", 0.75, "Oh,"},
        n: {"D3", 0.75, "what"},
        n: {"C3", 0.5, "a"},
        n: {"E3", 0.75, "glo-"},
        n: {"D3", 0.75, "ri-"},
        n: {"C3", 0.5, "ous"}
      ],
      # 27  night.
      [n: {"C3", 2, "night."}, rest: 2],
      # 28  Oh, what a glorious
      [
        n: {"E3", 0.75, "Oh,"},
        n: {"D3", 0.75, "what"},
        n: {"C3", 0.5, "a"},
        n: {"E3", 0.75, "glo-"},
        n: {"D3", 0.75, "ri-"},
        n: {"C3", 0.5, "ous"}
      ],
      # 29  night.
      [n: {"C3", 4, "night."}],
      # 30  I hear the
      [rest: 2.5, n: {"E3", 0.5, "I"}, n: {"D3", 0.5, "hear"}, n: {"C3", 0.5, "the"}],
      # 31  angels singing,
      [n: {"C3", 1, "an-"}, n: {"C3", 1, "gels"}, n: {"C3", 1, "sing-"}, n: {"C3", 1, "ing,"}],
      # 32  "Hallelujah! Let the
      [
        rest: 1,
        n: {"D3", 0.5, "Hal-"},
        n: {"D3", 0.5, "le-"},
        n: {"D3", 0.5, "lu-"},
        n: {"E3", 0.5, "jah!"},
        n: {"D3", 0.5, "Let"},
        n: {"C3", 0.5, "the"}
      ],
      # 33  earth receive her
      [
        n: {"F3", 1, "earth"},
        n: {"F3", 1, "re-"},
        n: {"E3", 1, "ceive"},
        n: {"E3", 0.5, "her"},
        n: {"D3", 0.5, "~her"}
      ],
      # 34  King!" I know that
      [
        n: {"D3", 2, "King!\""},
        rest: 0.5,
        n: {"E3", 0.5, "I"},
        n: {"D3", 0.5, "know"},
        n: {"C3", 0.5, "that"}
      ],
      # 35  Love has come,
      [n: {"C3", 1, "Love"}, n: {"C3", 1, "has"}, n: {"C3", 2, "come,"}],
      # 36  sing it out,
      [
        rest: 1,
        n: {"D3", 0.5, "sing"},
        n: {"D3", 0.5, "it"},
        n: {"D3", 0.5, "out,"},
        n: {"E3", 0.5, "~out,"},
        rest: 1
      ],
      # 37  Je-sus Christ is
      [
        n: {"F3", 1, "Je-"},
        n: {"F3", 1, "sus"},
        n: {"E3", 1, "Christ"},
        n: {"E3", 0.5, "is"},
        n: {"D3", 0.5, "~is"}
      ],
      # 38  born!
      [n: {"D3", 3, "born!"}, rest: 1],
      # 39  Je-sus Christ is
      # ? a straight line joins the last D3 to bar 40's D3 (voice-leading line,
      #   not a curved tie); "born!" treated as re-sung
      [
        n: {"F3", 1, "Je-"},
        n: {"F3", 1, "sus"},
        n: {"G3", 1, "Christ"},
        n: {"E3", 0.5, "is"},
        n: {"D3", 0.5, "~is"}
      ],
      # 40  born!
      [n: {"D3", 3, "born!"}, rest: 1],
      # 41  Glo-
      [
        n: {"G3", 2, "Glo-"},
        n: {"F3", 0.5, "~Glo-"},
        n: {"E3", 0.5, "~Glo-"},
        n: {"F3", 0.5, "~Glo-"},
        n: {"G3", 0.5, "~Glo-"}
      ],
      # 42  (Glo-)
      [
        n: {"F3", 2, "~Glo-"},
        n: {"G3", 0.5, "~Glo-"},
        n: {"F3", 0.5, "~Glo-"},
        n: {"E3", 0.5, "~Glo-"},
        n: {"D3", 0.5, "~Glo-"}
      ],
      # 43  (Glo-)
      [
        n: {"E3", 2, "~Glo-"},
        n: {"F3", 0.5, "~Glo-"},
        n: {"E3", 0.5, "~Glo-"},
        n: {"D3", 0.5, "~Glo-"},
        n: {"C3", 0.5, "~Glo-"}
      ],
      # 44  (Glo-) ri-a
      [n: {"D3", 1.5, "~Glo-"}, n: {"G3", 0.5, "ri-"}, n: {"G3", 1, "a"}, rest: 1],
      # 45  in ex-cel-sis
      [n: {"G3", 1, "in"}, n: {"A3", 1, "ex-"}, n: {"G3", 1, "cel-"}, n: {"A3", 1, "sis"}],
      # 46  De-
      [n: {"G3", 2, "De-"}, n: {"G2", 2, "~De-"}],
      # 47  o!
      [n: {"C3", 4, "o!"}],
      # 48  The shep-herds won-dered,
      [
        rest: 0.5,
        n: {"G3", 0.5, "The"},
        n: {"A3", 0.5, "shep-"},
        n: {"G3", 0.5, "herds"},
        n: {"G3", 1, "won-"},
        n: {"C4", 1, "dered,"}
      ],
      # 49  they could-n't hide it,
      [
        rest: 0.5,
        n: {"D3", 0.5, "they"},
        n: {"D3", 0.5, "could-"},
        n: {"E3", 0.5, "n't"},
        n: {"D3", 0.5, "hide"},
        n: {"C3", 0.5, "~hide"},
        n: {"C3", 1, "it,"}
      ],
      # 50  told ev-'ry-one in sight.
      [
        rest: 0.5,
        n: {"G3", 0.5, "told"},
        n: {"A3", 0.5, "ev-"},
        n: {"G3", 0.5, "'ry-"},
        n: {"G3", 0.75, "one"},
        n: {"E3", 0.75, "in"},
        n: {"E3", 0.5, "sight."}
      ],
      # 51  (sight.)
      [n: {"E3", 2, "~sight."}, rest: 2],
      # 52  All were a-mazed when
      [
        rest: 0.5,
        n: {"G3", 0.5, "All"},
        n: {"A3", 0.5, "were"},
        n: {"G3", 0.5, "a-"},
        n: {"G3", 1, "mazed"},
        n: {"C4", 1, "when"}
      ],
      # 53  they heard how God came
      [
        rest: 0.5,
        n: {"D3", 0.5, "they"},
        n: {"D3", 0.5, "heard"},
        n: {"E3", 0.5, "how"},
        n: {"D3", 0.5, "God"},
        n: {"C3", 0.5, "~God"},
        n: {"C3", 0.5, "came"},
        rest: 0.5
      ],
      # 54  down on the glo-ri-ous
      [
        n: {"E3", 0.75, "down"},
        n: {"D3", 0.75, "on"},
        n: {"C3", 0.5, "the"},
        n: {"E3", 0.75, "glo-"},
        n: {"D3", 0.75, "ri-"},
        n: {"C3", 0.5, "ous"}
      ],
      # 55  night. God came
      [n: {"C3", 2, "night."}, rest: 0.5, n: {"E3", 0.75, "God"}, n: {"G3", 0.75, "came"}],
      # 56  down on this glo-ri-ous
      [
        n: {"A3", 0.75, "down"},
        n: {"A3", 0.75, "on"},
        n: {"G3", 0.5, "this"},
        n: {"F3", 0.75, "glo-"},
        n: {"F3", 0.75, "ri-"},
        n: {"F3", 0.5, "ous"}
      ],
      # 57  night. I hear the  (mel. in lower voice)
      [
        n: {"G3", 2, "night."},
        rest: 0.5,
        n: {"E3", 0.5, "I"},
        n: {"D3", 0.5, "hear"},
        n: {"C3", 0.5, "the"}
      ],
      # 58  an-gels sing-ing,
      [n: {"C3", 1, "an-"}, n: {"C3", 1, "gels"}, n: {"C3", 1, "sing-"}, n: {"C3", 1, "ing,"}],
      # 59  "Hal-le-lu-jah! Let the
      [
        rest: 1,
        n: {"D3", 0.5, "\"Hal-"},
        n: {"D3", 0.5, "le-"},
        n: {"D3", 0.5, "lu-"},
        n: {"E3", 0.5, "jah!"},
        n: {"D3", 0.5, "Let"},
        n: {"C3", 0.5, "the"}
      ],
      # 60  earth re-ceive her
      [
        n: {"F3", 1, "earth"},
        n: {"F3", 1, "re-"},
        n: {"E3", 1, "ceive"},
        n: {"E3", 0.5, "her"},
        n: {"D3", 0.5, "~her"}
      ],
      # 61  King!" I know that
      [
        n: {"D3", 2, "King!\""},
        rest: 0.5,
        n: {"E3", 0.5, "I"},
        n: {"D3", 0.5, "know"},
        n: {"C3", 0.5, "that"}
      ],
      # 62  Love has come,
      [n: {"C3", 1, "Love"}, n: {"C3", 1, "has"}, n: {"C3", 2, "come,"}],
      # 63  sing it out,
      [
        rest: 1,
        n: {"D3", 0.5, "sing"},
        n: {"D3", 0.5, "it"},
        n: {"D3", 0.5, "out,"},
        n: {"E3", 0.5, "~out,"},
        rest: 1
      ],
      # 64  Je-sus Christ is
      [
        n: {"F3", 1, "Je-"},
        n: {"F3", 1, "sus"},
        n: {"E3", 1, "Christ"},
        n: {"E3", 0.5, "is"},
        n: {"D3", 0.5, "~is"}
      ],
      # 65  born!
      [n: {"D3", 3, "born!"}, rest: 1],
      # 66  Je-sus Christ is
      [
        n: {"F3", 1, "Je-"},
        n: {"F3", 1, "sus"},
        n: {"G3", 1, "Christ"},
        n: {"E3", 0.5, "is"},
        n: {"D3", 0.5, "~is"}
      ],
      # 67  born!
      [n: {"D3", 4, "born!"}],
      # 68  (piano interlude)
      [rest: 4],
      # 69  (piano interlude)
      [rest: 4],
      # 70  (WOMEN: Glo-ri-ous,)
      [rest: 4],
      # 71  (WOMEN: glo-ri-ous,)
      [rest: 4],
      # 72  (WOMEN: what a glo-ri-ous)
      [rest: 4],
      # 73  (WOMEN: night.)
      [rest: 4],
      # 74  Glo-ri-ous,  (men enter, mf)
      [
        n: {"C3", 0.75, "Glo-"},
        n: {"D3", 0.75, "~Glo-"},
        n: {"E3", 0.5, "ri-"},
        n: {"G3", 1, "ous,"},
        rest: 1
      ],
      # 75  glo-ri-ous,
      [
        n: {"C3", 0.75, "glo-"},
        n: {"D3", 0.75, "~glo-"},
        n: {"E3", 0.5, "ri-"},
        n: {"G3", 1, "ous,"},
        n: {"E3", 1, "~ous,"}
      ],
      # 76  what a glo-ri-ous
      [
        rest: 1,
        n: {"G3", 0.5, "what"},
        n: {"G3", 0.5, "a"},
        n: {"A3", 0.75, "glo-"},
        n: {"E3", 0.75, "ri-"},
        n: {"E3", 0.5, "ous"}
      ],
      # 77  night. I hear the  (f, mel. in lower voice)
      [
        n: {"E3", 0.5, "night."},
        n: {"D3", 1.5, "~night."},
        rest: 0.5,
        n: {"E3", 0.5, "I"},
        n: {"D3", 0.5, "hear"},
        n: {"C3", 0.5, "the"}
      ],
      # 78  an-gels sing-ing,
      [n: {"C3", 1, "an-"}, n: {"C3", 1, "gels"}, n: {"C3", 1, "sing-"}, n: {"C3", 1, "ing,"}],
      # 79  "Hal-le-lu-jah! Let the
      [
        rest: 1,
        n: {"D3", 0.5, "\"Hal-"},
        n: {"D3", 0.5, "le-"},
        n: {"D3", 0.5, "lu-"},
        n: {"E3", 0.5, "jah!"},
        n: {"D3", 0.5, "Let"},
        n: {"C3", 0.5, "the"}
      ],
      # 80  earth re-ceive her
      [
        n: {"F3", 1, "earth"},
        n: {"F3", 1, "re-"},
        n: {"E3", 1, "ceive"},
        n: {"E3", 0.5, "her"},
        n: {"D3", 0.5, "~her"}
      ],
      # 81  King!" I know that
      [
        n: {"D3", 2, "King!\""},
        rest: 0.5,
        n: {"E3", 0.5, "I"},
        n: {"D3", 0.5, "know"},
        n: {"C3", 0.5, "that"}
      ],
      # 82  Love has come,
      [n: {"C3", 1, "Love"}, n: {"C3", 1, "has"}, n: {"C3", 2, "come,"}],
      # 83  sing it out,
      [
        rest: 1,
        n: {"D3", 0.5, "sing"},
        n: {"D3", 0.5, "it"},
        n: {"D3", 0.5, "out,"},
        n: {"E3", 0.5, "~out,"},
        rest: 1
      ],
      # 84  Je-sus Christ is
      [
        n: {"F3", 1, "Je-"},
        n: {"F3", 1, "sus"},
        n: {"G3", 1, "Christ"},
        n: {"E3", 0.5, "is"},
        n: {"D3", 0.5, "~is"}
      ],
      # 85  born! I hear the
      [
        n: {"D3", 2, "born!"},
        rest: 0.5,
        n: {"E3", 0.5, "I"},
        n: {"D3", 0.5, "hear"},
        n: {"C3", 0.5, "the"}
      ],
      # 86  an-gels sing-ing,
      [n: {"C3", 1, "an-"}, n: {"C3", 1, "gels"}, n: {"C3", 1, "sing-"}, n: {"C3", 1, "ing,"}],
      # 87  "Hal-le-lu-jah! Let the
      [
        rest: 1,
        n: {"D3", 0.5, "\"Hal-"},
        n: {"D3", 0.5, "le-"},
        n: {"D3", 0.5, "lu-"},
        n: {"E3", 0.5, "jah!"},
        n: {"D3", 0.5, "Let"},
        n: {"C3", 0.5, "the"}
      ],
      # 88  earth re-ceive her
      [
        n: {"F3", 1, "earth"},
        n: {"F3", 1, "re-"},
        n: {"E3", 1, "ceive"},
        n: {"E3", 0.5, "her"},
        n: {"D3", 0.5, "~her"}
      ],
      # 89  King!" I know that
      [
        n: {"D3", 2, "King!\""},
        rest: 0.5,
        n: {"E3", 0.5, "I"},
        n: {"D3", 0.5, "know"},
        n: {"C3", 0.5, "that"}
      ],
      # 90  Love has come,
      [n: {"C3", 1, "Love"}, n: {"C3", 1, "has"}, n: {"C3", 2, "come,"}],
      # 91  sing it out,
      [
        rest: 1,
        n: {"D3", 0.5, "sing"},
        n: {"D3", 0.5, "it"},
        n: {"D3", 0.5, "out,"},
        n: {"E3", 0.5, "~out,"},
        rest: 1
      ],
      # 92  Je-sus Christ is
      [
        n: {"F3", 1, "Je-"},
        n: {"F3", 1, "sus"},
        n: {"E3", 1, "Christ"},
        n: {"E3", 0.5, "is"},
        n: {"D3", 0.5, "~is"}
      ],
      # 93  born!
      [n: {"D3", 3, "born!"}, rest: 1],
      # 94  Je-sus Christ is
      [
        n: {"F3", 1, "Je-"},
        n: {"F3", 1, "sus"},
        n: {"G3", 1, "Christ"},
        n: {"E3", 0.5, "is"},
        n: {"D3", 0.5, "~is"}
      ],
      # 95  born!
      [n: {"D3", 3, "born!"}, rest: 1],
      # 96  Glo-
      [
        n: {"G3", 2, "Glo-"},
        n: {"F3", 0.5, "~Glo-"},
        n: {"E3", 0.5, "~Glo-"},
        n: {"F3", 0.5, "~Glo-"},
        n: {"G3", 0.5, "~Glo-"}
      ],
      # 97  (Glo-)
      [
        n: {"F3", 2, "~Glo-"},
        n: {"G3", 0.5, "~Glo-"},
        n: {"F3", 0.5, "~Glo-"},
        n: {"E3", 0.5, "~Glo-"},
        n: {"D3", 0.5, "~Glo-"}
      ],
      # 98  (Glo-)
      [
        n: {"E3", 2, "~Glo-"},
        n: {"F3", 0.5, "~Glo-"},
        n: {"E3", 0.5, "~Glo-"},
        n: {"D3", 0.5, "~Glo-"},
        n: {"C3", 0.5, "~Glo-"}
      ],
      # 99  ri-a
      [n: {"D3", 1.5, "~Glo-"}, n: {"G3", 0.5, "ri-"}, n: {"G3", 1, "a"}, rest: 1],
      # 100  in ex-cel-sis
      [n: {"G3", 1, "in"}, n: {"A3", 1, "ex-"}, n: {"G3", 1, "cel-"}, n: {"A3", 1, "sis"}],
      # 101  De-
      [n: {"G3", 2, "De-"}, n: {"G2", 2, "~De-"}],
      # 102  o!
      [n: {"C3", 4, "o!"}],
      # 103  (rest)
      [rest: 4],
      # 104  All is calm now,
      [
        rest: 1,
        n: {"A3", 0.5, "All"},
        n: {"G3", 0.5, "is"},
        n: {"G3", 1, "calm"},
        n: {"C4", 1, "now,"}
      ],
      # 105  all is qui-et. A
      [
        rest: 1,
        n: {"D3", 0.5, "all"},
        n: {"E3", 0.5, "is"},
        n: {"D3", 0.5, "qui-"},
        n: {"C3", 0.5, "et."},
        rest: 0.5,
        n: {"C3", 0.5, "A"}
      ],
      # 106  star shin-ing in the sky.
      [
        n: {"A3", 0.75, "star"},
        n: {"G3", 0.75, "shin-"},
        n: {"G3", 0.5, "ing"},
        n: {"G3", 0.75, "in"},
        n: {"E3", 0.75, "the"},
        n: {"E3", 0.5, "sky."}
      ],
      # 107  (sky.)
      [n: {"E3", 2, "~sky."}, rest: 2],
      # 108  Be-low in Beth-le-hem,
      [
        rest: 0.5,
        n: {"G3", 0.5, "Be-"},
        n: {"A3", 0.5, "low"},
        n: {"G3", 0.5, "in"},
        n: {"G3", 0.5, "Beth-"},
        n: {"E3", 0.5, "le-"},
        n: {"E3", 1, "hem,"}
      ],
      # 109  the King is sleep-ing.
      [
        rest: 0.5,
        n: {"D3", 0.5, "the"},
        n: {"D3", 0.5, "King"},
        n: {"E3", 0.5, "is"},
        n: {"D3", 0.5, "sleep-"},
        n: {"C3", 0.5, "~sleep-"},
        n: {"C3", 0.5, "ing."},
        rest: 0.5
      ],
      # 110  Oh, what a glo-ri-ous
      [
        n: {"E3", 0.75, "Oh,"},
        n: {"D3", 0.75, "what"},
        n: {"C3", 0.5, "a"},
        n: {"E3", 0.75, "glo-"},
        n: {"D3", 0.75, "ri-"},
        n: {"C3", 0.5, "ous"}
      ],
      # 111  night.
      [n: {"C3", 2, "night."}, rest: 2],
      # 112  Oh, what a glo-ri-ous   (rit.)
      [
        n: {"E3", 0.75, "Oh,"},
        n: {"D3", 0.75, "what"},
        n: {"C3", 0.5, "a"},
        n: {"E3", 0.75, "glo-"},
        n: {"D3", 0.75, "ri-"},
        n: {"C3", 0.5, "ous"}
      ],
      # 113  night.   (fermata, final bar)
      [n: {"C3", 4, "night."}]
    ]
  end

  defp melody_bars do
    [
      # 1  (instrumental intro)
      [rest: 4],
      # 2  (instrumental intro)
      [rest: 4],
      # 3  (instrumental intro)
      [rest: 4],
      # 4  (instrumental intro)
      [rest: 4],
      # 5  (instrumental intro)
      [rest: 4],
      # 6  (instrumental intro)
      [rest: 4],
      # 7  (instrumental intro)
      [rest: 4],
      # 8  (instrumental intro)
      [rest: 4],
      # 9  (instrumental intro)
      [rest: 4],
      # 10  (instrumental intro)
      [rest: 4],
      # 11  (instrumental intro)
      [rest: 4],
      # 12  (instrumental intro)
      [rest: 4],
      # 13  alto (marked mel): Glo-   ? small noteheads; eighths read from standard tune; ok: score shows
      #   G4 in mel-marked lower treble voice, recording unclear at onset
      [
        n: {"G4", 2, "Glo-"},
        n: {"A4", 0.5, "~Glo-"},
        n: {"G4", 0.5, "~Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"E4", 0.5, "~Glo-"}
      ],
      # 14  alto (mel): (Glo-)
      [
        n: {"F4", 2, "~Glo-"},
        n: {"G4", 0.5, "~Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"E4", 0.5, "~Glo-"},
        n: {"D4", 0.5, "~Glo-"}
      ],
      # 15  alto (mel): (Glo-)
      [
        n: {"E4", 2, "~Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"E4", 0.5, "~Glo-"},
        n: {"D4", 0.5, "~Glo-"},
        n: {"C4", 0.5, "~Glo-"}
      ],
      # 16  alto (mel): (Glo-) ri-a
      [n: {"D4", 1.5, "~Glo-"}, n: {"G4", 0.5, "ri-"}, n: {"G4", 1, "a"}, rest: 1],
      # 17  alto (mel): in ex-cel-sis
      [n: {"C4", 1, "in"}, n: {"D4", 1, "ex-"}, n: {"E4", 1, "cel-"}, n: {"F4", 1, "sis"}],
      # 18  alto (mel): De-  ok: score lower treble E4-D4-C4 (mel line); sopranos hold G4 above
      [n: {"E4", 2, "De-"}, n: {"D4", 1.5, "~De-"}, n: {"C4", 0.5, "~De-"}],
      # 19  alto (mel): o!
      [n: {"C4", 4, "o!"}],
      # 20  unison: The shep-herds came to
      [
        rest: 0.5,
        n: {"G4", 0.5, "The"},
        n: {"A4", 0.5, "shep-"},
        n: {"G4", 0.5, "herds"},
        n: {"G4", 1, "came"},
        n: {"C5", 1, "to"}
      ],
      # 21  unison: see the Ba-by,
      [
        rest: 1,
        n: {"D4", 0.5, "see"},
        n: {"E4", 0.5, "the"},
        n: {"D4", 0.5, "Ba-"},
        n: {"C4", 0.5, "~Ba-"},
        n: {"C4", 1, "by,"}
      ],
      # 22  unison: stood by His moth-er's side
      [
        rest: 0.5,
        n: {"G4", 0.5, "stood"},
        n: {"A4", 0.5, "by"},
        n: {"G4", 0.5, "His"},
        n: {"G4", 0.75, "moth-"},
        n: {"E4", 0.75, "er's"},
        n: {"E4", 0.5, "side"}
      ],
      # 23  unison: (side)
      [n: {"E4", 2, "~side"}, rest: 2],
      # 24  unison: Here laid the Sav-ior
      [
        rest: 0.5,
        n: {"G4", 0.5, "Here"},
        n: {"A4", 0.5, "laid"},
        n: {"G4", 0.5, "the"},
        n: {"G4", 1, "Sav-"},
        n: {"C5", 1, "ior"}
      ],
      # 25  unison: in-side a man-ger.
      [
        rest: 0.5,
        n: {"D4", 0.5, "in-"},
        n: {"D4", 0.5, "side"},
        n: {"E4", 0.5, "a"},
        n: {"D4", 0.5, "man-"},
        n: {"C4", 0.5, "~man-"},
        n: {"C4", 0.5, "ger."},
        rest: 0.5
      ],
      # 26  unison: Oh, what a glo-ri-ous
      [
        n: {"E4", 0.75, "Oh,"},
        n: {"D4", 0.75, "what"},
        n: {"C4", 0.5, "a"},
        n: {"E4", 0.75, "glo-"},
        n: {"D4", 0.75, "ri-"},
        n: {"C4", 0.5, "ous"}
      ],
      # 27  unison: night.
      [n: {"C4", 2, "night."}, rest: 2],
      # 28  unison: Oh, what a glo-ri-ous
      [
        n: {"E4", 0.75, "Oh,"},
        n: {"D4", 0.75, "what"},
        n: {"C4", 0.5, "a"},
        n: {"E4", 0.75, "glo-"},
        n: {"D4", 0.75, "ri-"},
        n: {"C4", 0.5, "ous"}
      ],
      # 29  unison: night.
      [n: {"C4", 4, "night."}],
      # 30  alto (marked mel): I hear the
      [rest: 2.5, n: {"E4", 0.5, "I"}, n: {"D4", 0.5, "hear"}, n: {"C4", 0.5, "the"}],
      # 31  alto (mel): an-gels sing-ing,
      [n: {"C4", 1, "an-"}, n: {"C4", 1, "gels"}, n: {"C4", 1, "sing-"}, n: {"C4", 1, "ing,"}],
      # 32  alto (mel): Hal-le-lu-jah! Let the
      [
        rest: 1,
        n: {"D4", 0.5, "Hal-"},
        n: {"D4", 0.5, "le-"},
        n: {"D4", 0.5, "lu-"},
        n: {"E4", 0.5, "jah!"},
        n: {"D4", 0.5, "Let"},
        n: {"C4", 0.5, "the"}
      ],
      # 33  alto (mel): earth re-ceive her  ok: score lower treble ends on D4; sopranos have G4 above
      [
        n: {"F4", 1, "earth"},
        n: {"F4", 1, "re-"},
        n: {"E4", 1, "ceive"},
        n: {"E4", 0.5, "her"},
        n: {"D4", 0.5, "~her"}
      ],
      # 34  sop: King!" I know that
      [
        n: {"G4", 2, "King!\""},
        rest: 0.5,
        n: {"G4", 0.5, "I"},
        n: {"F4", 0.5, "know"},
        n: {"E4", 0.5, "that"}
      ],
      # 35  sop: Love has come,
      [n: {"F4", 1, "Love"}, n: {"F4", 1, "has"}, n: {"E4", 2, "come,"}],
      # 36  sop: sing it out,   ok: score clearly shows G4 (D4+G4 chords)
      [
        rest: 1,
        n: {"G4", 0.5, "sing"},
        n: {"G4", 0.5, "it"},
        n: {"G4", 0.5, "out,"},
        n: {"A4", 0.5, "~out,"},
        rest: 1
      ],
      # 37  sop: Je-sus Christ is
      [
        n: {"A4", 1, "Je-"},
        n: {"A4", 1, "sus"},
        n: {"G4", 1, "Christ"},
        n: {"A4", 0.5, "is"},
        n: {"G4", 0.5, "~is"}
      ],
      # 38  sop: born!
      [n: {"G4", 3, "born!"}, rest: 1],
      # 39  sop: Je-sus Christ is
      [
        n: {"A4", 1, "Je-"},
        n: {"A4", 1, "sus"},
        n: {"C5", 1, "Christ"},
        n: {"A4", 0.5, "is"},
        n: {"G4", 0.5, "~is"}
      ],
      # 40  sop: born!
      [n: {"G4", 3, "born!"}, rest: 1],
      # 41  alto (marked mel.): Glo-   ok: mel. line G4 under A4, confirmed at 400dpi
      [
        n: {"G4", 2, "Glo-"},
        n: {"A4", 0.5, "~Glo-"},
        n: {"G4", 0.5, "~Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"E4", 0.5, "~Glo-"}
      ],
      # 42  alto (mel.): (Glo-)
      [
        n: {"F4", 2, "~Glo-"},
        n: {"G4", 0.5, "~Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"E4", 0.5, "~Glo-"},
        n: {"D4", 0.5, "~Glo-"}
      ],
      # 43  alto (mel.): (Glo-)
      [
        n: {"E4", 2, "~Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"E4", 0.5, "~Glo-"},
        n: {"D4", 0.5, "~Glo-"},
        n: {"C4", 0.5, "~Glo-"}
      ],
      # 44  alto (mel.) / unison: (Glo-) ri-a
      [n: {"D4", 1.5, "~Glo-"}, n: {"G4", 0.5, "ri-"}, n: {"G4", 1, "a"}, rest: 1],
      # 45  alto (mel.): in ex-cel-sis
      [n: {"C4", 1, "in"}, n: {"D4", 1, "ex-"}, n: {"E4", 1, "cel-"}, n: {"F4", 1, "sis"}],
      # 46  alto (mel.): De-   ok: mel. line E4-D4-C4 (under G4-G4-F4) confirmed at 400dpi
      [n: {"E4", 2, "De-"}, n: {"D4", 1.5, "~De-"}, n: {"C4", 0.5, "~De-"}],
      # 47  alto (mel.): o!
      [n: {"C4", 4, "o!"}],
      # 48  unison: The shep-herds won-dered,
      [
        rest: 0.5,
        n: {"G4", 0.5, "The"},
        n: {"A4", 0.5, "shep-"},
        n: {"G4", 0.5, "herds"},
        n: {"G4", 1, "won-"},
        n: {"C5", 1, "dered,"}
      ],
      # 49  unison: they could-n't hide it,
      [
        rest: 0.5,
        n: {"D4", 0.5, "they"},
        n: {"D4", 0.5, "could-"},
        n: {"E4", 0.5, "n't"},
        n: {"D4", 0.5, "hide"},
        n: {"C4", 0.5, "~hide"},
        n: {"C4", 1, "it,"}
      ],
      # 50  unison: told ev-'ry-one in sight.
      [
        rest: 0.5,
        n: {"G4", 0.5, "told"},
        n: {"A4", 0.5, "ev-"},
        n: {"G4", 0.5, "'ry-"},
        n: {"G4", 0.75, "one"},
        n: {"E4", 0.25, "in"},
        n: {"E4", 0.5, "~in"},
        n: {"E4", 0.5, "sight."}
      ],
      # 51  unison: (sight.)
      [n: {"E4", 2, "~sight."}, rest: 2],
      # 52  unison: All were a-mazed when
      [
        rest: 0.5,
        n: {"G4", 0.5, "All"},
        n: {"A4", 0.5, "were"},
        n: {"G4", 0.5, "a-"},
        n: {"G4", 1, "mazed"},
        n: {"C5", 1, "when"}
      ],
      # 53  unison: they heard how God came
      [
        rest: 0.5,
        n: {"D4", 0.5, "they"},
        n: {"D4", 0.5, "heard"},
        n: {"E4", 0.5, "how"},
        n: {"D4", 0.5, "God"},
        n: {"C4", 0.5, "~God"},
        n: {"C4", 0.5, "came"},
        rest: 0.5
      ],
      # 54  unison: down on the glo-ri-ous
      [
        n: {"E4", 0.75, "down"},
        n: {"D4", 0.25, "on"},
        n: {"D4", 0.5, "~on"},
        n: {"C4", 0.5, "the"},
        n: {"E4", 0.75, "glo-"},
        n: {"D4", 0.25, "ri-"},
        n: {"D4", 0.5, "~ri-"},
        n: {"C4", 0.5, "ous"}
      ],
      # 55  unison women: night. God came
      [n: {"C4", 2, "night."}, rest: 0.5, n: {"E4", 0.75, "God"}, n: {"G4", 0.75, "came"}],
      # 56  sop: down on this glo-ri-ous   ? divides on "glo-ri-ous"; top line taken
      [
        n: {"A4", 0.75, "down"},
        n: {"A4", 0.75, "on"},
        n: {"G4", 0.5, "this"},
        n: {"A4", 0.75, "glo-"},
        n: {"A4", 0.75, "ri-"},
        n: {"C5", 0.5, "ous"}
      ],
      # 57  alto (mel.): night. I hear the   ? beats 1-2 lower note of the divisi chord, "mel." marked
      #   from beat 4
      [
        n: {"E4", 2, "night."},
        rest: 0.5,
        n: {"E4", 0.5, "I"},
        n: {"D4", 0.5, "hear"},
        n: {"C4", 0.5, "the"}
      ],
      # 58  alto (mel.): an-gels sing-ing,
      [n: {"C4", 1, "an-"}, n: {"C4", 1, "gels"}, n: {"C4", 1, "sing-"}, n: {"C4", 1, "ing,"}],
      # 59  alto (mel.): Hal-le-lu-jah! Let the
      [
        rest: 1,
        n: {"D4", 0.5, "Hal-"},
        n: {"D4", 0.5, "le-"},
        n: {"D4", 0.5, "lu-"},
        n: {"E4", 0.5, "jah!"},
        n: {"D4", 0.5, "Let"},
        n: {"C4", 0.5, "the"}
      ],
      # 60  alto (mel.): earth re-ceive her   ok: score has D4/E4 in the 'mel.'-marked lower women's
      #   voice (doubled by lower men); sopranos' G4 drowns it out in the recordings
      [
        n: {"F4", 1, "earth"},
        n: {"F4", 1, "re-"},
        n: {"E4", 1, "ceive"},
        n: {"E4", 0.5, "her"},
        n: {"D4", 0.5, "~her"}
      ],
      # 61  alto (mel.): King! I know that   ok: score has D4/E4 in the 'mel.'-marked lower women's voice
      #   (doubled by lower men); sopranos' G4 drowns it out in the recordings
      [
        n: {"D4", 2, "King!"},
        rest: 0.5,
        n: {"E4", 0.5, "I"},
        n: {"D4", 0.5, "know"},
        n: {"C4", 0.5, "that"}
      ],
      # 62  alto (mel.): Love has come,
      [n: {"C4", 1, "Love"}, n: {"C4", 1, "has"}, n: {"C4", 2, "come,"}],
      # 63  alto (mel.): sing it out,
      [
        rest: 1,
        n: {"D4", 0.5, "sing"},
        n: {"D4", 0.5, "it"},
        n: {"D4", 0.5, "out,"},
        n: {"E4", 0.5, "~out,"},
        rest: 1
      ],
      # 64  alto (mel.): Je-sus Christ is   ok: score has D4/E4 in the 'mel.'-marked lower women's voice
      #   (doubled by lower men); sopranos' G4 drowns it out in the recordings
      [
        n: {"F4", 1, "Je-"},
        n: {"F4", 1, "sus"},
        n: {"E4", 1, "Christ"},
        n: {"E4", 0.5, "is"},
        n: {"D4", 0.5, "~is"}
      ],
      # 65  alto (mel.): born!
      [n: {"D4", 3, "born!"}, rest: 1],
      # 66  alto (mel.): Je-sus Christ is   ok: score has D4/E4 in the 'mel.'-marked lower women's voice
      #   (doubled by lower men); sopranos' G4 drowns it out in the recordings
      [
        n: {"F4", 1, "Je-"},
        n: {"F4", 1, "sus"},
        n: {"G4", 1, "Christ"},
        n: {"E4", 0.5, "is"},
        n: {"D4", 0.5, "~is"}
      ],
      # 67  alto (mel.): born!
      [n: {"D4", 4, "born!"}],
      # 68  (piano)
      [rest: 4],
      # 69  (piano)
      [rest: 4],
      # 70  unison women: Glo-ri-ous,
      [
        n: {"C4", 0.75, "Glo-"},
        n: {"D4", 0.75, "~Glo-"},
        n: {"E4", 0.5, "ri-"},
        n: {"G4", 1, "ous,"},
        rest: 1
      ],
      # 71  unison women: glo-ri-ous,
      [
        n: {"C4", 0.75, "glo-"},
        n: {"D4", 0.75, "~glo-"},
        n: {"E4", 0.5, "ri-"},
        n: {"G4", 1, "ous,"},
        n: {"E4", 1, "~ous,"}
      ],
      # 72  unison women: what a glo-ri-ous
      [
        rest: 1,
        n: {"G4", 0.5, "what"},
        n: {"G4", 0.5, "a"},
        n: {"A4", 0.75, "glo-"},
        n: {"E4", 0.75, "ri-"},
        n: {"E4", 0.5, "ous"}
      ],
      # 73  unison women: night.
      [n: {"E4", 0.5, "night."}, n: {"D4", 1.5, "~night."}, rest: 2],
      # 74  men (8va): Glo-ri-ous,
      [
        n: {"C4", 0.75, "Glo-"},
        n: {"D4", 0.75, "~Glo-"},
        n: {"E4", 0.5, "ri-"},
        n: {"G4", 1, "ous,"},
        rest: 1
      ],
      # 75  men (8va): glo-ri-ous,
      [
        n: {"C4", 0.75, "glo-"},
        n: {"D4", 0.75, "~glo-"},
        n: {"E4", 0.5, "ri-"},
        n: {"G4", 1, "ous,"},
        n: {"E4", 1, "~ous,"}
      ],
      # 76  unison (women + men 8va): what a glo-ri-ous
      [
        rest: 1,
        n: {"G4", 0.5, "what"},
        n: {"G4", 0.5, "a"},
        n: {"A4", 0.75, "glo-"},
        n: {"E4", 0.75, "ri-"},
        n: {"E4", 0.5, "ous"}
      ],
      # 77  unison, then alto (mel.): night. I hear the
      [
        n: {"E4", 0.5, "night."},
        n: {"D4", 1.5, "~night."},
        rest: 0.5,
        n: {"E4", 0.5, "I"},
        n: {"D4", 0.5, "hear"},
        n: {"C4", 0.5, "the"}
      ],
      # 78  alto (mel.): an-gels sing-ing,
      [n: {"C4", 1, "an-"}, n: {"C4", 1, "gels"}, n: {"C4", 1, "sing-"}, n: {"C4", 1, "ing,"}],
      # 79  alto (mel.): Hal-le-lu-jah! Let the
      [
        rest: 1,
        n: {"D4", 0.5, "Hal-"},
        n: {"D4", 0.5, "le-"},
        n: {"D4", 0.5, "lu-"},
        n: {"E4", 0.5, "jah!"},
        n: {"D4", 0.5, "Let"},
        n: {"C4", 0.5, "the"}
      ],
      # 80  alto (mel.): earth re-ceive her   ok: score has D4/E4 in the 'mel.'-marked lower women's
      #   voice (doubled by lower men); sopranos' G4 drowns it out in the recordings
      [
        n: {"F4", 1, "earth"},
        n: {"F4", 1, "re-"},
        n: {"E4", 1, "ceive"},
        n: {"E4", 0.5, "her"},
        n: {"D4", 0.5, "~her"}
      ],
      # 81  sop - King! I know that
      [
        n: {"G4", 2, "King!"},
        rest: 0.5,
        n: {"G4", 0.5, "I"},
        n: {"F4", 0.5, "know"},
        n: {"E4", 0.5, "that"}
      ],
      # 82  sop - Love has come,
      [n: {"F4", 1, "Love"}, n: {"F4", 1, "has"}, n: {"E4", 2, "come,"}],
      # 83  sop - sing it out,
      [
        rest: 1,
        n: {"G4", 0.5, "sing"},
        n: {"G4", 0.5, "it"},
        n: {"G4", 0.5, "out,"},
        n: {"A4", 0.5, "~out,"},
        rest: 1
      ],
      # 84  sop - Je-sus Christ is
      [
        n: {"A4", 1, "Je-"},
        n: {"A4", 1, "sus"},
        n: {"C5", 1, "Christ"},
        n: {"A4", 0.5, "is"},
        n: {"G4", 0.5, "~is"}
      ],
      # 85  sop - born! I hear the
      [
        n: {"G4", 2, "born!"},
        rest: 0.5,
        n: {"G4", 0.5, "I"},
        n: {"F4", 0.5, "hear"},
        n: {"E4", 0.5, "the"}
      ],
      # 86  sop - an-gels sing-ing,
      [n: {"F4", 1, "an-"}, n: {"F4", 1, "gels"}, n: {"E4", 1, "sing-"}, n: {"E4", 1, "ing,"}],
      # 87  sop - Hal-le-lu-jah! Let the
      [
        rest: 1,
        n: {"G4", 0.5, "Hal-"},
        n: {"G4", 0.5, "le-"},
        n: {"G4", 0.5, "lu-"},
        n: {"A4", 0.5, "jah!"},
        n: {"F4", 0.5, "Let"},
        n: {"E4", 0.5, "the"}
      ],
      # 88  sop - earth re-ceive her
      [
        n: {"A4", 1, "earth"},
        n: {"A4", 1, "re-"},
        n: {"G4", 1, "ceive"},
        n: {"A4", 0.5, "her"},
        n: {"G4", 0.5, "~her"}
      ],
      # 89  sop - King! I know that
      [
        n: {"G4", 2, "King!"},
        rest: 0.5,
        n: {"G4", 0.5, "I"},
        n: {"F4", 0.5, "know"},
        n: {"E4", 0.5, "that"}
      ],
      # 90  sop - Love has come,
      [n: {"F4", 1, "Love"}, n: {"F4", 1, "has"}, n: {"E4", 2, "come,"}],
      # 91  sop - sing it out,
      [
        rest: 1,
        n: {"G4", 0.5, "sing"},
        n: {"G4", 0.5, "it"},
        n: {"G4", 0.5, "out,"},
        n: {"A4", 0.5, "~out,"},
        rest: 1
      ],
      # 92  sop - Je-sus Christ is
      [
        n: {"A4", 1, "Je-"},
        n: {"A4", 1, "sus"},
        n: {"G4", 1, "Christ"},
        n: {"A4", 0.5, "is"},
        n: {"G4", 0.5, "~is"}
      ],
      # 93  sop - born!
      [n: {"G4", 3, "born!"}, rest: 1],
      # 94  sop - Je-sus Christ is
      [
        n: {"A4", 1, "Je-"},
        n: {"A4", 1, "sus"},
        n: {"C5", 1, "Christ"},
        n: {"A4", 0.5, "is"},
        n: {"G4", 0.5, "~is"}
      ],
      # 95  sop - born!
      [n: {"G4", 3, "born!"}, rest: 1],
      # 96  alto (marked mel): Gloria melisma - Glo-   ok: 400dpi confirms alto G4 half (carol tune);
      #   alto buried in recordings
      [
        n: {"G4", 2, "Glo-"},
        n: {"A4", 0.5, "~Glo-"},
        n: {"G4", 0.5, "~Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"E4", 0.5, "~Glo-"}
      ],
      # 97  alto (mel) - (Glo-)
      [
        n: {"F4", 2, "~Glo-"},
        n: {"G4", 0.5, "~Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"E4", 0.5, "~Glo-"},
        n: {"D4", 0.5, "~Glo-"}
      ],
      # 98  alto (mel) - (Glo-)
      [
        n: {"E4", 2, "~Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"E4", 0.5, "~Glo-"},
        n: {"D4", 0.5, "~Glo-"},
        n: {"C4", 0.5, "~Glo-"}
      ],
      # 99  alto (mel), ri-a in unison - ri-a
      [n: {"D4", 1.5, "~Glo-"}, n: {"G4", 0.5, "ri-"}, n: {"G4", 1, "a"}, rest: 1],
      # 100  alto (mel) - in ex-cel-sis
      [n: {"C4", 1, "in"}, n: {"D4", 1, "ex-"}, n: {"E4", 1, "cel-"}, n: {"F4", 1, "sis"}],
      # 101  alto (mel)   - De-   ok: 400dpi confirms alto E4 half, D4 dotted quarter, C4 eighth (carol
      #   tune); other voices louder
      [n: {"E4", 2, "De-"}, n: {"D4", 1.5, "~De-"}, n: {"C4", 0.5, "~De-"}],
      # 102  alto (mel) - o!
      [n: {"C4", 4, "o!"}],
      # 103  (rest)
      [rest: 4],
      # 104  unison (women): All is calm now,
      [
        rest: 1,
        n: {"A4", 0.5, "All"},
        n: {"G4", 0.5, "is"},
        n: {"G4", 1, "calm"},
        n: {"C5", 1, "now,"}
      ],
      # 105  unison (women): all is qui-et. A
      [
        rest: 1,
        n: {"D4", 0.5, "all"},
        n: {"E4", 0.5, "is"},
        n: {"D4", 0.5, "qui-"},
        n: {"C4", 0.5, "et."},
        rest: 0.5,
        n: {"C4", 0.5, "A"}
      ],
      # 106  unison (women): star shin-ing in the sky.
      [
        n: {"A4", 0.75, "star"},
        n: {"G4", 0.75, "shin-"},
        n: {"G4", 0.5, "ing"},
        n: {"G4", 0.75, "in"},
        n: {"E4", 0.75, "the"},
        n: {"E4", 0.5, "sky."}
      ],
      # 107  unison (women): (sky.)
      [n: {"E4", 2, "~sky."}, rest: 2],
      # 108  unison (women): Be-low in Beth-le-hem,
      [
        rest: 0.5,
        n: {"G4", 0.5, "Be-"},
        n: {"A4", 0.5, "low"},
        n: {"G4", 0.5, "in"},
        n: {"G4", 0.5, "Beth-"},
        n: {"E4", 0.5, "le-"},
        n: {"E4", 1, "hem,"}
      ],
      # 109  unison (women): the King is sleep-ing.
      [
        rest: 0.5,
        n: {"D4", 0.5, "the"},
        n: {"D4", 0.5, "King"},
        n: {"E4", 0.5, "is"},
        n: {"D4", 0.5, "sleep-"},
        n: {"C4", 0.5, "~sleep-"},
        n: {"C4", 0.5, "ing."},
        rest: 0.5
      ],
      # 110  unison (women): Oh, what a glo-ri-ous
      [
        n: {"E4", 0.75, "Oh,"},
        n: {"D4", 0.75, "what"},
        n: {"C4", 0.5, "a"},
        n: {"E4", 0.75, "glo-"},
        n: {"D4", 0.75, "ri-"},
        n: {"C4", 0.5, "ous"}
      ],
      # 111  unison (women): night.
      [n: {"C4", 2, "night."}, rest: 2],
      # 112  unison (women): Oh, what a glo-ri-ous   (rit.)   ok: 400dpi confirms unison E-D-C, same as
      #   bar 110; recordings pitch-unstable at rit.
      [
        n: {"E4", 0.75, "Oh,"},
        n: {"D4", 0.75, "what"},
        n: {"C4", 0.5, "a"},
        n: {"E4", 0.75, "glo-"},
        n: {"D4", 0.75, "ri-"},
        n: {"C4", 0.5, "ous"}
      ],
      # 113  unison (women): night.   (fermata, final bar)
      [n: {"C4", 4, "night."}]
    ]
  end
end
