defmodule ChoirCoach.Songs.GraceOfGod do
  @moduledoc """
  "Grace of God with Us" (Brett Younker, Ben Fielding and Aodhan King, arr. Russell Mauldin), bass part
  and melody, bars 1–75.

  Transcribed from the Drive score, bar by bar, and checked note by note
  against the Bass rehearsal track with the pitch detector: every note it
  hears off the written pitch was re-read at 400 dpi (most are the tenor,
  who shares the channel, or a scoop into the note).

  Timing is the Bass rehearsal track's, fitted with `scripts/align_track.exs`:
  bar 1 starts 375 ms in, ♩ = 73.86 (marked 74), the rits. in bars 53, 69
  and 74 and the closing fermata as `bar_ms`. The Split and Demo tracks open
  with the end of the previous medley number (26.5 s and 39.2 s); their
  offsets come from cross-correlating their accompaniment with the rehearsal
  track's.

  The melody is the tune wherever a voice sings it, in the women's register:
  the solo while it sings (the soloist is on the demo, not the part tracks),
  else the unison line or the soprano, the men's line an octave up where they
  have it. Checked against the Soprano rehearsal track and the demo with the
  detector; the notes no recording confirms were re-read at 300–400 dpi and
  match the score.
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
          file: "grace_of_god/split.mp3",
          bar1_ms: 26_826.0,
          voice: :right,
          label: "Split track"
        },
        demo: %{file: "grace_of_god/demo.mp3", bar1_ms: 39_569.0, voice: :mixed, label: "Demo"}
      },
      part_tracks(part)
    )
  end

  defp part_tracks(:bass) do
    %{
      piano: %{file: "grace_of_god/piano_bass.mp3", bar1_ms: 375.0, voice: :left, label: "Piano"},
      rehearsal: %{
        file: "grace_of_god/bass.mp3",
        bar1_ms: 375.0,
        voice: :left,
        label: "Bass rehearsal"
      }
    }
  end

  defp part_tracks(:melody) do
    %{
      piano: %{
        file: "grace_of_god/piano_melody.mp3",
        bar1_ms: 375.0,
        voice: :left,
        label: "Piano"
      },
      rehearsal: %{
        file: "grace_of_god/soprano.mp3",
        bar1_ms: 375.0,
        voice: :left,
        label: "Soprano rehearsal"
      }
    }
  end

  # Every part shares the bar timeline (and so every track's offsets).
  defp timing do
    [
      title: "Grace of God with Us",
      key: 0,
      tempo_bpm: 73.86,
      beats_per_bar: 4,
      first_bar: 1,
      start_ms: 375.0,
      bar_ms: %{53 => 3_420.0, 69 => 3_800.0, 74 => 4_760.0, 75 => 5_940.0}
    ]
  end

  @spec bass() :: Song.t()
  def bass, do: Song.build(timing() ++ [part: :bass, clef: :bass, bars: bass_bars()])

  @spec melody() :: Song.t()
  def melody, do: Song.build(timing() ++ [part: :melody, clef: :treble, bars: melody_bars()])

  defp bass_bars do
    [
      # 1  (piano intro)
      [rest: 4],
      # 2  (piano intro)
      [rest: 4],
      # 3  (SOLO) Wonderful and
      [rest: 4],
      # 4  (SOLO) wise in counsel, for-
      [rest: 4],
      # 5  (SOLO) ever, Mighty
      [rest: 4],
      # 6  (SOLO) God.
      [rest: 4],
      # 7  (SOLO) Precious Father,
      [rest: 4],
      # 8  (SOLO) everlasting,
      [rest: 4],
      # 9  (SOLO) blessed Prince of
      [rest: 4],
      # 10  (SOLO) Peace.
      [rest: 4],
      # 11  Glory to
      [n: {"G3", 2, "Glo-"}, n: {"F3", 1, "ry"}, n: {"E3", 1, "to"}],
      # 12  God in the
      [n: {"G3", 1, "God"}, rest: 1, n: {"E3", 1, "in"}, n: {"G3", 1, "the"}],
      # 13  high-
      [n: {"A3", 2, "high-"}, n: {"G3", 2, "~high-"}],
      # 14  est.
      [n: {"G3", 3, "est."}, rest: 1],
      # 15  Jesus, our
      [n: {"G3", 2, "Je-"}, n: {"F3", 1, "sus,"}, n: {"E3", 1, "our"}],
      # 16  Savior, the
      [n: {"G3", 2, "Sav-"}, n: {"C3", 1, "ior,"}, rest: 0.5, n: {"C3", 0.5, "the"}],
      # 17  grace of God with
      [
        n: {"C3", 1, "grace"},
        n: {"E3", 1, "of"},
        n: {"D3", 1.5, "God"},
        n: {"C3", 0.5, "with"}
      ],
      # 18  us.
      [n: {"C3", 4, "us."}],
      # 19  (WOMEN) The
      [rest: 4],
      # 20  (WOMEN) kings of earth rest
      [rest: 4],
      # 21  (WOMEN) on Your shoulders; You
      [rest: 4],
      # 22  (WOMEN) rule on David's throne.
      [rest: 4],
      # 23  (MEN) Your
      [rest: 3.5, n: {"C3", 0.5, "Your"}],
      # 24  kingdom here is
      [n: {"C3", 1, "king-"}, n: {"B2", 1, "dom"}, n: {"D3", 1, "here"}, n: {"C3", 1, "is"}],
      # 25  now established,
      [
        n: {"C3", 1, "now"},
        n: {"B2", 1, "es-"},
        n: {"D3", 1, "tab-"},
        n: {"C3", 0.5, "lished,"},
        rest: 0.5
      ],
      # 26  (CHOIR) Christ, our Lord of
      [n: {"D3", 1, "Christ,"}, n: {"E3", 1, "our"}, n: {"C3", 1, "Lord"}, n: {"G3", 1, "of"}],
      # 27  lords.
      [n: {"G3", 3, "lords."}, rest: 1],
      # 28  Glory to
      [n: {"C3", 2, "Glo-"}, n: {"D3", 1, "ry"}, n: {"D3", 1, "to"}],
      # 29  God in the
      [n: {"E3", 1, "God"}, rest: 1, n: {"E3", 1, "in"}, n: {"E3", 1, "the"}],
      # 30  high-
      [n: {"F3", 2, "high-"}, n: {"A3", 2, "~high-"}],
      # 31  est.
      [n: {"G3", 3, "est."}, rest: 1],
      # 32  Jesus, our
      [n: {"C3", 2, "Je-"}, n: {"D3", 1, "sus,"}, n: {"D3", 1, "our"}],
      # 33  Savior, the
      [n: {"E3", 2, "Sav-"}, n: {"F3", 1, "ior,"}, rest: 0.5, n: {"F3", 0.5, "the"}],
      # 34  grace of God with
      [
        n: {"G3", 1, "grace"},
        n: {"G3", 1, "of"},
        n: {"G3", 1.5, "God"},
        n: {"C4", 0.5, "with"}
      ],
      # 35  us.
      [n: {"C4", 3, "us."}, rest: 1],
      # 36  Ah
      [n: {"E3", 4, "Ah"}],
      # 37  (Ah)
      [n: {"F3", 2, "~Ah"}, n: {"A3", 2, "~Ah"}],
      # 38  (Ah)
      [n: {"G3", 4, "~Ah"}],
      # 39  Ooo
      [rest: 1, n: {"C3", 1, "Ooo"}, n: {"D3", 2, "~Ooo"}],
      # 40  (Ooo)
      [n: {"E3", 2, "~Ooo"}, n: {"F3", 2, "~Ooo"}],
      # 41  Ooo
      # ? beat-2 G3 notehead carries stems up and down (tenor+bass unison); tenor ties on G3, bass drops to G2
      [rest: 1, n: {"G3", 1, "Ooo"}, n: {"G2", 2, "~Ooo"}],
      # 42  (Ooo)
      [n: {"C3", 4, "~Ooo"}],
      # 43  (piano)
      [rest: 4],
      # 44  (solo: Born that we might)
      [rest: 4],
      # 45  (solo: know forgiveness,)
      [rest: 4],
      # 46  (solo: born that we should)
      [rest: 4],
      # 47  (solo: live. With)
      [rest: 4],
      # 48  (solo: joy and hope, and)
      [rest: 4],
      # 49  (solo: expectation, our)
      [rest: 4],
      # 50  (solo: King will come a-)
      [rest: 4],
      # 51  (solo: gain.) choir: Our
      [rest: 3.5, n: {"C3", 0.5, "Our"}],
      # 52  King will come a-
      [n: {"D3", 1, "King"}, n: {"E3", 1, "will"}, n: {"G3", 1, "come"}, n: {"G3", 1, "a-"}],
      # 53  gain.
      [n: {"F3", 3, "gain."}, rest: 1],
      # 54  Glo-ry to
      [n: {"C3", 2, "Glo-"}, n: {"D3", 1, "ry"}, n: {"D3", 1, "to"}],
      # 55  God in the
      [n: {"E3", 1, "God"}, rest: 1, n: {"E3", 1, "in"}, n: {"E3", 1, "the"}],
      # 56  high-
      [n: {"F3", 2, "high-"}, n: {"A3", 2, "~high-"}],
      # 57  est.
      [n: {"G3", 3, "est."}, rest: 1],
      # 58  Je-sus, our
      [n: {"C3", 2, "Je-"}, n: {"D3", 1, "sus,"}, n: {"D3", 1, "our"}],
      # 59  Sav-ior.
      [n: {"E3", 2, "Sav-"}, n: {"F3", 2, "ior."}],
      # 60  (solo: the grace of God with)
      [rest: 4],
      # 61  Oh,
      [n: {"C3", 4, "Oh,"}],
      # 62  glo-ry to
      [n: {"C3", 2, "glo-"}, n: {"D3", 1, "ry"}, n: {"D3", 1, "to"}],
      # 63  God in the
      [n: {"E3", 1, "God"}, rest: 1, n: {"E3", 1, "in"}, n: {"E3", 1, "the"}],
      # 64  high-
      [n: {"F3", 2, "high-"}, n: {"A3", 2, "~high-"}],
      # 65  est.
      [n: {"G3", 3, "est."}, rest: 1],
      # 66  Je-sus, our
      [n: {"C3", 2, "Je-"}, n: {"D3", 1, "sus,"}, n: {"D3", 1, "our"}],
      # 67  Sav-ior,
      [n: {"E3", 2, "Sav-"}, n: {"F3", 2, "ior,"}],
      # 68  (solo: the grace of God with)
      [rest: 4],
      # 69  (solo: us.) choir: the
      [rest: 3.5, n: {"C3", 0.5, "the"}],
      # 70  grace of
      [n: {"C3", 3, "grace"}, n: {"E3", 1, "of"}],
      # 71  God with
      [n: {"G3", 2, "God"}, rest: 1, n: {"C4", 1, "with"}],
      # 72  us.
      [n: {"C4", 4, "us."}],
      # 73  (us.)
      [n: {"C4", 4, "~us."}],
      # 74  Ooo
      [rest: 1, n: {"G3", 1, "Ooo"}, n: {"G2", 2, "~Ooo"}],
      # 75  (Ooo) fermata
      [n: {"C3", 4, "~Ooo"}]
    ]
  end

  defp melody_bars do
    [
      # 1  (piano)
      [rest: 4],
      # 2  (piano)
      [rest: 4],
      # 3  solo: Won-der-ful and
      [n: {"C4", 1, "Won-"}, n: {"B3", 1, "der-"}, n: {"D4", 1, "ful"}, n: {"C4", 1, "and"}],
      # 4  solo: wise in coun-sel, for-
      [
        n: {"C4", 1, "wise"},
        n: {"B3", 1, "in"},
        n: {"D4", 1, "coun-"},
        n: {"C4", 0.5, "sel,"},
        rest: 0.25,
        n: {"C4", 0.25, "for-"}
      ],
      # 5  solo: ev-er, Might-y
      [n: {"D4", 1, "ev-"}, n: {"E4", 1, "er,"}, n: {"C4", 1, "Might-"}, n: {"B3", 1, "y"}],
      # 6  solo: God.
      [n: {"A3", 2, "God."}, rest: 2],
      # 7  solo: Pre-cious Fa-ther,   ok: re-read at 300 dpi; solo absent from part tracks, buried in demo
      [n: {"C4", 1, "Pre-"}, n: {"B3", 1, "cious"}, n: {"D4", 1, "Fa-"}, n: {"C4", 1, "ther,"}],
      # 8  solo: ev-er-last-ing,   ok: re-read at 300 dpi; solo absent from part tracks, buried in demo
      [
        n: {"C4", 1, "ev-"},
        n: {"B3", 1, "er-"},
        n: {"D4", 1, "last-"},
        n: {"C4", 0.5, "ing,"},
        rest: 0.5
      ],
      # 9  solo: bless-ed Prince of   ok: re-read at 300 dpi; solo absent from part tracks, buried in demo
      [n: {"D4", 1, "bless-"}, n: {"E4", 1, "ed"}, n: {"C4", 1, "Prince"}, n: {"B3", 1, "of"}],
      # 10  solo: Peace.
      [n: {"A3", 2, "Peace."}, rest: 2],
      # 11  sop: Glo-ry to
      [n: {"G4", 2, "Glo-"}, n: {"F4", 1, "ry"}, n: {"E4", 1, "to"}],
      # 12  sop: God in the
      [n: {"G4", 1, "God"}, rest: 1, n: {"E4", 1, "in"}, n: {"G4", 1, "the"}],
      # 13  sop: high-
      [n: {"A4", 2, "high-"}, n: {"G4", 2, "~high-"}],
      # 14  sop: est.
      [n: {"G4", 3, "est."}, rest: 1],
      # 15  sop: Je-sus, our
      [n: {"G4", 2, "Je-"}, n: {"F4", 1, "sus,"}, n: {"E4", 1, "our"}],
      # 16  sop: Sav-ior, the
      [n: {"G4", 2, "Sav-"}, n: {"C4", 1, "ior,"}, rest: 0.5, n: {"C4", 0.5, "the"}],
      # 17  sop: grace of God with
      [n: {"C4", 1, "grace"}, n: {"E4", 1, "of"}, n: {"D4", 1.5, "God"}, n: {"C4", 0.5, "with"}],
      # 18  sop: us.
      [n: {"C4", 4, "us."}],
      # 19  unison (women): The
      [rest: 3.5, n: {"C4", 0.5, "The"}],
      # 20  unison (women): kings of earth rest
      [n: {"C4", 1, "kings"}, n: {"B3", 1, "of"}, n: {"D4", 1, "earth"}, n: {"C4", 1, "rest"}],
      # 21  unison (women): on Your shoul-ders; You
      [
        n: {"C4", 1, "on"},
        n: {"B3", 1, "Your"},
        n: {"D4", 1, "shoul-"},
        n: {"C4", 0.5, "ders;"},
        rest: 0.25,
        n: {"C4", 0.25, "You"}
      ],
      # 22  unison (women): rule on Da-vid's
      [n: {"D4", 1, "rule"}, n: {"E4", 1, "on"}, n: {"C4", 1, "Da-"}, n: {"B3", 1, "vid's"}],
      # 23  women: throne. / men (8va): Your
      [n: {"A3", 2, "throne."}, rest: 1.5, n: {"C4", 0.5, "Your"}],
      # 24  men (8va): king-dom here is
      [n: {"C4", 1, "king-"}, n: {"B3", 1, "dom"}, n: {"D4", 1, "here"}, n: {"C4", 1, "is"}],
      # 25  men (8va): now es-tab-lished,
      [
        n: {"C4", 1, "now"},
        n: {"B3", 1, "es-"},
        n: {"D4", 1, "tab-"},
        n: {"C4", 0.5, "lished,"},
        rest: 0.5
      ],
      # 26  sop: Christ, our Lord of
      [n: {"D4", 1, "Christ,"}, n: {"E4", 1, "our"}, n: {"C4", 1, "Lord"}, n: {"G4", 1, "of"}],
      # 27  sop: lords.
      [n: {"G4", 3, "lords."}, rest: 1],
      # 28  sop: Glo-ry to   ok: re-read; soprano top note, same tune as bars 11-16
      [n: {"G4", 2, "Glo-"}, n: {"F4", 1, "ry"}, n: {"E4", 1, "to"}],
      # 29  sop: God in the
      [n: {"G4", 1, "God"}, rest: 1, n: {"E4", 1, "in"}, n: {"G4", 1, "the"}],
      # 30  sop: high-   ok: re-read; soprano top note, same tune as bars 11-16
      [n: {"A4", 2, "high-"}, n: {"G4", 2, "~high-"}],
      # 31  sop: est.
      [n: {"G4", 3, "est."}, rest: 1],
      # 32  sop: Je-sus, our
      [n: {"G4", 2, "Je-"}, n: {"F4", 1, "sus,"}, n: {"E4", 1, "our"}],
      # 33  sop: Sav-ior, the   ok: re-read; soprano top note, same tune as bars 11-16
      [n: {"G4", 2, "Sav-"}, n: {"C4", 1, "ior,"}, rest: 0.5, n: {"C4", 0.5, "the"}],
      # 34  sop: grace of God with
      [n: {"C4", 1, "grace"}, n: {"E4", 1, "of"}, n: {"D4", 1.5, "God"}, n: {"C4", 0.5, "with"}],
      # 35  sop: us.
      [n: {"C4", 3, "us."}, rest: 1],
      # 36  solo: Ooo   ? solo wordless line over choir "Ah"; taken as the tune per the solo rule   ok:
      #   re-read; solo staff, not on SATB tracks
      [rest: 2, n: {"G4", 1, "Ooo"}, n: {"C5", 0.5, "~Ooo"}, n: {"B4", 0.5, "~Ooo"}],
      # 37  solo: (Ooo)   ok: re-read; solo staff, not on SATB tracks
      [n: {"A4", 2, "~Ooo"}, n: {"B4", 1, "~Ooo"}, n: {"C5", 1, "~Ooo"}],
      # 38  solo: (Ooo) We
      [n: {"G4", 3, "~Ooo"}, rest: 0.5, n: {"C4", 0.5, "We"}],
      # 39  solo: bow be-fore You, we   ok: re-read; solo staff, not on SATB tracks
      [
        n: {"G4", 0.75, "bow"},
        n: {"G4", 0.25, "be-"},
        n: {"G4", 0.5, "fore"},
        n: {"G4", 0.5, "You,"},
        n: {"G4", 1, "~You,"},
        rest: 0.5,
        n: {"C4", 0.5, "we"}
      ],
      # 40  solo: wor-ship and a-dore You,   ok: re-read; solo staff, not on SATB tracks
      [
        n: {"G4", 0.5, "wor-"},
        n: {"F4", 0.5, "ship"},
        n: {"E4", 0.75, "and"},
        n: {"D4", 0.25, "a-"},
        n: {"D4", 0.5, "dore"},
        n: {"C4", 0.5, "You,"},
        n: {"C4", 1, "~You,"}
      ],
      # 41  solo: stand-ing on Your   ok: re-read; solo staff, not on SATB tracks
      [
        rest: 2,
        n: {"F4", 0.5, "stand-"},
        n: {"E4", 0.25, "ing"},
        n: {"D4", 0.25, "on"},
        n: {"D4", 0.5, "~on"},
        n: {"C4", 0.5, "Your"}
      ],
      # 42  solo: (Your) Word.
      [n: {"C4", 0.5, "~Your"}, n: {"C4", 0.5, "Word."}, n: {"C4", 3, "~Word."}],
      # 43  (piano)
      [rest: 4],
      # 44  solo: Born that we might
      [n: {"C4", 1, "Born"}, n: {"B3", 1, "that"}, n: {"D4", 1, "we"}, n: {"C4", 1, "might"}],
      # 45  solo: know forgiveness   ok: re-read at 400dpi; solo line not on SATB rehearsal tracks
      [
        n: {"C4", 1, "know"},
        n: {"B3", 1, "for-"},
        n: {"D4", 1, "give-"},
        n: {"C4", 0.5, "ness"},
        rest: 0.5
      ],
      # 46  solo: born that we should   ok: re-read at 400dpi; solo line not on SATB rehearsal tracks
      [n: {"D4", 1, "born"}, n: {"E4", 1, "that"}, n: {"C4", 1, "we"}, n: {"B3", 1, "should"}],
      # 47  solo: live. With
      [n: {"A3", 2, "live"}, rest: 1.5, n: {"C4", 0.5, "With"}],
      # 48  solo: joy and hope, and   ok: re-read at 400dpi; solo line not on SATB rehearsal tracks
      [
        n: {"C4", 1, "joy"},
        n: {"B3", 1, "and"},
        n: {"D4", 1, "hope"},
        rest: 0.5,
        n: {"C4", 0.5, "and"}
      ],
      # 49  solo: expectation, our   ok: re-read at 400dpi; solo line not on SATB rehearsal tracks
      [
        n: {"C4", 1, "ex-"},
        n: {"B3", 1, "pec-"},
        n: {"D4", 1, "ta-"},
        n: {"C4", 0.5, "tion"},
        rest: 0.25,
        n: {"C4", 0.25, "our"}
      ],
      # 50  solo: King will come a-   ok: re-read at 400dpi; solo line not on SATB rehearsal tracks
      [n: {"D4", 1, "King"}, n: {"E4", 1, "will"}, n: {"C4", 1, "come"}, n: {"G4", 1, "a-"}],
      # 51  solo: gain. Our   ok: re-read at 400dpi; solo line not on SATB rehearsal tracks
      [n: {"G4", 3, "gain"}, rest: 0.5, n: {"C4", 0.5, "Our"}],
      # 52  solo (choir joins): King will come a-
      [n: {"D4", 1, "King"}, n: {"E4", 1, "will"}, n: {"C4", 1, "come"}, n: {"G4", 1, "a-"}],
      # 53  solo: gain.
      [n: {"G4", 3, "gain"}, rest: 1],
      # 54  solo: Glory to   ok: re-read at 400dpi; solo carries tune, choir tracks sing harmony
      [n: {"G4", 2, "Glo-"}, n: {"F4", 1, "ry"}, n: {"E4", 1, "to"}],
      # 55  solo: God in the
      [n: {"G4", 1, "God"}, rest: 1, n: {"E4", 1, "in"}, n: {"G4", 1, "the"}],
      # 56  solo: high-   ok: re-read at 400dpi; solo carries tune, choir tracks sing harmony
      [n: {"A4", 2, "high-"}, n: {"G4", 2, "~high-"}],
      # 57  solo: est.
      [n: {"G4", 3, "est"}, rest: 1],
      # 58  solo: Jesus, our   ok: re-read at 400dpi; solo carries tune, choir tracks sing harmony
      [n: {"G4", 2, "Je-"}, n: {"F4", 1, "sus"}, n: {"E4", 1, "our"}],
      # 59  solo: Savior, the   ok: re-read at 400dpi; solo carries tune, choir tracks sing harmony
      [n: {"G4", 2, "Sav-"}, n: {"C4", 1, "ior"}, rest: 0.5, n: {"C4", 0.5, "the"}],
      # 60  solo: grace of God with   ok: re-read at 400dpi; solo line not on SATB rehearsal tracks
      [n: {"C4", 1, "grace"}, n: {"E4", 1, "of"}, n: {"D4", 1.5, "God"}, n: {"C4", 0.5, "with"}],
      # 61  solo: us.
      [n: {"C4", 3, "us"}, rest: 1],
      # 62  solo: Glory to
      [n: {"G4", 2, "Glo-"}, n: {"F4", 1, "ry"}, n: {"E4", 1, "to"}],
      # 63  solo: God in the   ? solo divides on beats 3-4; took lower note (matches bar 55)
      [n: {"G4", 1, "God"}, rest: 1, n: {"E4", 1, "in"}, n: {"G4", 1, "the"}],
      # 64  solo: high-   ok: re-read at 400dpi; solo carries tune, choir tracks sing harmony
      [n: {"A4", 2, "high-"}, n: {"G4", 2, "~high-"}],
      # 65  solo: est.
      [n: {"G4", 3, "est"}, rest: 1],
      # 66  solo: Jesus, our
      [n: {"G4", 2, "Je-"}, n: {"F4", 1, "sus"}, n: {"E4", 1, "our"}],
      # 67  solo: Savior, the   ok: re-read at 400dpi; solo carries tune, choir tracks sing harmony
      [n: {"G4", 2, "Sav-"}, n: {"C4", 1, "ior"}, rest: 0.5, n: {"C4", 0.5, "the"}],
      # 68  solo: grace of God with   ok: re-read at 400dpi; solo line not on SATB rehearsal tracks
      [n: {"C4", 1, "grace"}, n: {"E4", 1, "of"}, n: {"D4", 1.5, "God"}, n: {"E4", 0.5, "with"}],
      # 69  solo: us. / choir unison: the   ok: re-read at 400dpi; solo line not on SATB rehearsal tracks
      [n: {"E4", 3, "us"}, rest: 0.5, n: {"C4", 0.5, "the"}],
      # 70  unison: grace of
      [n: {"C4", 3, "grace"}, n: {"E4", 1, "of"}],
      # 71  unison: God with
      [n: {"D4", 2, "God"}, rest: 1, n: {"C4", 1, "with"}],
      # 72  unison: us (tied)
      [n: {"C4", 4, "us"}],
      # 73  unison: (us, tied)
      [n: {"C4", 4, "~us"}],
      # 74  sop: Ooo   ok: 400dpi confirms top voice E4 q + E4 half (lower voice D4~D4, C4)
      [rest: 1, n: {"E4", 1, "Ooo"}, n: {"E4", 2, "~Ooo"}],
      # 75  sop: (Ooo) fermata
      [n: {"E4", 4, "~Ooo"}]
    ]
  end
end
