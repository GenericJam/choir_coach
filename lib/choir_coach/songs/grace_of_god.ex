defmodule ChoirCoach.Songs.GraceOfGod do
  @moduledoc """
  "Grace of God with Us" (Brett Younker, Ben Fielding and Aodhan King, arr. Russell Mauldin), bass part, bars 1–75.

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
  """

  alias ChoirCoach.Song

  @doc "Where bar 1 falls on each track (ms), and which channel holds the voices."
  def tracks do
    %{
      rehearsal: %{
        file: "grace_of_god/bass.mp3",
        bar1_ms: 375.0,
        voice: :left,
        label: "Bass rehearsal"
      },
      split: %{
        file: "grace_of_god/split.mp3",
        bar1_ms: 26_826.0,
        voice: :right,
        label: "Split track"
      },
      demo: %{file: "grace_of_god/demo.mp3", bar1_ms: 39_569.0, voice: :mixed, label: "Demo"}
    }
  end

  @spec bass() :: Song.t()
  def bass do
    Song.build(
      title: "Grace of God with Us",
      part: :bass,
      clef: :bass,
      key: 0,
      tempo_bpm: 73.86,
      beats_per_bar: 4,
      first_bar: 1,
      start_ms: 375.0,
      bar_ms: %{53 => 3_420.0, 69 => 3_800.0, 74 => 4_760.0, 75 => 5_940.0},
      bars: [
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
    )
  end
end
