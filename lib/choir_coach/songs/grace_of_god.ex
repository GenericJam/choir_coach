defmodule ChoirCoach.Songs.GraceOfGod do
  @moduledoc """
  "Grace of God with Us" (Brett Younker, Ben Fielding and Aodhan King, arr. Russell Mauldin), bass,
  melody, soprano, alto and tenor parts, bars 1–75.

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

  The soprano, alto and tenor are the upper and lower voices of the treble
  staff and the upper voice of the bass staff (unison lines go to every part
  that sings them; tacet bars are rests), transcribed bar by bar and checked
  against their own rehearsal tracks with the detector. The flagged notes were
  re-read at 400 dpi: three were misreads (alto bars 38–39, tenor bars 39–40)
  and are fixed; the rest are the bass's low C, F, G and A bleeding into the
  channel (folded up by the detector), scoops, or the late pickups and early
  fermata, each noted on its bar.
  """

  alias ChoirCoach.Song

  @doc "The parts: the four voice parts, top down, then the melody."
  def parts, do: [:soprano, :alto, :tenor, :bass, :melody]

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
      rehearsal: %{
        file: "grace_of_god/soprano.mp3",
        bar1_ms: 375.0,
        voice: :left,
        label: "Soprano rehearsal"
      }
    }
  end

  # Soprano, alto and tenor: the part's rehearsal track, and its piano
  # rendering (`scripts/render_piano.exs`), on the bass track's timeline.
  defp part_tracks(part) when part in [:soprano, :alto, :tenor] do
    name = part |> Atom.to_string() |> String.capitalize()

    %{
      piano: %{
        file: "grace_of_god/piano_#{part}.mp3",
        bar1_ms: 375.0,
        voice: :left,
        label: "Piano"
      },
      rehearsal: %{
        file: "grace_of_god/#{part}.mp3",
        bar1_ms: 375.0,
        voice: :left,
        label: "#{name} rehearsal"
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

  @spec soprano() :: Song.t()
  def soprano, do: Song.build(timing() ++ [part: :soprano, clef: :treble, bars: soprano_bars()])

  @spec alto() :: Song.t()
  def alto, do: Song.build(timing() ++ [part: :alto, clef: :treble, bars: alto_bars()])

  @spec tenor() :: Song.t()
  def tenor, do: Song.build(timing() ++ [part: :tenor, clef: :bass, bars: tenor_bars()])

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

  defp soprano_bars do
    [
      # 1  (piano intro)
      [rest: 4],
      # 2  (piano intro)
      [rest: 4],
      # 3  (intro / solo)
      [rest: 4],
      # 4  (intro / solo)
      [rest: 4],
      # 5  (intro / solo)
      [rest: 4],
      # 6  (intro / solo)
      [rest: 4],
      # 7  (intro / solo)
      [rest: 4],
      # 8  (intro / solo)
      [rest: 4],
      # 9  (intro / solo)
      [rest: 4],
      # 10  (intro / solo)
      [rest: 4],
      # 11  unison (women), as the melody
      [n: {"G4", 2, "Glo-"}, n: {"F4", 1, "ry"}, n: {"E4", 1, "to"}],
      # 12  unison (women), as the melody
      [n: {"G4", 1, "God"}, rest: 1, n: {"E4", 1, "in"}, n: {"G4", 1, "the"}],
      # 13  unison (women), as the melody
      [n: {"A4", 2, "high-"}, n: {"G4", 2, "~high-"}],
      # 14  unison (women), as the melody
      [n: {"G4", 3, "est."}, rest: 1],
      # 15  unison (women), as the melody
      [n: {"G4", 2, "Je-"}, n: {"F4", 1, "sus,"}, n: {"E4", 1, "our"}],
      # 16  unison (women), as the melody
      [n: {"G4", 2, "Sav-"}, n: {"C4", 1, "ior,"}, rest: 0.5, n: {"C4", 0.5, "the"}],
      # 17  unison (women), as the melody
      [n: {"C4", 1, "grace"}, n: {"E4", 1, "of"}, n: {"D4", 1.5, "God"}, n: {"C4", 0.5, "with"}],
      # 18  unison (women), as the melody
      [n: {"C4", 4, "us."}],
      # 19  unison (women), as the melody
      [rest: 3.5, n: {"C4", 0.5, "The"}],
      # 20  unison (women), as the melody
      [n: {"C4", 1, "kings"}, n: {"B3", 1, "of"}, n: {"D4", 1, "earth"}, n: {"C4", 1, "rest"}],
      # 21  unison (women), as the melody
      [
        n: {"C4", 1, "on"},
        n: {"B3", 1, "Your"},
        n: {"D4", 1, "shoul-"},
        n: {"C4", 0.5, "ders;"},
        rest: 0.25,
        n: {"C4", 0.25, "You"}
      ],
      # 22  unison (women), as the melody
      [n: {"D4", 1, "rule"}, n: {"E4", 1, "on"}, n: {"C4", 1, "Da-"}, n: {"B3", 1, "vid's"}],
      # 23  (WOMEN) throne.
      [n: {"A3", 2, "throne."}, rest: 2],
      # 24  (MEN)
      [rest: 4],
      # 25  (MEN)
      [rest: 4],
      # 26  (CHOIR unison) Christ, our Lord of
      [n: {"D4", 1, "Christ,"}, n: {"E4", 1, "our"}, n: {"C4", 1, "Lord"}, n: {"G4", 1, "of"}],
      # 27  lords.
      [n: {"G4", 3, "lords."}, rest: 1],
      # 28  Glo-ry to  (G4 F4 E4)  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note
      #   heard under it
      [n: {"G4", 2, "Glo-"}, n: {"F4", 1, "ry"}, n: {"E4", 1, "to"}],
      # 29  God in the  (G4 E4 G4)  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note
      #   heard under it
      [n: {"G4", 1, "God"}, rest: 1, n: {"E4", 1, "in"}, n: {"G4", 1, "the"}],
      # 30  high-  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note heard under it
      [n: {"A4", 2, "high-"}, n: {"G4", 2, "~high-"}],
      # 31  est.
      [n: {"G4", 3, "est."}, rest: 1],
      # 32  Je-sus, our  (G4 F4 E4)  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note
      #   heard under it
      [n: {"G4", 2, "Je-"}, n: {"F4", 1, "sus,"}, n: {"E4", 1, "our"}],
      # 33  Sav-ior, the  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note heard under
      #   it; "the" B3 is a scoop
      [n: {"G4", 2, "Sav-"}, n: {"C4", 1, "ior,"}, rest: 0.5, n: {"C4", 0.5, "the"}],
      # 34  grace of God with
      [n: {"C4", 1, "grace"}, n: {"E4", 1, "of"}, n: {"D4", 1.5, "God"}, n: {"C4", 0.5, "with"}],
      # 35  us.
      [n: {"C4", 3, "us."}, rest: 1],
      # 36  Ah  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note heard under it
      [n: {"G4", 4, "Ah"}],
      # 37  (Ah)  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note heard under it
      [n: {"A4", 2, "~Ah"}, n: {"G4", 2, "~Ah"}],
      # 38  (Ah)
      [n: {"G4", 4, "~Ah"}],
      # 39  Ooo  ok: track A#4 is A#2 bleed folded; E4 then F4 heard
      [rest: 1, n: {"E4", 1, "Ooo"}, n: {"F4", 2, "~Ooo"}],
      # 40  (Ooo)  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note heard under it
      [n: {"G4", 1, "~Ooo"}, n: {"B4", 1, "~Ooo"}, n: {"A4", 2, "~Ooo"}],
      # 41  Ooo  ok: track C4 is bass C2 bleed; E4 then D4 heard
      [rest: 1, n: {"E4", 1, "Ooo"}, n: {"D4", 2, "~Ooo"}],
      # 42  (Ooo)  ok: track F4 is F2 bleed; C4 heard
      [n: {"C4", 4, "~Ooo"}],
      # 43  (piano / solo)
      [rest: 4],
      # 44  (piano / solo)
      [rest: 4],
      # 45  (piano / solo)
      [rest: 4],
      # 46  (piano / solo)
      [rest: 4],
      # 47  (piano / solo)
      [rest: 4],
      # 48  (piano / solo)
      [rest: 4],
      # 49  (piano / solo)
      [rest: 4],
      # 50  (piano / solo)
      [rest: 4],
      # 51  (solo) choir: Our  ok: "Our" flagged D4: pickup sung late into the D4 (drift)
      [rest: 3.5, n: {"C4", 0.5, "Our"}],
      # 52  King will come a-
      [n: {"D4", 1, "King"}, n: {"E4", 1, "will"}, n: {"C4", 1, "come"}, n: {"G4", 1, "a-"}],
      # 53  gain.
      [n: {"G4", 3, "gain."}, rest: 1],
      # 54  Glo-ry to  (G4 F4 E4)  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note
      #   heard under it
      [n: {"G4", 2, "Glo-"}, n: {"F4", 1, "ry"}, n: {"E4", 1, "to"}],
      # 55  God in the  (G4 E4 G4)  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note
      #   heard under it
      [n: {"G4", 1, "God"}, rest: 1, n: {"E4", 1, "in"}, n: {"G4", 1, "the"}],
      # 56  high-  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note heard under it
      [n: {"A4", 2, "high-"}, n: {"G4", 2, "~high-"}],
      # 57  est.  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note heard under it
      [n: {"G4", 3, "est."}, rest: 1],
      # 58  Je-sus, our  (G4 F4 E4)  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note
      #   heard under it
      [n: {"G4", 2, "Je-"}, n: {"F4", 1, "sus,"}, n: {"E4", 1, "our"}],
      # 59  Sav-ior.  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note heard under it
      [n: {"G4", 2, "Sav-"}, n: {"C4", 2, "ior."}],
      # 60  (solo)
      [rest: 4],
      # 61  Oh,  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note heard under it
      [n: {"E4", 1, "Oh,"}, n: {"F4", 1, "~Oh,"}, n: {"G4", 1, "~Oh,"}, n: {"A4", 1, "~Oh,"}],
      # 62  glo-ry to  (C5 A4 G4)
      [n: {"C5", 2, "glo-"}, n: {"A4", 1, "ry"}, n: {"G4", 1, "to"}],
      # 63  God in the  (C5 C5 B4)
      [n: {"C5", 1, "God"}, rest: 1, n: {"C5", 1, "in"}, n: {"B4", 1, "the"}],
      # 64  high-  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note heard under it
      [n: {"A4", 2, "high-"}, n: {"G4", 2, "~high-"}],
      # 65  est.
      [n: {"G4", 3, "est."}, rest: 1],
      # 66  Je-sus, our  (G4 F4 E4)
      [n: {"G4", 2, "Je-"}, n: {"F4", 1, "sus,"}, n: {"E4", 1, "our"}],
      # 67  Sav-ior,  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note heard under it
      [n: {"G4", 2, "Sav-"}, n: {"C4", 2, "ior,"}],
      # 68  (solo)
      [rest: 4],
      # 69  unison
      [rest: 3.5, n: {"C4", 0.5, "the"}],
      # 70  unison
      [n: {"C4", 3, "grace"}, n: {"E4", 1, "of"}],
      # 71  unison
      [n: {"D4", 2, "God"}, rest: 1, n: {"C4", 1, "with"}],
      # 72  unison
      [n: {"C4", 4, "us."}],
      # 73  unison
      [n: {"C4", 4, "~us."}],
      # 74  Ooo  ? upper voice E4 then D4 half
      [rest: 1, n: {"E4", 1, "Ooo"}, n: {"D4", 2, "~Ooo"}],
      # 75  (Ooo) fermata
      [n: {"C4", 4, "~Ooo"}]
    ]
  end

  defp alto_bars do
    [
      # 1  (piano intro)
      [rest: 4],
      # 2  (piano intro)
      [rest: 4],
      # 3  (intro / solo)
      [rest: 4],
      # 4  (intro / solo)
      [rest: 4],
      # 5  (intro / solo)
      [rest: 4],
      # 6  (intro / solo)
      [rest: 4],
      # 7  (intro / solo)
      [rest: 4],
      # 8  (intro / solo)
      [rest: 4],
      # 9  (intro / solo)
      [rest: 4],
      # 10  (intro / solo)
      [rest: 4],
      # 11  unison (women), as the melody
      [n: {"G4", 2, "Glo-"}, n: {"F4", 1, "ry"}, n: {"E4", 1, "to"}],
      # 12  unison (women), as the melody
      [n: {"G4", 1, "God"}, rest: 1, n: {"E4", 1, "in"}, n: {"G4", 1, "the"}],
      # 13  unison (women), as the melody
      [n: {"A4", 2, "high-"}, n: {"G4", 2, "~high-"}],
      # 14  unison (women), as the melody
      [n: {"G4", 3, "est."}, rest: 1],
      # 15  unison (women), as the melody
      [n: {"G4", 2, "Je-"}, n: {"F4", 1, "sus,"}, n: {"E4", 1, "our"}],
      # 16  unison (women), as the melody
      [n: {"G4", 2, "Sav-"}, n: {"C4", 1, "ior,"}, rest: 0.5, n: {"C4", 0.5, "the"}],
      # 17  unison (women), as the melody
      [n: {"C4", 1, "grace"}, n: {"E4", 1, "of"}, n: {"D4", 1.5, "God"}, n: {"C4", 0.5, "with"}],
      # 18  unison (women), as the melody
      [n: {"C4", 4, "us."}],
      # 19  unison (women), as the melody
      [rest: 3.5, n: {"C4", 0.5, "The"}],
      # 20  unison (women), as the melody
      [n: {"C4", 1, "kings"}, n: {"B3", 1, "of"}, n: {"D4", 1, "earth"}, n: {"C4", 1, "rest"}],
      # 21  unison (women), as the melody
      [
        n: {"C4", 1, "on"},
        n: {"B3", 1, "Your"},
        n: {"D4", 1, "shoul-"},
        n: {"C4", 0.5, "ders;"},
        rest: 0.25,
        n: {"C4", 0.25, "You"}
      ],
      # 22  unison (women), as the melody
      [n: {"D4", 1, "rule"}, n: {"E4", 1, "on"}, n: {"C4", 1, "Da-"}, n: {"B3", 1, "vid's"}],
      # 23  (WOMEN) throne.
      [n: {"A3", 2, "throne."}, rest: 2],
      # 24  (MEN)
      [rest: 4],
      # 25  (MEN)
      [rest: 4],
      # 26  (CHOIR unison) Christ, our Lord of
      [n: {"D4", 1, "Christ,"}, n: {"E4", 1, "our"}, n: {"C4", 1, "Lord"}, n: {"G4", 1, "of"}],
      # 27  lords.
      [n: {"G4", 3, "lords."}, rest: 1],
      # 28  Glo-ry to  (E4 D4 C4)
      [n: {"E4", 2, "Glo-"}, n: {"D4", 1, "ry"}, n: {"C4", 1, "to"}],
      # 29  God in the  (E4 C4 E4)  ok: C#4 is 0.6 st sharp, a scoop
      [n: {"E4", 1, "God"}, rest: 1, n: {"C4", 1, "in"}, n: {"E4", 1, "the"}],
      # 30  high-  ok: track A4 is the bass A2 bleed; F4 then E4 heard
      [n: {"F4", 2, "high-"}, n: {"E4", 2, "~high-"}],
      # 31  est.  ok: no alto readings under the bass; D4 as bars 57/65
      [n: {"D4", 3, "est."}, rest: 1],
      # 32  Je-sus, our  (E4 D4 C4)
      [n: {"E4", 2, "Je-"}, n: {"D4", 1, "sus,"}, n: {"C4", 1, "our"}],
      # 33  Sav-ior, the  ok: flags are timing (C4 heard on the next beat) and an A3 scoop
      [n: {"E4", 2, "Sav-"}, n: {"C4", 1, "ior,"}, rest: 0.5, n: {"C4", 0.5, "the"}],
      # 34  grace of God with  (unison C4, then the lower notes)
      [n: {"C4", 1, "grace"}, n: {"C4", 1, "of"}, n: {"B3", 1.5, "God"}, n: {"C4", 0.5, "with"}],
      # 35  us.
      [n: {"C4", 3, "us."}, rest: 1],
      # 36  Ah
      [n: {"E4", 4, "Ah"}],
      # 37  (Ah)
      [n: {"F4", 2, "~Ah"}, n: {"E4", 2, "~Ah"}],
      # 38  (Ah)  ok: 400 dpi lower note sits below the staff (D4); track hears D4  ok: first half the G2 bleed, D4
      #   heard from beat 3
      [n: {"D4", 4, "~Ah"}],
      # 39  Ooo  (C4 tied)  ok: 400 dpi the arc is a tie on C4 (the soprano slurs E4-F4); track holds C4
      [rest: 1, n: {"C4", 1, "Ooo"}, n: {"C4", 2, "~Ooo"}],
      # 40  (Ooo)
      [n: {"E4", 1, "~Ooo"}, n: {"G4", 1, "~Ooo"}, n: {"F4", 2, "~Ooo"}],
      # 41  Ooo
      [rest: 1, n: {"C4", 1, "Ooo"}, n: {"B3", 2, "~Ooo"}],
      # 42  (Ooo)
      [n: {"G3", 4, "~Ooo"}],
      # 43  (piano / solo)
      [rest: 4],
      # 44  (piano / solo)
      [rest: 4],
      # 45  (piano / solo)
      [rest: 4],
      # 46  (piano / solo)
      [rest: 4],
      # 47  (piano / solo)
      [rest: 4],
      # 48  (piano / solo)
      [rest: 4],
      # 49  (piano / solo)
      [rest: 4],
      # 50  (piano / solo)
      [rest: 4],
      # 51  (solo) choir: Our  ok: "Our" sung late into D4 (drift)
      [rest: 3.5, n: {"C4", 0.5, "Our"}],
      # 52  King will come a-  ok: "a-" D4 under G2 bleed, D4 heard
      [n: {"D4", 1, "King"}, n: {"E4", 1, "will"}, n: {"C4", 1, "come"}, n: {"D4", 1, "a-"}],
      # 53  gain.
      [n: {"C4", 3, "gain."}, rest: 1],
      # 54  Glo-ry to  (E4 D4 C4)
      [n: {"E4", 2, "Glo-"}, n: {"D4", 1, "ry"}, n: {"C4", 1, "to"}],
      # 55  God in the  (E4 C4 E4)
      [n: {"E4", 1, "God"}, rest: 1, n: {"C4", 1, "in"}, n: {"E4", 1, "the"}],
      # 56  high-
      [n: {"F4", 2, "high-"}, n: {"E4", 2, "~high-"}],
      # 57  est.
      [n: {"D4", 3, "est."}, rest: 1],
      # 58  Je-sus, our  (E4 D4 C4)
      [n: {"E4", 2, "Je-"}, n: {"D4", 1, "sus,"}, n: {"C4", 1, "our"}],
      # 59  Sav-ior.
      [n: {"E4", 2, "Sav-"}, n: {"C4", 2, "ior."}],
      # 60  (solo)
      [rest: 4],
      # 61  Oh,
      [n: {"C4", 1, "Oh,"}, n: {"D4", 1, "~Oh,"}, n: {"E4", 1, "~Oh,"}, n: {"F4", 1, "~Oh,"}],
      # 62  glo-ry to  (G4 F4 E4)
      [n: {"G4", 2, "glo-"}, n: {"F4", 1, "ry"}, n: {"E4", 1, "to"}],
      # 63  God in the  (G4 G4 G4)  ok: track C5 is the bass C bleed
      [n: {"G4", 1, "God"}, rest: 1, n: {"G4", 1, "in"}, n: {"G4", 1, "the"}],
      # 64  high-  ok: track A4 is the bass A2 bleed
      [n: {"F4", 2, "high-"}, n: {"E4", 2, "~high-"}],
      # 65  est.
      [n: {"D4", 3, "est."}, rest: 1],
      # 66  Je-sus, our  (E4 D4 C4)
      [n: {"E4", 2, "Je-"}, n: {"D4", 1, "sus,"}, n: {"C4", 1, "our"}],
      # 67  Sav-ior,  ok: track C4 is C2 bleed; E4 heard (folded E3)
      [n: {"E4", 2, "Sav-"}, n: {"C4", 2, "ior,"}],
      # 68  (solo)
      [rest: 4],
      # 69  unison
      [rest: 3.5, n: {"C4", 0.5, "the"}],
      # 70  unison
      [n: {"C4", 3, "grace"}, n: {"E4", 1, "of"}],
      # 71  unison
      [n: {"D4", 2, "God"}, rest: 1, n: {"C4", 1, "with"}],
      # 72  unison
      [n: {"C4", 4, "us."}],
      # 73  unison
      [n: {"C4", 4, "~us."}],
      # 74  Ooo  ? lower voice C4~C4, B3  ok: track runs ~0.5 s early here (rit.); B3 lands as C4 holds
      [rest: 1, n: {"C4", 1, "Ooo"}, n: {"C4", 1, "~Ooo"}, n: {"B3", 1, "~Ooo"}],
      # 75  (Ooo) fermata
      [n: {"G3", 4, "~Ooo"}]
    ]
  end

  defp tenor_bars do
    [
      # 1  (piano intro)
      [rest: 4],
      # 2  (piano intro)
      [rest: 4],
      # 3  (intro / solo)
      [rest: 4],
      # 4  (intro / solo)
      [rest: 4],
      # 5  (intro / solo)
      [rest: 4],
      # 6  (intro / solo)
      [rest: 4],
      # 7  (intro / solo)
      [rest: 4],
      # 8  (intro / solo)
      [rest: 4],
      # 9  (intro / solo)
      [rest: 4],
      # 10  (intro / solo)
      [rest: 4],
      # 11  unison (men), as the bass
      [n: {"G3", 2, "Glo-"}, n: {"F3", 1, "ry"}, n: {"E3", 1, "to"}],
      # 12  unison (men), as the bass
      [n: {"G3", 1, "God"}, rest: 1, n: {"E3", 1, "in"}, n: {"G3", 1, "the"}],
      # 13  unison (men), as the bass
      [n: {"A3", 2, "high-"}, n: {"G3", 2, "~high-"}],
      # 14  unison (men), as the bass
      [n: {"G3", 3, "est."}, rest: 1],
      # 15  unison (men), as the bass
      [n: {"G3", 2, "Je-"}, n: {"F3", 1, "sus,"}, n: {"E3", 1, "our"}],
      # 16  unison (men), as the bass
      [n: {"G3", 2, "Sav-"}, n: {"C3", 1, "ior,"}, rest: 0.5, n: {"C3", 0.5, "the"}],
      # 17  unison (men), as the bass
      [
        n: {"C3", 1, "grace"},
        n: {"E3", 1, "of"},
        n: {"D3", 1.5, "God"},
        n: {"C3", 0.5, "with"}
      ],
      # 18  unison (men), as the bass
      [n: {"C3", 4, "us."}],
      # 19  (WOMEN)
      [rest: 4],
      # 20  (WOMEN)
      [rest: 4],
      # 21  (WOMEN)
      [rest: 4],
      # 22  (WOMEN)
      [rest: 4],
      # 23  unison with the bass
      [rest: 3.5, n: {"C3", 0.5, "Your"}],
      # 24  unison with the bass
      [n: {"C3", 1, "king-"}, n: {"B2", 1, "dom"}, n: {"D3", 1, "here"}, n: {"C3", 1, "is"}],
      # 25  unison with the bass
      [
        n: {"C3", 1, "now"},
        n: {"B2", 1, "es-"},
        n: {"D3", 1, "tab-"},
        n: {"C3", 0.5, "lished,"},
        rest: 0.5
      ],
      # 26  unison with the bass
      [n: {"D3", 1, "Christ,"}, n: {"E3", 1, "our"}, n: {"C3", 1, "Lord"}, n: {"G3", 1, "of"}],
      # 27  unison with the bass
      [n: {"G3", 3, "lords."}, rest: 1],
      # 28  Glo-ry to  (C4 A3 G3)  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note
      #   heard under it; A#3 a sharp A3
      [n: {"C4", 2, "Glo-"}, n: {"A3", 1, "ry"}, n: {"G3", 1, "to"}],
      # 29  God in the  (C4 G3 C4)  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note
      #   heard under it
      [n: {"C4", 1, "God"}, rest: 1, n: {"G3", 1, "in"}, n: {"C4", 1, "the"}],
      # 30  high-
      [n: {"C4", 4, "high-"}],
      # 31  est.
      [n: {"C4", 2, "est."}, n: {"B3", 1, "~est."}, rest: 1],
      # 32  Je-sus, our  (C4 A3 G3)  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note
      #   heard under it
      [n: {"C4", 2, "Je-"}, n: {"A3", 1, "sus,"}, n: {"G3", 1, "our"}],
      # 33  Sav-ior, the
      [n: {"C4", 2, "Sav-"}, n: {"A3", 1, "ior,"}, rest: 0.5, n: {"A3", 0.5, "the"}],
      # 34  grace of God with  (unison with the bass)  ok: track flags are the men's C (C2/C3) bleeding in, folded
      #   up; written note heard under it
      [
        n: {"G3", 1, "grace"},
        n: {"G3", 1, "of"},
        n: {"G3", 1.5, "God"},
        n: {"C4", 0.5, "with"}
      ],
      # 35  us.
      [n: {"C4", 3, "us."}, rest: 1],
      # 36  Ah
      [n: {"C4", 2, "Ah"}, n: {"D4", 1, "~Ah"}, n: {"C4", 1, "~Ah"}],
      # 37  (Ah)
      [n: {"C4", 4, "~Ah"}],
      # 38  (Ah)
      [n: {"C4", 2, "~Ah"}, n: {"B3", 2, "~Ah"}],
      # 39  Ooo  (G3 A3)  ok: re-read at 400 dpi, upper notes of the chords over the bass's C3 D3; track agrees  ok:
      #   G3 under the bass C2 bleed
      [rest: 1, n: {"G3", 1, "Ooo"}, n: {"A3", 2, "~Ooo"}],
      # 40  (Ooo)  (C4 tied)  ok: re-read at 400 dpi (ledger C4 over the bass's E3 F3); track hears C4  ok: track F4
      #   is the bass F2 bleed; C4 heard
      [n: {"C4", 4, "~Ooo"}],
      # 41  Ooo
      [rest: 1, n: {"G3", 3, "Ooo"}],
      # 42  (Ooo)
      [n: {"E3", 4, "~Ooo"}],
      # 43  (piano / solo)
      [rest: 4],
      # 44  (piano / solo)
      [rest: 4],
      # 45  (piano / solo)
      [rest: 4],
      # 46  (piano / solo)
      [rest: 4],
      # 47  (piano / solo)
      [rest: 4],
      # 48  (piano / solo)
      [rest: 4],
      # 49  (piano / solo)
      [rest: 4],
      # 50  (piano / solo)
      [rest: 4],
      # 51  (solo) choir: Our  ok: "Our" sung late into D3 (drift)
      [rest: 3.5, n: {"C3", 0.5, "Our"}],
      # 52  King will come a-
      [n: {"D3", 1, "King"}, n: {"E3", 1, "will"}, n: {"G3", 1, "come"}, n: {"B3", 1, "a-"}],
      # 53  gain.
      [n: {"A3", 3, "gain."}, rest: 1],
      # 54  Glo-ry to  (C4 A3 G3)  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note
      #   heard under it; A#3 a sharp A3
      [n: {"C4", 2, "Glo-"}, n: {"A3", 1, "ry"}, n: {"G3", 1, "to"}],
      # 55  God in the  (C4 G3 C4)  ok: track flags are the men's C (C2/C3) bleeding in, folded up; written note
      #   heard under it
      [n: {"C4", 1, "God"}, rest: 1, n: {"G3", 1, "in"}, n: {"C4", 1, "the"}],
      # 56  high-
      [n: {"C4", 4, "high-"}],
      # 57  est.
      [n: {"C4", 2, "est."}, n: {"B3", 1, "~est."}, rest: 1],
      # 58  Je-sus, our  (C4 A3 G3)
      [n: {"C4", 2, "Je-"}, n: {"A3", 1, "sus,"}, n: {"G3", 1, "our"}],
      # 59  Sav-ior.
      [n: {"C4", 2, "Sav-"}, n: {"A3", 2, "ior."}],
      # 60  (solo)
      [rest: 4],
      # 61  Oh,
      [n: {"G3", 1, "Oh,"}, n: {"A3", 1, "~Oh,"}, n: {"C4", 1, "~Oh,"}, n: {"D4", 1, "~Oh,"}],
      # 62  glo-ry to  (E4 D4 C4)
      [n: {"E4", 2, "glo-"}, n: {"D4", 1, "ry"}, n: {"C4", 1, "to"}],
      # 63  God in the  (E4 E4 D4)  ok: E4 heard; beats 3-4 weak (G2 bleed), D4 present
      [n: {"E4", 1, "God"}, rest: 1, n: {"E4", 1, "in"}, n: {"D4", 1, "the"}],
      # 64  high-
      [n: {"C4", 4, "high-"}],
      # 65  est.  ok: B3 0.8 st sharp, late
      [n: {"C4", 2, "est."}, n: {"B3", 1, "~est."}, rest: 1],
      # 66  Je-sus, our  (C4 A3 G3)  ok: few readings; "our" G3 weak under the bass
      [n: {"C4", 2, "Je-"}, n: {"A3", 1, "sus,"}, n: {"G3", 1, "our"}],
      # 67  Sav-ior,
      [n: {"C4", 2, "Sav-"}, n: {"A3", 2, "ior,"}],
      # 68  (solo)
      [rest: 4],
      # 69  unison with the bass
      [rest: 3.5, n: {"C3", 0.5, "the"}],
      # 70  unison with the bass
      [n: {"C3", 3, "grace"}, n: {"E3", 1, "of"}],
      # 71  unison with the bass
      [n: {"G3", 2, "God"}, rest: 1, n: {"C4", 1, "with"}],
      # 72  unison with the bass
      [n: {"C4", 4, "us."}],
      # 73  unison with the bass
      [n: {"C4", 4, "~us."}],
      # 74  Ooo  (bass staff upper voice: G3~G3 dotted, F3 eighth)  ok: track runs ~0.5 s early; G3 then F3 to E3 heard
      [rest: 1, n: {"G3", 1, "Ooo"}, n: {"G3", 1.5, "~Ooo"}, n: {"F3", 0.5, "~Ooo"}],
      # 75  (Ooo) fermata
      [n: {"E3", 4, "~Ooo"}]
    ]
  end
end
