defmodule ChoirCoach.Songs.OComeAllYeFaithful do
  @moduledoc """
  "O Come, All Ye Faithful" (traditional; the Musicnotes arrangement for
  mixed chorus with optional accompaniment, 2009) and the refrain "For You
  Alone Are Worthy", all four voice parts and the melody, in performance
  order: the intro (bars 1–5, bar 1 a one-beat pickup), verses 1–3 (6–28,
  29–51, 52–74: the score's repeat with its 1.2. and 3. endings, the final
  fermata on 74), then the refrain (75–85, its pickup "For" a bar of its
  own each time).

  A congregational song: everyone sings the melody, so the practice screen
  opens on it, with the singer's own part to switch to.

  The sheet music is canonical. The choir's band recordings follow another
  arrangement (in F, with its own form; its only voices are backing
  harmonies in the choruses), so the app's recordings are made from this
  transcription (`scripts/render_score.exs`): the score's piano part
  (`ChoirCoach.Songs.OComeAllYeFaithful.Piano`, doubled by the choir's own
  notes in the refrain, which prints no piano) and Kevin singing the
  melody to it in two takes in `audio_src/o_come_all_ye_faithful/`:
  `vocal_0.wav`, verse 1 (song time = take time + 730 ms) and `vocal.wav`,
  verses 2 and 3 and the refrain (+ 43 790 ms), each offset fitted against
  the melody at the app's tempo. As sung, 74–75% of their readings land on
  the written note and every miss is under 1.3 semitones; both are
  pitch-corrected to the melody (`scripts/tune_vocal.py`: 1 note of 209
  still over 0.3 semitones off, 98% of readings on the note). Beyond those
  takes nothing can check a note, so every bar was read at 400 dpi and the
  voices checked against the piano's harmony.

  The tune (Adeste Fideles) is the soprano's throughout, so the melody is
  the soprano line. Soprano and alto are the upper and lower voices of the
  treble staff, tenor and bass of the bass staff; verses 2 and 3 have no
  pickup (the score sets "Sing," and "Yea," on the downbeat).
  """

  alias ChoirCoach.Song
  alias ChoirCoach.Songs.OComeAllYeFaithful.Piano

  @doc "The parts: the four voice parts, top down, then the melody."
  def parts, do: [:soprano, :alto, :tenor, :bass, :melody]

  @doc "Everyone sings the melody: it is the part the practice screen opens on."
  def congregational?, do: true

  @doc """
  Each part's recordings, made from the score (`scripts/render_score.exs`):
  the split track (the piano accompaniment left, the sung melody right)
  serves every part, beside the part's piano.
  """
  def tracks(part) do
    split = %{
      file: "o_come_all_ye_faithful/split.mp3",
      bar1_ms: 1_000.0,
      voice: :right,
      label: "Split track"
    }

    %{
      split: split,
      demo: %{
        file: "o_come_all_ye_faithful/demo.mp3",
        bar1_ms: 1_000.0,
        voice: :mixed,
        label: "Demo"
      },
      rehearsal: Map.merge(split, %{label: "Sung melody", detail: "One voice, pitch-corrected"}),
      piano: %{
        file: "o_come_all_ye_faithful/piano_#{part}.mp3",
        bar1_ms: 1_000.0,
        voice: :left,
        label: "Piano"
      }
    }
  end

  # Every part shares the bar timeline (and so every track's offsets).
  defp timing do
    [
      title: "O Come, All Ye Faithful",
      key: 1,
      tempo_bpm: 104,
      beats_per_bar: 4,
      first_bar: 1,
      start_ms: 1_000.0,
      # Bar 1 is the one-beat pickup; in the refrain the pickup "For" is a
      # bar of its own (75, 78, 81), "wor-thy," (77, 80) and "Lord!" (85)
      # three beats.
      meter: %{
        1 => 1,
        2 => 4,
        75 => 1,
        76 => 4,
        77 => 3,
        78 => 1,
        79 => 4,
        80 => 3,
        81 => 1,
        82 => 4,
        85 => 3
      },
      # The final fermata (bar 74): 1.6 × the bar.
      bar_ms: %{74 => 3_692.0}
    ]
  end

  @spec bass() :: Song.t()
  def bass, do: Song.build(timing() ++ [part: :bass, clef: :bass, bars: bass_bars()])

  @spec melody() :: Song.t()
  def melody, do: Song.build(timing() ++ [part: :melody, clef: :treble, bars: melody_bars()])

  @spec soprano() :: Song.t()
  def soprano, do: Song.build(timing() ++ [part: :soprano, clef: :treble, bars: soprano_bars()])

  @spec alto() :: Song.t()
  def alto, do: Song.build(timing() ++ [part: :alto, clef: :treble, bars: alto_bars()])

  @spec tenor() :: Song.t()
  def tenor, do: Song.build(timing() ++ [part: :tenor, clef: :bass, bars: tenor_bars()])

  @doc """
  The score's piano accompaniment, for rendering the backing: one
  `ChoirCoach.Song` per layer of the piano's chords (top voice first), on
  the parts' bar timeline. Never drawn, so every layer is on the treble clef.
  """
  @spec accompaniment() :: [Song.t()]
  def accompaniment do
    for {bars, i} <- Enum.with_index(Piano.layers()) do
      Song.build(timing() ++ [part: :"piano_#{i}", clef: :treble, bars: bars])
    end
  end

  defp bass_bars do
    [
      # 1  (s1)  (rest)
      [rest: 1],
      # 2  (s2)  (rest)
      [rest: 4],
      # 3  (s3)  (rest)
      [rest: 4],
      # 4  (s4)  (rest)
      [rest: 4],
      # 5  (s5)  Oh,
      [rest: 3, n: {"G3", 1, "Oh,"}],
      # 6  (s6, v1)  come, all ye
      [n: {"G3", 2, "come,"}, n: {"B3", 1, "all"}, n: {"G3", 1, "ye"}],
      # 7  (s7, v1)  faith-ful,
      [n: {"F#3", 2, "faith-"}, n: {"F#3", 2, "ful,"}],
      # 8  (s8, v1)  Joy-ful and tri-
      [n: {"G3", 1, "Joy-"}, n: {"F#3", 1, "ful"}, n: {"G3", 1, "and"}, n: {"C3", 1, "tri-"}],
      # 9  (s9, v1)  um-phant! Oh,
      [n: {"D3", 2, "um-"}, n: {"D3", 1, "phant!"}, n: {"E3", 1, "Oh,"}],
      # 10  (s10, v1)  come ye, oh,
      [n: {"E3", 2, "come"}, n: {"D3", 1, "ye,"}, n: {"A2", 1, "oh,"}],
      # 11  (s11, v1)  come ye to
      [n: {"D3", 1, "come"}, n: {"B2", 1, "~come"}, n: {"F#2", 1, "ye"}, n: {"G2", 1, "to"}],
      # 12  (s12, v1)  Beth-le-
      [n: {"A2", 2, "Beth-"}, n: {"A2", 1.5, "~Beth-"}, n: {"D3", 0.5, "le-"}],
      # 13  (s13, v1)  hem;
      [n: {"D3", 3, "hem;"}, rest: 1],
      # 14  (s14, v1)  Come and be-
      [n: {"B3", 2, "Come"}, n: {"A3", 1, "and"}, n: {"G3", 1, "be-"}],
      # 15  (s15, v1)  hold him
      [n: {"A3", 2, "hold"}, n: {"G3", 2, "him"}],
      # 16  (s16, v1)  Born the king of
      [n: {"F#3", 1, "Born"}, n: {"G3", 1, "the"}, n: {"E3", 1, "king"}, n: {"C3", 1, "of"}],
      # 17  (s17, v1)  an-gels; Oh,
      [n: {"D3", 2, "an-"}, n: {"D3", 1, "gels;"}, rest: 1],
      # 18  (s18, v1)  (rest)
      [rest: 4],
      # 19  (s19, v1)  (rest)
      [rest: 4],
      # 20  (s20, v1)  (rest)
      [rest: 4],
      # 21  (s21, v1)  dore him, Oh,
      [rest: 3, n: {"G3", 1, "Oh,"}],
      # 22  (s22, v1)  come, let us a-
      [n: {"A3", 1, "come,"}, n: {"G3", 1, "let"}, n: {"F#3", 1, "us"}, n: {"E3", 1, "a-"}],
      # 23  (s23, v1)  dore him,
      [n: {"D3", 1, "dore"}, n: {"C3", 1, "~dore"}, n: {"B2", 1, "him,"}, n: {"C3", 1, "~him,"}],
      # 24  (s24, v1)  Christ the
      [n: {"D3", 2, "Christ"}, n: {"D3", 1.5, "~Christ"}, n: {"G2", 0.5, "the"}],
      # 25  (s25, v1)  Lord!
      [n: {"G2", 4, "Lord!"}],
      # 26  (s26, v1)  (rest)
      [rest: 4],
      # 27  (s27, v1)  (rest)
      [rest: 4],
      # 28  (s28, v1)  (rest)
      [rest: 4],
      # 29  (s6, v2)  Sing, choirs of
      [n: {"G3", 2, "Sing,"}, n: {"B3", 1, "choirs"}, n: {"G3", 1, "of"}],
      # 30  (s7, v2)  an-gels,
      [n: {"F#3", 2, "an-"}, n: {"F#3", 2, "gels,"}],
      # 31  (s8, v2)  Sing in ex-ul-
      [n: {"G3", 1, "Sing"}, n: {"F#3", 1, "in"}, n: {"G3", 1, "ex-"}, n: {"C3", 1, "ul-"}],
      # 32  (s9, v2)  ta-tion,
      [n: {"D3", 2, "ta-"}, n: {"D3", 1, "tion,"}, n: {"E3", 1, "~tion,"}],
      # 33  (s10, v2)  Sing, all ye
      [n: {"E3", 2, "Sing,"}, n: {"D3", 1, "all"}, n: {"A2", 1, "ye"}],
      # 34  (s11, v2)  cit-i-zens of
      [n: {"D3", 1, "cit-"}, n: {"B2", 1, "i-"}, n: {"F#2", 1, "zens"}, n: {"G2", 1, "of"}],
      # 35  (s12, v2)  heav-en a-
      [n: {"A2", 2, "heav-"}, n: {"A2", 1.5, "en"}, n: {"D3", 0.5, "a-"}],
      # 36  (s13, v2)  bove!
      [n: {"D3", 3, "bove!"}, rest: 1],
      # 37  (s14, v2)  Glo-ry to
      [n: {"B3", 2, "Glo-"}, n: {"A3", 1, "ry"}, n: {"G3", 1, "to"}],
      # 38  (s15, v2)  God
      [n: {"A3", 2, "God"}, n: {"G3", 2, "~God"}],
      # 39  (s16, v2)  In the
      [n: {"F#3", 1, "In"}, n: {"G3", 1, "~In"}, n: {"E3", 1, "the"}, n: {"C3", 1, "~the"}],
      # 40  (s17, v2)  high-est: Oh,
      [n: {"D3", 2, "high-"}, n: {"D3", 1, "est:"}, rest: 1],
      # 41  (s18, v2)  (rest)
      [rest: 4],
      # 42  (s19, v2)  (rest)
      [rest: 4],
      # 43  (s20, v2)  (rest)
      [rest: 4],
      # 44  (s21, v2)  dore him, Oh,
      [rest: 3, n: {"G3", 1, "Oh,"}],
      # 45  (s22, v2)  come, let us a-
      [n: {"A3", 1, "come,"}, n: {"G3", 1, "let"}, n: {"F#3", 1, "us"}, n: {"E3", 1, "a-"}],
      # 46  (s23, v2)  dore him,
      [n: {"D3", 1, "dore"}, n: {"C3", 1, "~dore"}, n: {"B2", 1, "him,"}, n: {"C3", 1, "~him,"}],
      # 47  (s24, v2)  Christ the
      [n: {"D3", 2, "Christ"}, n: {"D3", 1.5, "~Christ"}, n: {"G2", 0.5, "the"}],
      # 48  (s25, v2)  Lord!
      [n: {"G2", 4, "Lord!"}],
      # 49  (s26, v2)  (rest)
      [rest: 4],
      # 50  (s27, v2)  (rest)
      [rest: 4],
      # 51  (s28, v2)  (rest)
      [rest: 4],
      # 52  (s6, v3)  Yea, Lord, we
      [n: {"G3", 2, "Yea,"}, n: {"B3", 1, "Lord,"}, n: {"G3", 1, "we"}],
      # 53  (s7, v3)  greet thee,
      [n: {"F#3", 2, "greet"}, n: {"F#3", 2, "thee,"}],
      # 54  (s8, v3)  Born this hap-py
      [n: {"G3", 1, "Born"}, n: {"F#3", 1, "this"}, n: {"G3", 1, "hap-"}, n: {"C3", 1, "py"}],
      # 55  (s9, v3)  morn-ing;
      [n: {"D3", 2, "morn-"}, n: {"D3", 1, "ing;"}, n: {"E3", 1, "~ing;"}],
      # 56  (s10, v3)  Je-sus, to
      [n: {"E3", 2, "Je-"}, n: {"D3", 1, "sus,"}, n: {"A2", 1, "to"}],
      # 57  (s11, v3)  thee be
      [n: {"D3", 1, "thee"}, n: {"B2", 1, "~thee"}, n: {"F#2", 1, "be"}, n: {"G2", 1, "~be"}],
      # 58  (s12, v3)  glo-ry
      [n: {"A2", 2, "glo-"}, n: {"A2", 1.5, "~glo-"}, n: {"D3", 0.5, "ry"}],
      # 59  (s13, v3)  giv'n!
      [n: {"D3", 3, "giv'n!"}, rest: 1],
      # 60  (s14, v3)  Word of the
      [n: {"B3", 2, "Word"}, n: {"A3", 1, "of"}, n: {"G3", 1, "the"}],
      # 61  (s15, v3)  Fa-ther,
      [n: {"A3", 2, "Fa-"}, n: {"G3", 2, "ther,"}],
      # 62  (s16, v3)  Now in flesh ap-
      [n: {"F#3", 1, "Now"}, n: {"G3", 1, "in"}, n: {"E3", 1, "flesh"}, n: {"C3", 1, "ap-"}],
      # 63  (s17, v3)  pear-ing: Oh,
      [n: {"D3", 2, "pear-"}, n: {"D3", 1, "ing:"}, rest: 1],
      # 64  (s18, v3)  (rest)
      [rest: 4],
      # 65  (s19, v3)  (rest)
      [rest: 4],
      # 66  (s20, v3)  (rest)
      [rest: 4],
      # 67  (s21, v3)  dore him, Oh,
      [rest: 3, n: {"G3", 1, "Oh,"}],
      # 68  (s22, v3)  come, let us a-
      [n: {"A3", 1, "come,"}, n: {"G3", 1, "let"}, n: {"F#3", 1, "us"}, n: {"E3", 1, "a-"}],
      # 69  (s23, v3)  dore him,
      [n: {"D3", 1, "dore"}, n: {"C3", 1, "~dore"}, n: {"B2", 1, "him,"}, n: {"C3", 1, "~him,"}],
      # 70  (s24, v3)  Christ the
      [n: {"D3", 2, "Christ"}, n: {"D3", 1.5, "~Christ"}, n: {"G2", 0.5, "the"}],
      # 71  (s29, v3)  Lord!
      [n: {"G2", 4, "Lord!"}],
      # 72  (s30, v3)  (rest)
      [rest: 4],
      # 73  (s31, v3)  (rest)
      [rest: 4],
      # 74  (s32, v3)  (rest)
      [rest: 4],
      # 75  (r1)  For
      [n: {"G3", 1, "For"}],
      # 76  (r2)  You a-lone are
      [n: {"G3", 1, "You"}, n: {"D3", 1, "a-"}, n: {"G3", 1, "lone"}, n: {"D3", 1, "are"}],
      # 77  (r3)  wor-thy,
      [n: {"G2", 2, "wor-"}, n: {"G2", 1, "thy,"}],
      # 78  (r4)  For
      [n: {"G3", 1, "For"}],
      # 79  (r5)  You a-lone are
      [n: {"G3", 1, "You"}, n: {"D3", 1, "a-"}, n: {"G3", 1, "lone"}, n: {"C3", 1, "are"}],
      # 80  (r6)  wor-thy,
      [n: {"G3", 2, "wor-"}, n: {"F#3", 1, "thy,"}],
      # 81  (r7)  For
      [n: {"G3", 1, "For"}],
      # 82  (r8)  You a-lone are
      [n: {"A3", 1, "You"}, n: {"G3", 1, "a-"}, n: {"F#3", 1, "lone"}, n: {"E3", 1, "are"}],
      # 83  (r9)  wor-thy,
      [n: {"D3", 1, "wor-"}, n: {"C3", 1, "~wor-"}, n: {"B2", 1, "thy,"}, n: {"C3", 1, "~thy,"}],
      # 84  (r10)  Christ the
      [n: {"D3", 2, "Christ"}, n: {"D3", 1.5, "~Christ"}, n: {"G2", 0.5, "the"}],
      # 85  (r11)  Lord!
      [n: {"G2", 3, "Lord!"}]
    ]
  end

  # The tune is the soprano's in every bar (checked bar by bar).
  defp melody_bars, do: soprano_bars()

  defp soprano_bars do
    [
      # 1  (s1)  (rest)
      [rest: 1],
      # 2  (s2)  (rest)
      [rest: 4],
      # 3  (s3)  (rest)
      [rest: 4],
      # 4  (s4)  (rest)
      [rest: 4],
      # 5  (s5)  Oh,
      [rest: 3, n: {"G4", 1, "Oh,"}],
      # 6  (s6, v1)  come, all ye
      [n: {"G4", 2, "come,"}, n: {"D4", 1, "all"}, n: {"G4", 1, "ye"}],
      # 7  (s7, v1)  faith-ful,
      [n: {"A4", 2, "faith-"}, n: {"D4", 2, "ful,"}],
      # 8  (s8, v1)  Joy-ful and tri-
      [n: {"B4", 1, "Joy-"}, n: {"A4", 1, "ful"}, n: {"B4", 1, "and"}, n: {"C5", 1, "tri-"}],
      # 9  (s9, v1)  um-phant! Oh,
      [n: {"B4", 2, "um-"}, n: {"A4", 1, "phant!"}, n: {"G4", 1, "Oh,"}],
      # 10  (s10, v1)  come ye, oh,
      [n: {"G4", 2, "come"}, n: {"F#4", 1, "ye,"}, n: {"E4", 1, "oh,"}],
      # 11  (s11, v1)  come ye to
      [n: {"F#4", 1, "come"}, n: {"G4", 1, "~come"}, n: {"A4", 1, "ye"}, n: {"B4", 1, "to"}],
      # 12  (s12, v1)  Beth-le-
      [n: {"F#4", 2, "Beth-"}, n: {"E4", 1.5, "~Beth-"}, n: {"D4", 0.5, "le-"}],
      # 13  (s13, v1)  hem;
      [n: {"D4", 3, "hem;"}, rest: 1],
      # 14  (s14, v1)  Come and be-
      [n: {"D5", 2, "Come"}, n: {"C5", 1, "and"}, n: {"B4", 1, "be-"}],
      # 15  (s15, v1)  hold him
      [n: {"C5", 2, "hold"}, n: {"B4", 2, "him"}],
      # 16  (s16, v1)  Born the king of
      [n: {"A4", 1, "Born"}, n: {"B4", 1, "the"}, n: {"G4", 1, "king"}, n: {"A4", 1, "of"}],
      # 17  (s17, v1)  an-gels; Oh,
      [
        n: {"F#4", 1.5, "an-"},
        n: {"E4", 0.5, "~an-"},
        n: {"D4", 1, "gels;"},
        n: {"G4", 1, "Oh,"}
      ],
      # 18  (s18, v1)  come let us a-
      [n: {"G4", 1, "come"}, n: {"F#4", 1, "let"}, n: {"G4", 1, "us"}, n: {"A4", 1, "a-"}],
      # 19  (s19, v1)  dore him, Oh,
      [n: {"G4", 2, "dore"}, n: {"D4", 1, "him,"}, n: {"B4", 1, "Oh,"}],
      # 20  (s20, v1)  come, let us a-
      [n: {"B4", 1, "come,"}, n: {"A4", 1, "let"}, n: {"B4", 1, "us"}, n: {"C5", 1, "a-"}],
      # 21  (s21, v1)  dore him, Oh,
      [n: {"B4", 2, "dore"}, n: {"A4", 1, "him,"}, n: {"B4", 1, "Oh,"}],
      # 22  (s22, v1)  come, let us a-
      [n: {"C5", 1, "come,"}, n: {"B4", 1, "let"}, n: {"A4", 1, "us"}, n: {"G4", 1, "a-"}],
      # 23  (s23, v1)  dore him,
      [n: {"F#4", 2, "dore"}, n: {"G4", 1, "him,"}, n: {"C5", 1, "~him,"}],
      # 24  (s24, v1)  Christ the
      [n: {"B4", 2, "Christ"}, n: {"A4", 1.5, "~Christ"}, n: {"G4", 0.5, "the"}],
      # 25  (s25, v1)  Lord!
      [n: {"G4", 4, "Lord!"}],
      # 26  (s26, v1)  (rest)
      [rest: 4],
      # 27  (s27, v1)  (rest)
      [rest: 4],
      # 28  (s28, v1)  (rest)
      [rest: 4],
      # 29  (s6, v2)  Sing, choirs of
      [n: {"G4", 2, "Sing,"}, n: {"D4", 1, "choirs"}, n: {"G4", 1, "of"}],
      # 30  (s7, v2)  an-gels,
      [n: {"A4", 2, "an-"}, n: {"D4", 2, "gels,"}],
      # 31  (s8, v2)  Sing in ex-ul-
      [n: {"B4", 1, "Sing"}, n: {"A4", 1, "in"}, n: {"B4", 1, "ex-"}, n: {"C5", 1, "ul-"}],
      # 32  (s9, v2)  ta-tion,
      [n: {"B4", 2, "ta-"}, n: {"A4", 1, "tion,"}, n: {"G4", 1, "~tion,"}],
      # 33  (s10, v2)  Sing, all ye
      [n: {"G4", 2, "Sing,"}, n: {"F#4", 1, "all"}, n: {"E4", 1, "ye"}],
      # 34  (s11, v2)  cit-i-zens of
      [n: {"F#4", 1, "cit-"}, n: {"G4", 1, "i-"}, n: {"A4", 1, "zens"}, n: {"B4", 1, "of"}],
      # 35  (s12, v2)  heav-en a-
      [n: {"F#4", 2, "heav-"}, n: {"E4", 1.5, "en"}, n: {"D4", 0.5, "a-"}],
      # 36  (s13, v2)  bove!
      [n: {"D4", 3, "bove!"}, rest: 1],
      # 37  (s14, v2)  Glo-ry to
      [n: {"D5", 2, "Glo-"}, n: {"C5", 1, "ry"}, n: {"B4", 1, "to"}],
      # 38  (s15, v2)  God
      [n: {"C5", 2, "God"}, n: {"B4", 2, "~God"}],
      # 39  (s16, v2)  In the
      [n: {"A4", 1, "In"}, n: {"B4", 1, "~In"}, n: {"G4", 1, "the"}, n: {"A4", 1, "~the"}],
      # 40  (s17, v2)  high-est: Oh,
      [
        n: {"F#4", 1.5, "high-"},
        n: {"E4", 0.5, "~high-"},
        n: {"D4", 1, "est:"},
        n: {"G4", 1, "Oh,"}
      ],
      # 41  (s18, v2)  come let us a-
      [n: {"G4", 1, "come"}, n: {"F#4", 1, "let"}, n: {"G4", 1, "us"}, n: {"A4", 1, "a-"}],
      # 42  (s19, v2)  dore him, Oh,
      [n: {"G4", 2, "dore"}, n: {"D4", 1, "him,"}, n: {"B4", 1, "Oh,"}],
      # 43  (s20, v2)  come, let us a-
      [n: {"B4", 1, "come,"}, n: {"A4", 1, "let"}, n: {"B4", 1, "us"}, n: {"C5", 1, "a-"}],
      # 44  (s21, v2)  dore him, Oh,
      [n: {"B4", 2, "dore"}, n: {"A4", 1, "him,"}, n: {"B4", 1, "Oh,"}],
      # 45  (s22, v2)  come, let us a-
      [n: {"C5", 1, "come,"}, n: {"B4", 1, "let"}, n: {"A4", 1, "us"}, n: {"G4", 1, "a-"}],
      # 46  (s23, v2)  dore him,
      [n: {"F#4", 2, "dore"}, n: {"G4", 1, "him,"}, n: {"C5", 1, "~him,"}],
      # 47  (s24, v2)  Christ the
      [n: {"B4", 2, "Christ"}, n: {"A4", 1.5, "~Christ"}, n: {"G4", 0.5, "the"}],
      # 48  (s25, v2)  Lord!
      [n: {"G4", 4, "Lord!"}],
      # 49  (s26, v2)  (rest)
      [rest: 4],
      # 50  (s27, v2)  (rest)
      [rest: 4],
      # 51  (s28, v2)  (rest)
      [rest: 4],
      # 52  (s6, v3)  Yea, Lord, we
      [n: {"G4", 2, "Yea,"}, n: {"D4", 1, "Lord,"}, n: {"G4", 1, "we"}],
      # 53  (s7, v3)  greet thee,
      [n: {"A4", 2, "greet"}, n: {"D4", 2, "thee,"}],
      # 54  (s8, v3)  Born this hap-py
      [n: {"B4", 1, "Born"}, n: {"A4", 1, "this"}, n: {"B4", 1, "hap-"}, n: {"C5", 1, "py"}],
      # 55  (s9, v3)  morn-ing;
      [n: {"B4", 2, "morn-"}, n: {"A4", 1, "ing;"}, n: {"G4", 1, "~ing;"}],
      # 56  (s10, v3)  Je-sus, to
      [n: {"G4", 2, "Je-"}, n: {"F#4", 1, "sus,"}, n: {"E4", 1, "to"}],
      # 57  (s11, v3)  thee be
      [n: {"F#4", 1, "thee"}, n: {"G4", 1, "~thee"}, n: {"A4", 1, "be"}, n: {"B4", 1, "~be"}],
      # 58  (s12, v3)  glo-ry
      [n: {"F#4", 2, "glo-"}, n: {"E4", 1.5, "~glo-"}, n: {"D4", 0.5, "ry"}],
      # 59  (s13, v3)  giv'n!
      [n: {"D4", 3, "giv'n!"}, rest: 1],
      # 60  (s14, v3)  Word of the
      [n: {"D5", 2, "Word"}, n: {"C5", 1, "of"}, n: {"B4", 1, "the"}],
      # 61  (s15, v3)  Fa-ther,
      [n: {"C5", 2, "Fa-"}, n: {"B4", 2, "ther,"}],
      # 62  (s16, v3)  Now in flesh ap-
      [n: {"A4", 1, "Now"}, n: {"B4", 1, "in"}, n: {"G4", 1, "flesh"}, n: {"A4", 1, "ap-"}],
      # 63  (s17, v3)  pear-ing: Oh,
      [
        n: {"F#4", 1.5, "pear-"},
        n: {"E4", 0.5, "~pear-"},
        n: {"D4", 1, "ing:"},
        n: {"G4", 1, "Oh,"}
      ],
      # 64  (s18, v3)  come let us a-
      [n: {"G4", 1, "come"}, n: {"F#4", 1, "let"}, n: {"G4", 1, "us"}, n: {"A4", 1, "a-"}],
      # 65  (s19, v3)  dore him, Oh,
      [n: {"G4", 2, "dore"}, n: {"D4", 1, "him,"}, n: {"B4", 1, "Oh,"}],
      # 66  (s20, v3)  come, let us a-
      [n: {"B4", 1, "come,"}, n: {"A4", 1, "let"}, n: {"B4", 1, "us"}, n: {"C5", 1, "a-"}],
      # 67  (s21, v3)  dore him, Oh,
      [n: {"B4", 2, "dore"}, n: {"A4", 1, "him,"}, n: {"B4", 1, "Oh,"}],
      # 68  (s22, v3)  come, let us a-
      [n: {"C5", 1, "come,"}, n: {"B4", 1, "let"}, n: {"A4", 1, "us"}, n: {"G4", 1, "a-"}],
      # 69  (s23, v3)  dore him,
      [n: {"F#4", 2, "dore"}, n: {"G4", 1, "him,"}, n: {"C5", 1, "~him,"}],
      # 70  (s24, v3)  Christ the
      [n: {"B4", 2, "Christ"}, n: {"A4", 1.5, "~Christ"}, n: {"G4", 0.5, "the"}],
      # 71  (s29, v3)  Lord!
      [n: {"G4", 4, "Lord!"}],
      # 72  (s30, v3)  (rest)
      [rest: 4],
      # 73  (s31, v3)  (rest)
      [rest: 4],
      # 74  (s32, v3)  (rest)
      [rest: 4],
      # 75  (r1)  For
      [n: {"G4", 1, "For"}],
      # 76  (r2)  You a-lone are
      [n: {"G4", 1, "You"}, n: {"F#4", 1, "a-"}, n: {"G4", 1, "lone"}, n: {"A4", 1, "are"}],
      # 77  (r3)  wor-thy,
      [n: {"G4", 2, "wor-"}, n: {"D4", 1, "thy,"}],
      # 78  (r4)  For
      [n: {"B4", 1, "For"}],
      # 79  (r5)  You a-lone are
      [n: {"B4", 1, "You"}, n: {"A4", 1, "a-"}, n: {"B4", 1, "lone"}, n: {"C5", 1, "are"}],
      # 80  (r6)  wor-thy,
      [n: {"B4", 2, "wor-"}, n: {"A4", 1, "thy,"}],
      # 81  (r7)  For
      [n: {"B4", 1, "For"}],
      # 82  (r8)  You a-lone are
      [n: {"C5", 1, "You"}, n: {"B4", 1, "a-"}, n: {"A4", 1, "lone"}, n: {"G4", 1, "are"}],
      # 83  (r9)  wor-thy,
      [n: {"F#4", 2, "wor-"}, n: {"G4", 1, "thy,"}, n: {"C5", 1, "~thy,"}],
      # 84  (r10)  Christ the
      [n: {"B4", 2, "Christ"}, n: {"A4", 1.5, "~Christ"}, n: {"G4", 0.5, "the"}],
      # 85  (r11)  Lord!
      [n: {"G4", 3, "Lord!"}]
    ]
  end

  defp alto_bars do
    [
      # 1  (s1)  (rest)
      [rest: 1],
      # 2  (s2)  (rest)
      [rest: 4],
      # 3  (s3)  (rest)
      [rest: 4],
      # 4  (s4)  (rest)
      [rest: 4],
      # 5  (s5)  Oh,
      [rest: 3, n: {"D4", 1, "Oh,"}],
      # 6  (s6, v1)  come, all ye
      [n: {"D4", 2, "come,"}, n: {"D4", 1, "all"}, n: {"D4", 1, "ye"}],
      # 7  (s7, v1)  faith-ful,
      [n: {"D4", 2, "faith-"}, n: {"D4", 2, "ful,"}],
      # 8  (s8, v1)  Joy-ful and tri-
      [n: {"D4", 1, "Joy-"}, n: {"D4", 1, "ful"}, n: {"D4", 1, "and"}, n: {"E4", 1, "tri-"}],
      # 9  (s9, v1)  um-phant! Oh,
      [n: {"D4", 2, "um-"}, n: {"D4", 1, "phant!"}, n: {"B3", 1, "Oh,"}],
      # 10  (s10, v1)  come ye, oh,
      [n: {"B3", 1, "come"}, n: {"C#4", 1, "~come"}, n: {"D4", 1, "ye,"}, n: {"C#4", 1, "oh,"}],
      # 11  (s11, v1)  come ye to
      [n: {"D4", 1, "come"}, n: {"D4", 1, "~come"}, n: {"D4", 1, "ye"}, n: {"D4", 1, "to"}],
      # 12  (s12, v1)  Beth-le-
      [n: {"D4", 2, "Beth-"}, n: {"C#4", 1.5, "~Beth-"}, n: {"D4", 0.5, "le-"}],
      # 13  (s13, v1)  hem;
      [n: {"D4", 3, "hem;"}, rest: 1],
      # 14  (s14, v1)  Come and be-
      [n: {"D4", 2, "Come"}, n: {"E4", 0.5, "and"}, n: {"F#4", 0.5, "~and"}, n: {"G4", 1, "be-"}],
      # 15  (s15, v1)  hold him
      [n: {"G4", 1, "hold"}, n: {"F#4", 1, "~hold"}, n: {"G4", 2, "him"}],
      # 16  (s16, v1)  Born the king of
      [n: {"D4", 1, "Born"}, n: {"D4", 1, "the"}, n: {"E4", 1, "king"}, n: {"E4", 1, "of"}],
      # 17  (s17, v1)  an-gels; Oh,
      [n: {"D4", 2, "an-"}, n: {"D4", 1, "gels;"}, n: {"D4", 1, "Oh,"}],
      # 18  (s18, v1)  come let us a-
      [n: {"D4", 4, "come"}],
      # 19  (s19, v1)  dore him, Oh,
      [n: {"D4", 3, "~come"}, n: {"D4", 1, "Oh,"}],
      # 20  (s20, v1)  come, let us a-
      [n: {"D4", 1, "come,"}, n: {"D4", 1, "let"}, n: {"D4", 1, "us"}, n: {"D4", 1, "a-"}],
      # 21  (s21, v1)  dore him, Oh,
      [n: {"D4", 2, "dore"}, n: {"D4", 1, "him,"}, n: {"G4", 1, "Oh,"}],
      # 22  (s22, v1)  come, let us a-
      [
        n: {"F#4", 1, "come,"},
        n: {"G4", 1, "let"},
        n: {"D4", 1, "us"},
        n: {"D4", 0.5, "a-"},
        n: {"C#4", 0.5, "~a-"}
      ],
      # 23  (s23, v1)  dore him,
      [n: {"D4", 2, "dore"}, n: {"D4", 1, "him,"}, n: {"E4", 1, "~him,"}],
      # 24  (s24, v1)  Christ the
      [n: {"D4", 2, "Christ"}, n: {"D4", 1.5, "~Christ"}, n: {"B3", 0.5, "the"}],
      # 25  (s25, v1)  Lord!
      [n: {"B3", 4, "Lord!"}],
      # 26  (s26, v1)  (rest)
      [rest: 4],
      # 27  (s27, v1)  (rest)
      [rest: 4],
      # 28  (s28, v1)  (rest)
      [rest: 4],
      # 29  (s6, v2)  Sing, choirs of
      [n: {"D4", 2, "Sing,"}, n: {"D4", 1, "choirs"}, n: {"D4", 1, "of"}],
      # 30  (s7, v2)  an-gels,
      [n: {"D4", 2, "an-"}, n: {"D4", 2, "gels,"}],
      # 31  (s8, v2)  Sing in ex-ul-
      [n: {"D4", 1, "Sing"}, n: {"D4", 1, "in"}, n: {"D4", 1, "ex-"}, n: {"E4", 1, "ul-"}],
      # 32  (s9, v2)  ta-tion,
      [n: {"D4", 2, "ta-"}, n: {"D4", 1, "tion,"}, n: {"B3", 1, "~tion,"}],
      # 33  (s10, v2)  Sing, all ye
      [n: {"B3", 1, "Sing,"}, n: {"C#4", 1, "~Sing,"}, n: {"D4", 1, "all"}, n: {"C#4", 1, "ye"}],
      # 34  (s11, v2)  cit-i-zens of
      [n: {"D4", 1, "cit-"}, n: {"D4", 1, "i-"}, n: {"D4", 1, "zens"}, n: {"D4", 1, "of"}],
      # 35  (s12, v2)  heav-en a-
      [n: {"D4", 2, "heav-"}, n: {"C#4", 1.5, "en"}, n: {"D4", 0.5, "a-"}],
      # 36  (s13, v2)  bove!
      [n: {"D4", 3, "bove!"}, rest: 1],
      # 37  (s14, v2)  Glo-ry to
      [n: {"D4", 2, "Glo-"}, n: {"E4", 0.5, "ry"}, n: {"F#4", 0.5, "~ry"}, n: {"G4", 1, "to"}],
      # 38  (s15, v2)  God
      [n: {"G4", 1, "God"}, n: {"F#4", 1, "~God"}, n: {"G4", 2, "~God"}],
      # 39  (s16, v2)  In the
      [n: {"D4", 1, "In"}, n: {"D4", 1, "~In"}, n: {"E4", 1, "the"}, n: {"E4", 1, "~the"}],
      # 40  (s17, v2)  high-est: Oh,
      [n: {"D4", 2, "high-"}, n: {"D4", 1, "est:"}, n: {"D4", 1, "Oh,"}],
      # 41  (s18, v2)  come let us a-
      [n: {"D4", 4, "come"}],
      # 42  (s19, v2)  dore him, Oh,
      [n: {"D4", 3, "~come"}, n: {"D4", 1, "Oh,"}],
      # 43  (s20, v2)  come, let us a-
      [n: {"D4", 1, "come,"}, n: {"D4", 1, "let"}, n: {"D4", 1, "us"}, n: {"D4", 1, "a-"}],
      # 44  (s21, v2)  dore him, Oh,
      [n: {"D4", 2, "dore"}, n: {"D4", 1, "him,"}, n: {"G4", 1, "Oh,"}],
      # 45  (s22, v2)  come, let us a-
      [
        n: {"F#4", 1, "come,"},
        n: {"G4", 1, "let"},
        n: {"D4", 1, "us"},
        n: {"D4", 0.5, "a-"},
        n: {"C#4", 0.5, "~a-"}
      ],
      # 46  (s23, v2)  dore him,
      [n: {"D4", 2, "dore"}, n: {"D4", 1, "him,"}, n: {"E4", 1, "~him,"}],
      # 47  (s24, v2)  Christ the
      [n: {"D4", 2, "Christ"}, n: {"D4", 1.5, "~Christ"}, n: {"B3", 0.5, "the"}],
      # 48  (s25, v2)  Lord!
      [n: {"B3", 4, "Lord!"}],
      # 49  (s26, v2)  (rest)
      [rest: 4],
      # 50  (s27, v2)  (rest)
      [rest: 4],
      # 51  (s28, v2)  (rest)
      [rest: 4],
      # 52  (s6, v3)  Yea, Lord, we
      [n: {"D4", 2, "Yea,"}, n: {"D4", 1, "Lord,"}, n: {"D4", 1, "we"}],
      # 53  (s7, v3)  greet thee,
      [n: {"D4", 2, "greet"}, n: {"D4", 2, "thee,"}],
      # 54  (s8, v3)  Born this hap-py
      [n: {"D4", 1, "Born"}, n: {"D4", 1, "this"}, n: {"D4", 1, "hap-"}, n: {"E4", 1, "py"}],
      # 55  (s9, v3)  morn-ing;
      [n: {"D4", 2, "morn-"}, n: {"D4", 1, "ing;"}, n: {"B3", 1, "~ing;"}],
      # 56  (s10, v3)  Je-sus, to
      [n: {"B3", 1, "Je-"}, n: {"C#4", 1, "~Je-"}, n: {"D4", 1, "sus,"}, n: {"C#4", 1, "to"}],
      # 57  (s11, v3)  thee be
      [n: {"D4", 1, "thee"}, n: {"D4", 1, "~thee"}, n: {"D4", 1, "be"}, n: {"D4", 1, "~be"}],
      # 58  (s12, v3)  glo-ry
      [n: {"D4", 2, "glo-"}, n: {"C#4", 1.5, "~glo-"}, n: {"D4", 0.5, "ry"}],
      # 59  (s13, v3)  giv'n!
      [n: {"D4", 3, "giv'n!"}, rest: 1],
      # 60  (s14, v3)  Word of the
      [n: {"D4", 2, "Word"}, n: {"E4", 0.5, "of"}, n: {"F#4", 0.5, "~of"}, n: {"G4", 1, "the"}],
      # 61  (s15, v3)  Fa-ther,
      [n: {"G4", 1, "Fa-"}, n: {"F#4", 1, "~Fa-"}, n: {"G4", 2, "ther,"}],
      # 62  (s16, v3)  Now in flesh ap-
      [n: {"D4", 1, "Now"}, n: {"D4", 1, "in"}, n: {"E4", 1, "flesh"}, n: {"E4", 1, "ap-"}],
      # 63  (s17, v3)  pear-ing: Oh,
      [n: {"D4", 2, "pear-"}, n: {"D4", 1, "ing:"}, n: {"D4", 1, "Oh,"}],
      # 64  (s18, v3)  come let us a-
      [n: {"D4", 4, "come"}],
      # 65  (s19, v3)  dore him, Oh,
      [n: {"D4", 3, "~come"}, n: {"D4", 1, "Oh,"}],
      # 66  (s20, v3)  come, let us a-
      [n: {"D4", 1, "come,"}, n: {"D4", 1, "let"}, n: {"D4", 1, "us"}, n: {"D4", 1, "a-"}],
      # 67  (s21, v3)  dore him, Oh,
      [n: {"D4", 2, "dore"}, n: {"D4", 1, "him,"}, n: {"G4", 1, "Oh,"}],
      # 68  (s22, v3)  come, let us a-
      [
        n: {"F#4", 1, "come,"},
        n: {"G4", 1, "let"},
        n: {"D4", 1, "us"},
        n: {"D4", 0.5, "a-"},
        n: {"C#4", 0.5, "~a-"}
      ],
      # 69  (s23, v3)  dore him,
      [n: {"D4", 2, "dore"}, n: {"D4", 1, "him,"}, n: {"E4", 1, "~him,"}],
      # 70  (s24, v3)  Christ the
      [n: {"D4", 2, "Christ"}, n: {"D4", 1.5, "~Christ"}, n: {"B3", 0.5, "the"}],
      # 71  (s29, v3)  Lord!
      [n: {"B3", 4, "Lord!"}],
      # 72  (s30, v3)  (rest)
      [rest: 4],
      # 73  (s31, v3)  (rest)
      [rest: 4],
      # 74  (s32, v3)  (rest)
      [rest: 4],
      # 75  (r1)  For
      [n: {"D4", 1, "For"}],
      # 76  (r2)  You a-lone are
      [n: {"D4", 1, "You"}, n: {"D4", 1, "a-"}, n: {"D4", 1, "lone"}, n: {"F#4", 1, "are"}],
      # 77  (r3)  wor-thy,
      [n: {"D4", 2, "wor-"}, n: {"D4", 1, "thy,"}],
      # 78  (r4)  For
      [n: {"D4", 1, "For"}],
      # 79  (r5)  You a-lone are
      [n: {"G4", 1, "You"}, n: {"F#4", 1, "a-"}, n: {"G4", 1, "lone"}, n: {"G4", 1, "are"}],
      # 80  (r6)  wor-thy,
      [n: {"G4", 2, "wor-"}, n: {"D4", 1, "thy,"}],
      # 81  (r7)  For
      [n: {"G4", 0.5, "For"}, n: {"F#4", 0.5, "~For"}],
      # 82  (r8)  You a-lone are
      [
        n: {"E4", 0.5, "You"},
        n: {"F#4", 0.5, "~You"},
        n: {"G4", 1, "a-"},
        n: {"D4", 1, "lone"},
        n: {"C#4", 1, "are"}
      ],
      # 83  (r9)  wor-thy,
      [n: {"D4", 2, "wor-"}, n: {"D4", 1, "thy,"}, n: {"E4", 1, "~thy,"}],
      # 84  (r10)  Christ the
      [n: {"G4", 2, "Christ"}, n: {"F#4", 1.5, "~Christ"}, n: {"D4", 0.5, "the"}],
      # 85  (r11)  Lord!
      [n: {"D4", 3, "Lord!"}]
    ]
  end

  defp tenor_bars do
    [
      # 1  (s1)  (rest)
      [rest: 1],
      # 2  (s2)  (rest)
      [rest: 4],
      # 3  (s3)  (rest)
      [rest: 4],
      # 4  (s4)  (rest)
      [rest: 4],
      # 5  (s5)  Oh,
      [rest: 3, n: {"B3", 1, "Oh,"}],
      # 6  (s6, v1)  come, all ye
      [n: {"B3", 2, "come,"}, n: {"B3", 1, "all"}, n: {"B3", 1, "ye"}],
      # 7  (s7, v1)  faith-ful,
      [n: {"A3", 2, "faith-"}, n: {"A3", 2, "ful,"}],
      # 8  (s8, v1)  Joy-ful and tri-
      [n: {"G3", 1, "Joy-"}, n: {"A3", 1, "ful"}, n: {"G3", 1, "and"}, n: {"G3", 1, "tri-"}],
      # 9  (s9, v1)  um-phant! Oh,
      [n: {"G3", 2, "um-"}, n: {"F#3", 1, "phant!"}, n: {"G3", 1, "Oh,"}],
      # 10  (s10, v1)  come ye, oh,
      [n: {"G3", 2, "come"}, n: {"A3", 1, "ye,"}, n: {"A3", 1, "oh,"}],
      # 11  (s11, v1)  come ye to
      [n: {"A3", 1, "come"}, n: {"G3", 1, "~come"}, n: {"F#3", 1, "ye"}, n: {"E3", 1, "to"}],
      # 12  (s12, v1)  Beth-le-
      [n: {"A3", 2, "Beth-"}, n: {"G3", 1.5, "~Beth-"}, n: {"F#3", 0.5, "le-"}],
      # 13  (s13, v1)  hem;
      [n: {"F#3", 3, "hem;"}, rest: 1],
      # 14  (s14, v1)  Come and be-
      [n: {"B3", 2, "Come"}, n: {"C4", 1, "and"}, n: {"D4", 1, "be-"}],
      # 15  (s15, v1)  hold him
      [n: {"C4", 2, "hold"}, n: {"D4", 2, "him"}],
      # 16  (s16, v1)  Born the king of
      [n: {"A3", 1, "Born"}, n: {"G3", 1, "the"}, n: {"B3", 1, "king"}, n: {"C4", 1, "of"}],
      # 17  (s17, v1)  an-gels; Oh,
      [
        n: {"A3", 1.5, "an-"},
        n: {"G3", 0.5, "~an-"},
        n: {"F#3", 1, "gels;"},
        n: {"B3", 1, "Oh,"}
      ],
      # 18  (s18, v1)  come let us a-
      [n: {"B3", 1, "come"}, n: {"A3", 1, "let"}, n: {"B3", 1, "us"}, n: {"C4", 1, "a-"}],
      # 19  (s19, v1)  dore him, Oh,
      [n: {"B3", 3, "dore"}, n: {"G3", 1, "Oh,"}],
      # 20  (s20, v1)  come, let us a-
      [n: {"G3", 1, "come,"}, n: {"F#3", 1, "let"}, n: {"G3", 1, "us"}, n: {"A3", 1, "a-"}],
      # 21  (s21, v1)  dore him, Oh,
      [n: {"G3", 2, "dore"}, n: {"F#3", 1, "him,"}, n: {"D4", 1, "Oh,"}],
      # 22  (s22, v1)  come, let us a-
      [n: {"D4", 1, "come,"}, n: {"D4", 1, "let"}, n: {"A3", 1, "us"}, n: {"A3", 1, "a-"}],
      # 23  (s23, v1)  dore him,
      [n: {"A3", 2, "dore"}, n: {"G3", 2, "him,"}],
      # 24  (s24, v1)  Christ the
      [n: {"G3", 2, "Christ"}, n: {"F#3", 1.5, "~Christ"}, n: {"G3", 0.5, "the"}],
      # 25  (s25, v1)  Lord!
      [n: {"G3", 4, "Lord!"}],
      # 26  (s26, v1)  (rest)
      [rest: 4],
      # 27  (s27, v1)  (rest)
      [rest: 4],
      # 28  (s28, v1)  (rest)
      [rest: 4],
      # 29  (s6, v2)  Sing, choirs of
      [n: {"B3", 2, "Sing,"}, n: {"B3", 1, "choirs"}, n: {"B3", 1, "of"}],
      # 30  (s7, v2)  an-gels,
      [n: {"A3", 2, "an-"}, n: {"A3", 2, "gels,"}],
      # 31  (s8, v2)  Sing in ex-ul-
      [n: {"G3", 1, "Sing"}, n: {"A3", 1, "in"}, n: {"G3", 1, "ex-"}, n: {"G3", 1, "ul-"}],
      # 32  (s9, v2)  ta-tion,
      [n: {"G3", 2, "ta-"}, n: {"F#3", 1, "tion,"}, n: {"G3", 1, "~tion,"}],
      # 33  (s10, v2)  Sing, all ye
      [n: {"G3", 2, "Sing,"}, n: {"A3", 1, "all"}, n: {"A3", 1, "ye"}],
      # 34  (s11, v2)  cit-i-zens of
      [n: {"A3", 1, "cit-"}, n: {"G3", 1, "i-"}, n: {"F#3", 1, "zens"}, n: {"E3", 1, "of"}],
      # 35  (s12, v2)  heav-en a-
      [n: {"A3", 2, "heav-"}, n: {"G3", 1.5, "en"}, n: {"F#3", 0.5, "a-"}],
      # 36  (s13, v2)  bove!
      [n: {"F#3", 3, "bove!"}, rest: 1],
      # 37  (s14, v2)  Glo-ry to
      [n: {"B3", 2, "Glo-"}, n: {"C4", 1, "ry"}, n: {"D4", 1, "to"}],
      # 38  (s15, v2)  God
      [n: {"C4", 2, "God"}, n: {"D4", 2, "~God"}],
      # 39  (s16, v2)  In the
      [n: {"A3", 1, "In"}, n: {"G3", 1, "~In"}, n: {"B3", 1, "the"}, n: {"C4", 1, "~the"}],
      # 40  (s17, v2)  high-est: Oh,
      [
        n: {"A3", 1.5, "high-"},
        n: {"G3", 0.5, "~high-"},
        n: {"F#3", 1, "est:"},
        n: {"B3", 1, "Oh,"}
      ],
      # 41  (s18, v2)  come let us a-
      [n: {"B3", 1, "come"}, n: {"A3", 1, "let"}, n: {"B3", 1, "us"}, n: {"C4", 1, "a-"}],
      # 42  (s19, v2)  dore him, Oh,
      [n: {"B3", 3, "dore"}, n: {"G3", 1, "Oh,"}],
      # 43  (s20, v2)  come, let us a-
      [n: {"G3", 1, "come,"}, n: {"F#3", 1, "let"}, n: {"G3", 1, "us"}, n: {"A3", 1, "a-"}],
      # 44  (s21, v2)  dore him, Oh,
      [n: {"G3", 2, "dore"}, n: {"F#3", 1, "him,"}, n: {"D4", 1, "Oh,"}],
      # 45  (s22, v2)  come, let us a-
      [n: {"D4", 1, "come,"}, n: {"D4", 1, "let"}, n: {"A3", 1, "us"}, n: {"A3", 1, "a-"}],
      # 46  (s23, v2)  dore him,
      [n: {"A3", 2, "dore"}, n: {"G3", 2, "him,"}],
      # 47  (s24, v2)  Christ the
      [n: {"G3", 2, "Christ"}, n: {"F#3", 1.5, "~Christ"}, n: {"G3", 0.5, "the"}],
      # 48  (s25, v2)  Lord!
      [n: {"G3", 4, "Lord!"}],
      # 49  (s26, v2)  (rest)
      [rest: 4],
      # 50  (s27, v2)  (rest)
      [rest: 4],
      # 51  (s28, v2)  (rest)
      [rest: 4],
      # 52  (s6, v3)  Yea, Lord, we
      [n: {"B3", 2, "Yea,"}, n: {"B3", 1, "Lord,"}, n: {"B3", 1, "we"}],
      # 53  (s7, v3)  greet thee,
      [n: {"A3", 2, "greet"}, n: {"A3", 2, "thee,"}],
      # 54  (s8, v3)  Born this hap-py
      [n: {"G3", 1, "Born"}, n: {"A3", 1, "this"}, n: {"G3", 1, "hap-"}, n: {"G3", 1, "py"}],
      # 55  (s9, v3)  morn-ing;
      [n: {"G3", 2, "morn-"}, n: {"F#3", 1, "ing;"}, n: {"G3", 1, "~ing;"}],
      # 56  (s10, v3)  Je-sus, to
      [n: {"G3", 2, "Je-"}, n: {"A3", 1, "sus,"}, n: {"A3", 1, "to"}],
      # 57  (s11, v3)  thee be
      [n: {"A3", 1, "thee"}, n: {"G3", 1, "~thee"}, n: {"F#3", 1, "be"}, n: {"E3", 1, "~be"}],
      # 58  (s12, v3)  glo-ry
      [n: {"A3", 2, "glo-"}, n: {"G3", 1.5, "~glo-"}, n: {"F#3", 0.5, "ry"}],
      # 59  (s13, v3)  giv'n!
      [n: {"F#3", 3, "giv'n!"}, rest: 1],
      # 60  (s14, v3)  Word of the
      [n: {"B3", 2, "Word"}, n: {"C4", 1, "of"}, n: {"D4", 1, "the"}],
      # 61  (s15, v3)  Fa-ther,
      [n: {"C4", 2, "Fa-"}, n: {"D4", 2, "ther,"}],
      # 62  (s16, v3)  Now in flesh ap-
      [n: {"A3", 1, "Now"}, n: {"G3", 1, "in"}, n: {"B3", 1, "flesh"}, n: {"C4", 1, "ap-"}],
      # 63  (s17, v3)  pear-ing: Oh,
      [
        n: {"A3", 1.5, "pear-"},
        n: {"G3", 0.5, "~pear-"},
        n: {"F#3", 1, "ing:"},
        n: {"B3", 1, "Oh,"}
      ],
      # 64  (s18, v3)  come let us a-
      [n: {"B3", 1, "come"}, n: {"A3", 1, "let"}, n: {"B3", 1, "us"}, n: {"C4", 1, "a-"}],
      # 65  (s19, v3)  dore him, Oh,
      [n: {"B3", 3, "dore"}, n: {"G3", 1, "Oh,"}],
      # 66  (s20, v3)  come, let us a-
      [n: {"G3", 1, "come,"}, n: {"F#3", 1, "let"}, n: {"G3", 1, "us"}, n: {"A3", 1, "a-"}],
      # 67  (s21, v3)  dore him, Oh,
      [n: {"G3", 2, "dore"}, n: {"F#3", 1, "him,"}, n: {"D4", 1, "Oh,"}],
      # 68  (s22, v3)  come, let us a-
      [n: {"D4", 1, "come,"}, n: {"D4", 1, "let"}, n: {"A3", 1, "us"}, n: {"A3", 1, "a-"}],
      # 69  (s23, v3)  dore him,
      [n: {"A3", 2, "dore"}, n: {"G3", 2, "him,"}],
      # 70  (s24, v3)  Christ the
      [n: {"G3", 2, "Christ"}, n: {"F#3", 1.5, "~Christ"}, n: {"G3", 0.5, "the"}],
      # 71  (s29, v3)  Lord!
      [n: {"G3", 4, "Lord!"}],
      # 72  (s30, v3)  (rest)
      [rest: 4],
      # 73  (s31, v3)  (rest)
      [rest: 4],
      # 74  (s32, v3)  (rest)
      [rest: 4],
      # 75  (r1)  For
      [n: {"B3", 1, "For"}],
      # 76  (r2)  You a-lone are
      [n: {"B3", 1, "You"}, n: {"A3", 1, "a-"}, n: {"B3", 1, "lone"}, n: {"C4", 1, "are"}],
      # 77  (r3)  wor-thy,
      [n: {"B3", 2, "wor-"}, n: {"B3", 1, "thy,"}],
      # 78  (r4)  For
      [n: {"D4", 1, "For"}],
      # 79  (r5)  You a-lone are
      [n: {"D4", 1, "You"}, n: {"D4", 1, "a-"}, n: {"D4", 1, "lone"}, n: {"E4", 1, "are"}],
      # 80  (r6)  wor-thy,
      [n: {"D4", 2, "wor-"}, n: {"D4", 1, "thy,"}],
      # 81  (r7)  For
      [n: {"D4", 1, "For"}],
      # 82  (r8)  You a-lone are
      [n: {"C4", 1, "You"}, n: {"D4", 1, "a-"}, n: {"A3", 1, "lone"}, n: {"A3", 1, "are"}],
      # 83  (r9)  wor-thy,
      [n: {"A3", 2, "wor-"}, n: {"G3", 2, "thy,"}],
      # 84  (r10)  Christ the
      [n: {"D4", 2, "Christ"}, n: {"C4", 1.5, "~Christ"}, n: {"B3", 0.5, "the"}],
      # 85  (r11)  Lord!
      [n: {"B3", 3, "Lord!"}]
    ]
  end
end
