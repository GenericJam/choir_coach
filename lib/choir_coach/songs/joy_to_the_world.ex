defmodule ChoirCoach.Songs.JoyToTheWorld do
  @moduledoc """
  "The Joy / Joy to the World" (Mitch Wong, Austin Davis, Isaac Watts and
  George Frideric Handel, arr. Travis Cottrell and Mason Brown), all four
  voice parts and the melody, bars 1–160.

  A congregational song: everyone sings the melody, so the practice screen
  opens on it, with the singer's own part to switch to. There are no part
  rehearsal tracks, only the split track (accompaniment left, all voices
  right) and the finished mix, so every part's pitch check was against all
  voices together: each note the detector heard off the written pitch was
  re-read at 400 dpi (most are another voice, or the choir's scoop on the
  tied quavers of the first bridge).

  Timing is the split track's, fitted with `scripts/align_track.exs`: bar 1
  starts 1.9 s in, ♩ = 132; the rit. in bar 159 and the final fermata come
  from the accompaniment's onsets (no voice sings from bar 153). The demo
  shares the split's timeline exactly.

  The melody is the tune wherever a voice sings it: the women's unison line
  in the verses and the first bridge, the soprano in verse 2, the tenor in
  the choruses and tag (marked "mel." from bar 54) and in the second bridge
  (bridge 1's tune note for note under the women's harmony), the solo in
  bars 154–157. The tenor's tune stays at its pitch (C4–F4, the pitch the
  women and the solo sing it at). Soprano and alto are the upper and lower
  voices of the treble staff, tenor and bass of the bass staff, the unison
  line where a staff prints one.
  """

  alias ChoirCoach.Song

  @doc "The parts: the four voice parts, top down, then the melody."
  def parts, do: [:soprano, :alto, :tenor, :bass, :melody]

  @doc "Everyone sings the melody: it is the part the practice screen opens on."
  def congregational?, do: true

  @doc """
  Each part's recordings: where bar 1 falls on each (ms), and which channel
  holds the voices. There are no part rehearsal tracks: the split track
  (accompaniment left, all voices right) serves every part, beside the
  part's piano rendering.
  """
  def tracks(part) do
    split = %{
      file: "joy_to_the_world/split.mp3",
      bar1_ms: 1_900.0,
      voice: :right,
      label: "Split track"
    }

    %{
      split: split,
      demo: %{file: "joy_to_the_world/demo.mp3", bar1_ms: 1_900.0, voice: :mixed, label: "Demo"},
      rehearsal: Map.merge(split, %{label: "Choir", detail: "All voices together"}),
      piano: %{
        file: "joy_to_the_world/piano_#{part}.mp3",
        bar1_ms: 1_900.0,
        voice: :left,
        label: "Piano"
      }
    }
  end

  # Every part shares the bar timeline (and so every track's offsets).
  defp timing do
    [
      title: "The Joy / Joy to the World",
      key: 0,
      tempo_bpm: 132.0,
      beats_per_bar: 4,
      first_bar: 1,
      start_ms: 1_900.0,
      bar_ms: %{159 => 1_990.0, 160 => 3_640.0}
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
      # 1  (piano)
      [rest: 4],
      # 2  (piano)
      [rest: 4],
      # 3  (piano)
      [rest: 4],
      # 4  (piano)
      [rest: 4],
      # 5  (piano)
      [rest: 4],
      # 6  (piano)
      [rest: 4],
      # 7  (piano)
      [rest: 4],
      # 8  (piano)
      [rest: 4],
      # 9  (piano)
      [rest: 4],
      # 10  (piano)
      [rest: 4],
      # 11  (piano)
      [rest: 4],
      # 12  (piano)
      [rest: 4],
      # 13  Joy to the
      [n: {"C4", 2, "Joy"}, n: {"B3", 1.5, "to"}, n: {"A3", 0.5, "the"}],
      # 14  world, the
      [n: {"G3", 2, "world,"}, rest: 1, n: {"F3", 1, "the"}],
      # 15  Lord is
      [n: {"E3", 2, "Lord"}, n: {"D3", 2, "is"}],
      # 16  come, let
      [n: {"C3", 2, "come,"}, rest: 1, n: {"G3", 1, "let"}],
      # 17  earth re-
      [n: {"A3", 2, "earth"}, rest: 1, n: {"A3", 1, "re-"}],
      # 18  ceive her
      [n: {"B3", 3, "ceive"}, n: {"B3", 1, "her"}],
      # 19  King.
      [n: {"C4", 4, "King."}],
      # 20  Let
      [rest: 3, n: {"C4", 1, "Let"}],
      # 21  ev-'ry
      [n: {"C4", 1, "ev-"}, n: {"B3", 1, "~ev-"}, n: {"A3", 1, "'ry"}, n: {"G3", 1, "~'ry"}],
      # 22  heart pre-
      [
        n: {"G3", 1.5, "heart"},
        n: {"F3", 0.5, "~heart"},
        n: {"E3", 0.5, "~heart"},
        rest: 0.5,
        n: {"C4", 1, "pre-"}
      ],
      # 23  pare Him
      [n: {"C4", 1, "pare"}, n: {"B3", 1, "~pare"}, n: {"A3", 1, "Him"}, n: {"G3", 1, "~Him"}],
      # 24  room, and
      [
        n: {"G3", 1.5, "room,"},
        n: {"F3", 0.5, "~room,"},
        n: {"E3", 0.5, "~room,"},
        rest: 0.5,
        n: {"E3", 1, "and"}
      ],
      # 25  Heav-en and na-ture
      [
        n: {"E3", 0.5, "Heav-"},
        n: {"E3", 0.5, "en"},
        n: {"E3", 1, "and"},
        n: {"E3", 1, "na-"},
        n: {"F3", 1, "ture"}
      ],
      # 26  sing, and
      [n: {"G3", 2, "sing,"}, rest: 1, n: {"F3", 0.5, "and"}, n: {"E3", 0.5, "~and"}],
      # 27  Heav-en and na-ture
      [
        n: {"D3", 0.5, "Heav-"},
        n: {"D3", 0.5, "en"},
        n: {"D3", 1, "and"},
        n: {"D3", 1, "na-"},
        n: {"E3", 1, "ture"}
      ],
      # 28  sing, and
      [n: {"F3", 2, "sing,"}, rest: 1, n: {"E3", 0.5, "and"}, n: {"D3", 0.5, "~and"}],
      # 29  Heav-en and
      [n: {"C3", 1, "Heav-"}, n: {"C4", 2, "en"}, n: {"A3", 1, "and"}],
      # 30  Heav-en and
      [
        n: {"G3", 1.5, "Heav-"},
        n: {"F3", 0.5, "~Heav-"},
        n: {"E3", 1, "en"},
        n: {"F3", 1, "and"}
      ],
      # 31  na-ture
      [n: {"E3", 2, "na-"}, n: {"D3", 2, "ture"}],
      # 32  sing.
      [n: {"C3", 4, "sing."}],
      # 33  (piano)
      [rest: 4],
      # 34  (piano)
      [rest: 4],
      # 35  (piano)
      [rest: 4],
      # 36  Joy to the
      [n: {"C3", 2, "Joy"}, n: {"C3", 1.5, "to"}, n: {"C3", 0.5, "the"}],
      # 37  Earth, the
      [n: {"C3", 2, "Earth,"}, rest: 1, n: {"C3", 1, "the"}],
      # 38  Sav-ior
      [n: {"C3", 2, "Sav-"}, n: {"C3", 2, "ior"}],
      # 39  reigns, let
      [n: {"C3", 2, "reigns,"}, rest: 1, n: {"C3", 1, "let"}],
      # 40  all, their
      [n: {"F3", 2, "all,"}, rest: 1, n: {"F3", 1, "their"}],
      # 41  songs em-
      [n: {"G3", 3, "songs"}, n: {"G3", 1, "em-"}],
      # 42  ploy,
      [n: {"C3", 4, "ploy,"}],
      # 43  while
      [rest: 3, n: {"C4", 1, "while"}],
      # 44  fields and
      [
        n: {"C4", 1, "fields"},
        n: {"B3", 1, "~fields"},
        n: {"A3", 1, "and"},
        n: {"G3", 1, "~and"}
      ],
      # 45  floods, rocks,
      [
        n: {"G3", 1.5, "floods,"},
        n: {"F3", 0.5, "~floods,"},
        n: {"E3", 0.5, "~floods,"},
        rest: 0.5,
        n: {"C4", 1, "rocks,"}
      ],
      # 46  hills and
      [n: {"C4", 1, "hills"}, n: {"B3", 1, "~hills"}, n: {"A3", 1, "and"}, n: {"G3", 1, "~and"}],
      # 47  plains re-
      [
        n: {"G3", 1.5, "plains"},
        n: {"F3", 0.5, "~plains"},
        n: {"E3", 0.5, "~plains"},
        rest: 0.5,
        n: {"C3", 1, "re-"}
      ],
      # 48  peat the sound-ing
      [n: {"C3", 1, "peat"}, n: {"C3", 1, "the"}, n: {"C3", 1, "sound-"}, n: {"C3", 1, "ing"}],
      # 49  joy, re-
      [n: {"C3", 2, "joy,"}, rest: 1, n: {"C3", 1, "re-"}],
      # 50  peat the sound-ing
      [n: {"G3", 1, "peat"}, n: {"G3", 1, "the"}, n: {"G3", 1, "sound-"}, n: {"G3", 1, "ing"}],
      # 51  joy, re-
      [n: {"G3", 2, "joy,"}, rest: 1, n: {"E3", 0.5, "re-"}, n: {"D3", 0.5, "~re-"}],
      # 52  peat, re-
      [n: {"C3", 1, "peat,"}, n: {"C4", 2, "~peat,"}, n: {"A3", 1, "re-"}],
      # 53  peat, the
      [
        n: {"G3", 1.5, "peat,"},
        n: {"F3", 0.5, "~peat,"},
        n: {"E3", 1, "~peat,"},
        n: {"F3", 1, "the"}
      ],
      # 54  sound-ing… The
      [n: {"E3", 2, "sound-"}, n: {"D3", 1, "ing…"}, rest: 0.5, n: {"G2", 0.5, "The"}],
      # 55  joy of the Lord, the
      [
        n: {"C3", 0.75, "joy"},
        n: {"C3", 0.25, "of"},
        n: {"C3", 0.5, "~of"},
        n: {"C3", 0.5, "the"},
        n: {"C3", 1, "Lord,"},
        rest: 0.5,
        n: {"C3", 0.5, "the"}
      ],
      # 56  joy of the Lord is my
      [
        n: {"D3", 0.75, "joy"},
        n: {"D3", 0.25, "of"},
        n: {"D3", 0.5, "~of"},
        n: {"D3", 0.5, "the"},
        n: {"D3", 0.75, "Lord"},
        n: {"D3", 0.25, "is"},
        n: {"D3", 0.5, "~is"},
        n: {"F3", 0.5, "my"}
      ],
      # 57  strength.
      [n: {"F3", 1, "~my"}, n: {"F3", 3, "strength."}],
      # 58  The
      [rest: 3.5, n: {"G2", 0.5, "The"}],
      # 59  joy of the Lord, the
      [
        n: {"C3", 0.75, "joy"},
        n: {"C3", 0.25, "of"},
        n: {"C3", 0.5, "~of"},
        n: {"C3", 0.5, "the"},
        n: {"C3", 1, "Lord,"},
        rest: 0.5,
        n: {"C3", 0.5, "the"}
      ],
      # 60  joy of the Lord is my
      [
        n: {"D3", 0.75, "joy"},
        n: {"D3", 0.25, "of"},
        n: {"D3", 0.5, "~of"},
        n: {"D3", 0.5, "the"},
        n: {"D3", 0.75, "Lord"},
        n: {"D3", 0.25, "is"},
        n: {"D3", 0.5, "~is"},
        n: {"F3", 0.5, "my"}
      ],
      # 61  strength.
      [n: {"F3", 1, "~my"}, n: {"F3", 3, "strength."}],
      # 62  O
      [rest: 3.5, n: {"A3", 0.5, "O"}],
      # 63  my soul, bless
      [
        n: {"A3", 0.5, "~O"},
        n: {"A3", 1, "my"},
        n: {"A3", 0.5, "soul,"},
        n: {"A3", 1, "~soul,"},
        rest: 0.5,
        n: {"G3", 0.5, "bless"}
      ],
      # 64  His Name, all
      [
        n: {"G3", 0.5, "~bless"},
        n: {"G3", 1, "His"},
        n: {"G3", 0.5, "Name,"},
        n: {"G3", 1, "~Name,"},
        rest: 0.5,
        n: {"E3", 0.5, "all"}
      ],
      # 65  that is with-in
      [
        n: {"E3", 0.5, "~all"},
        n: {"E3", 1, "that"},
        n: {"E3", 0.5, "is"},
        n: {"E3", 1, "~is"},
        n: {"E3", 0.5, "with-"},
        n: {"D3", 0.5, "in"}
      ],
      # 66  me say: The
      [
        n: {"D3", 0.5, "~in"},
        n: {"D3", 1, "me"},
        n: {"D3", 0.5, "say:"},
        n: {"D3", 1, "~say:"},
        rest: 0.5,
        n: {"C3", 0.5, "The"}
      ],
      # 67  joy of the Lord, the
      [
        n: {"C3", 0.75, "joy"},
        n: {"C3", 0.25, "of"},
        n: {"C3", 0.5, "~of"},
        n: {"C3", 0.5, "the"},
        n: {"C3", 1, "Lord,"},
        rest: 0.5,
        n: {"C3", 0.5, "the"}
      ],
      # 68  joy of the Lord is my
      [
        n: {"D3", 0.75, "joy"},
        n: {"D3", 0.25, "of"},
        n: {"D3", 0.5, "~of"},
        n: {"D3", 0.5, "the"},
        n: {"D3", 0.75, "Lord"},
        n: {"D3", 0.25, "is"},
        n: {"D3", 0.5, "~is"},
        n: {"C3", 0.5, "my"}
      ],
      # 69  strength.
      [n: {"C3", 1, "~my"}, n: {"C3", 3, "strength."}],
      # 70  (piano)
      [rest: 4],
      # 71  (piano)
      [rest: 4],
      # 72  (piano)
      [rest: 4],
      # 73  (piano)
      [rest: 4],
      # 74  (piano)
      [rest: 4],
      # 75  (piano)
      [rest: 4],
      # 76  Let it rise
      [
        rest: 1.5,
        n: {"F3", 0.5, "Let"},
        n: {"F3", 0.5, "~Let"},
        n: {"E3", 1, "it"},
        n: {"E3", 0.5, "rise"}
      ],
      # 77  up
      [n: {"E3", 1.5, "~rise"}, n: {"D3", 0.5, "up"}, n: {"D3", 2, "~up"}],
      # 78  like a riv-
      [
        rest: 1.5,
        n: {"E3", 0.5, "like"},
        n: {"E3", 0.5, "~like"},
        n: {"D3", 1, "a"},
        n: {"D3", 0.5, "riv-"}
      ],
      # 79  er,
      [n: {"D3", 1.5, "~riv-"}, n: {"C3", 0.5, "er,"}, n: {"C3", 2, "~er,"}],
      # 80  o-ver-flow-
      [
        rest: 1.5,
        n: {"F3", 0.5, "o-"},
        n: {"F3", 0.5, "~o-"},
        n: {"E3", 1, "ver-"},
        n: {"E3", 0.5, "flow-"}
      ],
      # 81  ing
      [n: {"E3", 1.5, "~flow-"}, n: {"D3", 0.5, "ing"}, n: {"D3", 2, "~ing"}],
      # 82  Ho-ly Spir-
      [
        rest: 1.5,
        n: {"E3", 0.5, "Ho-"},
        n: {"E3", 0.5, "~Ho-"},
        n: {"D3", 1, "ly"},
        n: {"D3", 0.5, "Spir-"}
      ],
      # 83  it.
      [n: {"D3", 1.5, "~Spir-"}, n: {"C3", 0.5, "it."}, n: {"C3", 2, "~it."}],
      # 84  Let it pour
      [
        rest: 1.5,
        n: {"F3", 0.5, "Let"},
        n: {"F3", 0.5, "~Let"},
        n: {"E3", 1, "it"},
        n: {"E3", 0.5, "pour"}
      ],
      # 85  out
      [n: {"E3", 1.5, "~pour"}, n: {"D3", 0.5, "out"}, n: {"D3", 2, "~out"}],
      # 86  with no lim-
      [
        rest: 1.5,
        n: {"E3", 0.5, "with"},
        n: {"E3", 0.5, "~with"},
        n: {"D3", 1, "no"},
        n: {"D3", 0.5, "lim-"}
      ],
      # 87  it,
      [n: {"D3", 1.5, "~lim-"}, n: {"C3", 0.5, "it,"}, n: {"C3", 2, "~it,"}],
      # 88  o-ver-flow-
      [
        rest: 1.5,
        n: {"F3", 0.5, "o-"},
        n: {"F3", 0.5, "~o-"},
        n: {"E3", 1, "ver-"},
        n: {"E3", 0.5, "flow-"}
      ],
      # 89  ing
      [n: {"E3", 1.5, "~flow-"}, n: {"D3", 0.5, "ing"}, n: {"D3", 2, "~ing"}],
      # 90  Ho-ly Spir-
      [
        rest: 1.5,
        n: {"E3", 0.5, "Ho-"},
        n: {"E3", 0.5, "~Ho-"},
        n: {"D3", 1, "ly"},
        n: {"D3", 0.5, "Spir-"}
      ],
      # 91  it.
      [n: {"D3", 1.5, "~Spir-"}, n: {"C3", 0.5, "it."}, n: {"C3", 2, "~it."}],
      # 92  Let it rise
      [
        rest: 1.5,
        n: {"C3", 0.5, "Let"},
        n: {"C3", 0.5, "~Let"},
        n: {"C3", 1, "it"},
        n: {"G3", 0.5, "rise"}
      ],
      # 93  up
      [n: {"G3", 1.5, "~rise"}, n: {"G3", 0.5, "up"}, n: {"G3", 2, "~up"}],
      # 94  like a riv-
      [
        rest: 1.5,
        n: {"G3", 0.5, "like"},
        n: {"G3", 0.5, "~like"},
        n: {"G3", 1, "a"},
        n: {"F3", 0.5, "riv-"}
      ],
      # 95  er,
      [n: {"F3", 1.5, "~riv-"}, n: {"C3", 0.5, "er,"}, n: {"C3", 2, "~er,"}],
      # 96  o-ver-flow-
      [
        rest: 1.5,
        n: {"C3", 0.5, "o-"},
        n: {"C3", 0.5, "~o-"},
        n: {"C3", 1, "ver-"},
        n: {"G3", 0.5, "flow-"}
      ],
      # 97  ing
      [n: {"G3", 1.5, "~flow-"}, n: {"G3", 0.5, "ing"}, n: {"G3", 2, "~ing"}],
      # 98  Ho-ly Spir-
      [
        rest: 1.5,
        n: {"G3", 0.5, "Ho-"},
        n: {"G3", 0.5, "~Ho-"},
        n: {"G3", 1, "ly"},
        n: {"F3", 0.5, "Spir-"}
      ],
      # 99  it.
      [n: {"F3", 1.5, "~Spir-"}, n: {"C3", 0.5, "it."}, n: {"C3", 2, "~it."}],
      # 100  Let it pour
      [
        rest: 1.5,
        n: {"C3", 0.5, "Let"},
        n: {"C3", 0.5, "~Let"},
        n: {"C3", 1, "it"},
        n: {"G3", 0.5, "pour"}
      ],
      # 101  out
      [n: {"G3", 1.5, "~pour"}, n: {"G3", 0.5, "out"}, n: {"G3", 2, "~out"}],
      # 102  with no lim-
      [
        rest: 1.5,
        n: {"G3", 0.5, "with"},
        n: {"G3", 0.5, "~with"},
        n: {"G3", 1, "no"},
        n: {"F3", 0.5, "lim-"}
      ],
      # 103  it,
      [n: {"F3", 1.5, "~lim-"}, n: {"C3", 0.5, "it,"}, n: {"C3", 2, "~it,"}],
      # 104  o-ver-flow-
      [
        rest: 1.5,
        n: {"C3", 0.5, "o-"},
        n: {"C3", 0.5, "~o-"},
        n: {"C3", 1, "ver-"},
        n: {"G3", 0.5, "flow-"}
      ],
      # 105  ing
      [n: {"G3", 1.5, "~flow-"}, n: {"G3", 0.5, "ing"}, n: {"G3", 2, "~ing"}],
      # 106  Ho-ly Spir-
      [
        rest: 1.5,
        n: {"G3", 0.5, "Ho-"},
        n: {"G3", 0.5, "~Ho-"},
        n: {"G3", 1, "ly"},
        n: {"F3", 0.5, "Spir-"}
      ],
      # 107  it.
      [n: {"F3", 1.5, "~Spir-"}, n: {"F3", 0.5, "it."}, n: {"F3", 2, "~it."}],
      # 108  (held)
      [n: {"F3", 3, "~it."}, rest: 1],
      # 109  He rules the
      [n: {"C4", 2, "He"}, n: {"B3", 1.5, "rules"}, n: {"A3", 0.5, "the"}],
      # 110  world with
      [n: {"G3", 2, "world"}, rest: 1, n: {"F3", 1, "with"}],
      # 111  truth and
      [n: {"E3", 2, "truth"}, n: {"D3", 2, "and"}],
      # 112  grace, and
      [n: {"C3", 2, "grace,"}, rest: 1, n: {"G3", 1, "and"}],
      # 113  makes the
      [n: {"A3", 2, "makes"}, rest: 1, n: {"A3", 1, "the"}],
      # 114  na-tions
      [n: {"B3", 3, "na-"}, n: {"B3", 1, "tions"}],
      # 115  prove
      [n: {"C4", 4, "prove"}],
      # 116  the
      [rest: 3, n: {"C4", 1, "the"}],
      # 117  glo-ries
      [n: {"C4", 1, "glo-"}, n: {"B3", 1, "~glo-"}, n: {"A3", 1, "ries"}, n: {"G3", 1, "~ries"}],
      # 118  of His
      [
        n: {"G3", 1.5, "of"},
        n: {"F3", 0.5, "~of"},
        n: {"E3", 0.5, "~of"},
        rest: 0.5,
        n: {"C4", 1, "His"}
      ],
      # 119  right-eous-
      [
        n: {"C4", 1, "right-"},
        n: {"B3", 1, "~right-"},
        n: {"A3", 1, "eous-"},
        n: {"G3", 1, "~eous-"}
      ],
      # 120  ness, and
      [
        n: {"G3", 1.5, "ness,"},
        n: {"F3", 0.5, "~ness,"},
        n: {"E3", 0.5, "~ness,"},
        rest: 0.5,
        n: {"E3", 1, "and"}
      ],
      # 121  won-ders of His
      [n: {"E3", 1, "won-"}, n: {"E3", 1, "ders"}, n: {"E3", 1, "of"}, n: {"F3", 1, "His"}],
      # 122  love, and
      [n: {"G3", 2, "love,"}, rest: 1, n: {"F3", 0.5, "and"}, n: {"E3", 0.5, "~and"}],
      # 123  won-ders of His
      [n: {"D3", 1, "won-"}, n: {"D3", 1, "ders"}, n: {"D3", 1, "of"}, n: {"E3", 1, "His"}],
      # 124  love, and
      [n: {"F3", 2, "love,"}, rest: 1, n: {"E3", 0.5, "and"}, n: {"D3", 0.5, "~and"}],
      # 125  won-ders,
      [n: {"C3", 1, "won-"}, n: {"C4", 2, "~won-"}, n: {"A3", 1, "ders,"}],
      # 126  won-ders
      [
        n: {"G3", 1.5, "won-"},
        n: {"F3", 0.5, "~won-"},
        n: {"E3", 1, "~won-"},
        n: {"F3", 1, "ders"}
      ],
      # 127  of His
      [n: {"E3", 2, "of"}, n: {"D3", 2, "His"}],
      # 128  love.
      [n: {"C3", 4, "love."}],
      # 129  The
      [rest: 3.5, n: {"G2", 0.5, "The"}],
      # 130  joy of the Lord, the
      [
        n: {"C3", 0.75, "joy"},
        n: {"C3", 0.25, "of"},
        n: {"C3", 0.5, "~of"},
        n: {"C3", 0.5, "the"},
        n: {"C3", 1, "Lord,"},
        rest: 0.5,
        n: {"C3", 0.5, "the"}
      ],
      # 131  joy of the Lord is my
      [
        n: {"D3", 0.75, "joy"},
        n: {"D3", 0.25, "of"},
        n: {"D3", 0.5, "~of"},
        n: {"D3", 0.5, "the"},
        n: {"D3", 0.75, "Lord"},
        n: {"D3", 0.25, "is"},
        n: {"D3", 0.5, "~is"},
        n: {"F3", 0.5, "my"}
      ],
      # 132  strength.
      [n: {"F3", 1, "~my"}, n: {"F3", 3, "strength."}],
      # 133  The
      [rest: 3.5, n: {"G2", 0.5, "The"}],
      # 134  joy of the Lord, the
      [
        n: {"C3", 0.75, "joy"},
        n: {"C3", 0.25, "of"},
        n: {"C3", 0.5, "~of"},
        n: {"C3", 0.5, "the"},
        n: {"C3", 1, "Lord,"},
        rest: 0.5,
        n: {"C3", 0.5, "the"}
      ],
      # 135  joy of the Lord is my
      [
        n: {"D3", 0.75, "joy"},
        n: {"D3", 0.25, "of"},
        n: {"D3", 0.5, "~of"},
        n: {"D3", 0.5, "the"},
        n: {"D3", 0.75, "Lord"},
        n: {"D3", 0.25, "is"},
        n: {"D3", 0.5, "~is"},
        n: {"F3", 0.5, "my"}
      ],
      # 136  strength.
      [n: {"F3", 1, "~my"}, n: {"F3", 3, "strength."}],
      # 137  O
      [rest: 3.5, n: {"A3", 0.5, "O"}],
      # 138  my soul, bless
      [
        n: {"A3", 0.5, "~O"},
        n: {"A3", 1, "my"},
        n: {"A3", 0.5, "soul,"},
        n: {"A3", 1, "~soul,"},
        rest: 0.5,
        n: {"G3", 0.5, "bless"}
      ],
      # 139  His Name, all
      [
        n: {"G3", 0.5, "~bless"},
        n: {"G3", 1, "His"},
        n: {"G3", 0.5, "Name,"},
        n: {"G3", 1, "~Name,"},
        rest: 0.5,
        n: {"E3", 0.5, "all"}
      ],
      # 140  that is with-in
      [
        n: {"E3", 0.5, "~all"},
        n: {"E3", 1, "that"},
        n: {"E3", 0.5, "is"},
        n: {"E3", 1, "~is"},
        n: {"E3", 0.5, "with-"},
        n: {"D3", 0.5, "in"}
      ],
      # 141  me say: O
      [
        n: {"D3", 0.5, "~in"},
        n: {"D3", 1, "me"},
        n: {"D3", 0.5, "say:"},
        n: {"D3", 1, "~say:"},
        rest: 0.5,
        n: {"A3", 0.5, "O"}
      ],
      # 142  my soul, bless
      [
        n: {"A3", 0.5, "~O"},
        n: {"A3", 1, "my"},
        n: {"A3", 0.5, "soul,"},
        n: {"A3", 1, "~soul,"},
        rest: 0.5,
        n: {"G3", 0.5, "bless"}
      ],
      # 143  His Name, all
      [
        n: {"G3", 0.5, "~bless"},
        n: {"G3", 1, "His"},
        n: {"G3", 0.5, "Name,"},
        n: {"G3", 1, "~Name,"},
        rest: 0.5,
        n: {"E3", 0.5, "all"}
      ],
      # 144  that is with-in
      [
        n: {"E3", 0.5, "~all"},
        n: {"E3", 1, "that"},
        n: {"E3", 0.5, "is"},
        n: {"E3", 1, "~is"},
        n: {"E3", 0.5, "with-"},
        n: {"D3", 0.5, "in"}
      ],
      # 145  me say: O
      [
        n: {"D3", 0.5, "~in"},
        n: {"D3", 1, "me"},
        n: {"D3", 0.5, "say:"},
        n: {"D3", 1, "~say:"},
        rest: 0.5,
        n: {"A3", 0.5, "O"}
      ],
      # 146  my soul, bless
      [
        n: {"A3", 0.5, "~O"},
        n: {"A3", 1, "my"},
        n: {"A3", 0.5, "soul,"},
        n: {"A3", 1, "~soul,"},
        rest: 0.5,
        n: {"B3", 0.5, "bless"}
      ],
      # 147  His Name, all
      [
        n: {"B3", 0.5, "~bless"},
        n: {"B3", 1, "His"},
        n: {"B3", 0.5, "Name,"},
        n: {"B3", 1, "~Name,"},
        rest: 0.5,
        n: {"E3", 0.5, "all"}
      ],
      # 148  that is with-in
      [
        n: {"E3", 0.5, "~all"},
        n: {"E3", 1, "that"},
        n: {"E3", 0.5, "is"},
        n: {"E3", 1, "~is"},
        n: {"E3", 0.5, "with-"},
        n: {"D3", 0.5, "in"}
      ],
      # 149  me say: The
      [
        n: {"D3", 0.5, "~in"},
        n: {"D3", 1, "me"},
        n: {"D3", 0.5, "say:"},
        n: {"D3", 1, "~say:"},
        rest: 0.5,
        n: {"C3", 0.5, "The"}
      ],
      # 150  joy of the Lord, the
      [
        n: {"C3", 0.75, "joy"},
        n: {"C3", 0.25, "of"},
        n: {"C3", 0.5, "~of"},
        n: {"C3", 0.5, "the"},
        n: {"C3", 1, "Lord,"},
        rest: 0.5,
        n: {"C3", 0.5, "the"}
      ],
      # 151  joy of the Lord is my
      [
        n: {"D3", 0.75, "joy"},
        n: {"D3", 0.25, "of"},
        n: {"D3", 0.5, "~of"},
        n: {"D3", 0.5, "the"},
        n: {"D3", 0.75, "Lord"},
        n: {"D3", 0.25, "is"},
        n: {"D3", 0.5, "~is"},
        n: {"C3", 0.5, "my"}
      ],
      # 152  strength.
      [n: {"C3", 1, "~my"}, n: {"C3", 3, "strength."}],
      # 153  (piano)
      [rest: 4],
      # 154  (solo, piano)
      [rest: 4],
      # 155  (solo, piano)
      [rest: 4],
      # 156  (solo, piano)
      [rest: 4],
      # 157  (solo, piano)
      [rest: 4],
      # 158  (piano)
      [rest: 4],
      # 159  (piano)
      [rest: 4],
      # 160  (piano)
      [rest: 4]
    ]
  end

  defp melody_bars do
    [
      # 1  (intro)
      [rest: 4],
      # 2  (intro)
      [rest: 4],
      # 3  (intro)
      [rest: 4],
      # 4  (intro)
      [rest: 4],
      # 5  (intro)
      [rest: 4],
      # 6  (intro)
      [rest: 4],
      # 7  (intro)
      [rest: 4],
      # 8  (intro)
      [rest: 4],
      # 9  (intro)
      [rest: 4],
      # 10  (intro)
      [rest: 4],
      # 11  (intro)
      [rest: 4],
      # 12  (intro)
      [rest: 4],
      # 13  Joy to the
      [n: {"C5", 2, "Joy"}, n: {"B4", 1.5, "to"}, n: {"A4", 0.5, "the"}],
      # 14  world, the
      [n: {"G4", 2, "world,"}, rest: 1, n: {"F4", 1, "the"}],
      # 15  Lord is
      [n: {"E4", 2, "Lord"}, n: {"D4", 2, "is"}],
      # 16  come, let
      [n: {"C4", 2, "come,"}, rest: 1, n: {"G4", 1, "let"}],
      # 17  earth re-
      [n: {"A4", 2, "earth"}, rest: 1, n: {"A4", 1, "re-"}],
      # 18  ceive her
      [n: {"B4", 3, "ceive"}, n: {"B4", 1, "her"}],
      # 19  King.
      [n: {"C5", 4, "King."}],
      # 20  Let
      [rest: 3, n: {"C5", 1, "Let"}],
      # 21  ev-'ry
      [n: {"C5", 1, "ev-"}, n: {"B4", 1, "~ev-"}, n: {"A4", 1, "'ry"}, n: {"G4", 1, "~'ry"}],
      # 22  heart pre-
      [
        n: {"G4", 1.5, "heart"},
        n: {"F4", 0.5, "~heart"},
        n: {"E4", 0.5, "~heart"},
        rest: 0.5,
        n: {"C5", 1, "pre-"}
      ],
      # 23  pare Him
      [n: {"C5", 1, "pare"}, n: {"B4", 1, "~pare"}, n: {"A4", 1, "Him"}, n: {"G4", 1, "~Him"}],
      # 24  room, and
      [
        n: {"G4", 1.5, "room,"},
        n: {"F4", 0.5, "~room,"},
        n: {"E4", 0.5, "~room,"},
        rest: 0.5,
        n: {"E4", 1, "and"}
      ],
      # 25  Heav-en and na-ture
      [
        n: {"E4", 0.5, "Heav-"},
        n: {"E4", 0.5, "en"},
        n: {"E4", 1, "and"},
        n: {"E4", 1, "na-"},
        n: {"F4", 1, "ture"}
      ],
      # 26  sing, and
      [n: {"G4", 2, "sing,"}, rest: 1, n: {"F4", 0.5, "and"}, n: {"E4", 0.5, "~and"}],
      # 27  Heav-en and na-ture
      [
        n: {"D4", 0.5, "Heav-"},
        n: {"D4", 0.5, "en"},
        n: {"D4", 1, "and"},
        n: {"D4", 1, "na-"},
        n: {"E4", 1, "ture"}
      ],
      # 28  sing, and
      [n: {"F4", 2, "sing,"}, rest: 1, n: {"E4", 0.5, "and"}, n: {"D4", 0.5, "~and"}],
      # 29  Heav-en and
      [n: {"C4", 1, "Heav-"}, n: {"C5", 2, "en"}, n: {"A4", 1, "and"}],
      # 30  Heav-en and
      [
        n: {"G4", 1.5, "Heav-"},
        n: {"F4", 0.5, "~Heav-"},
        n: {"E4", 1, "en"},
        n: {"F4", 1, "and"}
      ],
      # 31  na-ture
      [n: {"E4", 2, "na-"}, n: {"D4", 2, "ture"}],
      # 32  sing.
      [n: {"C4", 4, "sing."}],
      # 33  (turn)
      [rest: 4],
      # 34  (turn)
      [rest: 4],
      # 35  (turn)
      [rest: 4],
      # 36  Joy to the
      [n: {"C5", 2, "Joy"}, n: {"B4", 1.5, "to"}, n: {"A4", 0.5, "the"}],
      # 37  Earth, the
      [n: {"G4", 2, "Earth,"}, rest: 1, n: {"F4", 1, "the"}],
      # 38  Sav-ior
      [n: {"E4", 2, "Sav-"}, n: {"D4", 2, "ior"}],
      # 39  reigns, let
      [n: {"C4", 2, "reigns,"}, rest: 1, n: {"G4", 1, "let"}],
      # 40  all, their
      [n: {"A4", 2, "all,"}, rest: 1, n: {"A4", 1, "their"}],
      # 41  songs em-
      [n: {"B4", 3, "songs"}, n: {"B4", 1, "em-"}],
      # 42  ploy,
      [n: {"C5", 4, "ploy,"}],
      # 43  while
      [rest: 3, n: {"C5", 1, "while"}],
      # 44  fields and
      [
        n: {"C5", 1, "fields"},
        n: {"B4", 1, "~fields"},
        n: {"A4", 1, "and"},
        n: {"G4", 1, "~and"}
      ],
      # 45  floods, rocks,
      [
        n: {"G4", 1.5, "floods,"},
        n: {"F4", 0.5, "~floods,"},
        n: {"E4", 0.5, "~floods,"},
        rest: 0.5,
        n: {"C5", 1, "rocks,"}
      ],
      # 46  hills and
      [n: {"C5", 1, "hills"}, n: {"B4", 1, "~hills"}, n: {"A4", 1, "and"}, n: {"G4", 1, "~and"}],
      # 47  plains re-
      [
        n: {"G4", 1.5, "plains"},
        n: {"F4", 0.5, "~plains"},
        n: {"E4", 0.5, "~plains"},
        rest: 0.5,
        n: {"E4", 1, "re-"}
      ],
      # 48  peat the sound-ing
      [n: {"E4", 1, "peat"}, n: {"E4", 1, "the"}, n: {"E4", 1, "sound-"}, n: {"F4", 1, "ing"}],
      # 49  joy, re-
      [n: {"G4", 2, "joy,"}, rest: 1, n: {"F4", 0.5, "re-"}, n: {"E4", 0.5, "~re-"}],
      # 50  peat the sound-ing
      [n: {"D4", 1, "peat"}, n: {"D4", 1, "the"}, n: {"D4", 1, "sound-"}, n: {"E4", 1, "ing"}],
      # 51  joy, re-
      [n: {"F4", 2, "joy,"}, rest: 1, n: {"E4", 0.5, "re-"}, n: {"D4", 0.5, "~re-"}],
      # 52  peat, re-
      [n: {"C4", 1, "peat,"}, n: {"C5", 2, "~peat,"}, n: {"A4", 1, "re-"}],
      # 53  peat, the
      [
        n: {"G4", 1.5, "peat,"},
        n: {"F4", 0.5, "~peat,"},
        n: {"E4", 1, "~peat,"},
        n: {"F4", 1, "the"}
      ],
      # 54  sound-ing… The
      [n: {"E4", 2, "sound-"}, n: {"D4", 1, "ing…"}, rest: 0.5, n: {"G3", 0.5, "The"}],
      # 55  joy of the Lord, the  (tenor, mel.)
      [
        n: {"C4", 0.75, "joy"},
        n: {"C4", 0.75, "of"},
        n: {"C4", 0.5, "the"},
        n: {"C4", 1, "Lord,"},
        rest: 0.5,
        n: {"C4", 0.5, "the"}
      ],
      # 56  joy of the Lord is my  (tenor, mel.)
      [
        n: {"C4", 0.75, "joy"},
        n: {"D4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 0.75, "Lord"},
        n: {"D4", 0.75, "is"},
        n: {"C4", 0.5, "my"}
      ],
      # 57  strength.  (tenor, mel.)
      [n: {"C4", 1, "~my"}, n: {"C4", 3, "strength."}],
      # 58  The  (tenor, mel.)
      [rest: 3.5, n: {"G3", 0.5, "The"}],
      # 59  joy of the Lord, the  (tenor, mel.)
      [
        n: {"C4", 0.75, "joy"},
        n: {"C4", 0.75, "of"},
        n: {"C4", 0.5, "the"},
        n: {"C4", 1, "Lord,"},
        rest: 0.5,
        n: {"C4", 0.5, "the"}
      ],
      # 60  joy of the Lord is my  (tenor, mel.)
      [
        n: {"C4", 0.75, "joy"},
        n: {"D4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 0.75, "Lord"},
        n: {"D4", 0.75, "is"},
        n: {"C4", 0.5, "my"}
      ],
      # 61  strength.  (tenor, mel.)
      [n: {"C4", 1, "~my"}, n: {"C4", 3, "strength."}],
      # 62  O  (tenor, mel.)
      [rest: 3.5, n: {"C4", 0.5, "O"}],
      # 63  my soul, bless  (tenor, mel.)
      [
        n: {"C4", 0.5, "~O"},
        n: {"C4", 1, "my"},
        n: {"C4", 1.5, "soul,"},
        rest: 0.5,
        n: {"D4", 0.5, "bless"}
      ],
      # 64  His Name, all  (tenor, mel.)
      [
        n: {"D4", 0.5, "~bless"},
        n: {"D4", 1, "His"},
        n: {"D4", 1.5, "Name,"},
        rest: 0.5,
        n: {"E4", 0.5, "all"}
      ],
      # 65  that is with-in  (tenor, mel.)
      [
        n: {"E4", 0.5, "~all"},
        n: {"E4", 1, "that"},
        n: {"E4", 1.5, "is"},
        n: {"C4", 0.5, "with-"},
        n: {"F4", 0.5, "in"}
      ],
      # 66  me say: The  (tenor, mel.)
      [
        n: {"F4", 0.5, "~in"},
        n: {"E4", 1, "me"},
        n: {"D4", 1.5, "say:"},
        rest: 0.5,
        n: {"G3", 0.5, "The"}
      ],
      # 67  joy of the Lord, the  (tenor, mel.)
      [
        n: {"C4", 0.75, "joy"},
        n: {"C4", 0.75, "of"},
        n: {"C4", 0.5, "the"},
        n: {"C4", 1, "Lord,"},
        rest: 0.5,
        n: {"C4", 0.5, "the"}
      ],
      # 68  joy of the Lord is my  (tenor, mel.)
      [
        n: {"C4", 0.75, "joy"},
        n: {"D4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 0.75, "Lord"},
        n: {"D4", 0.75, "is"},
        n: {"C4", 0.5, "my"}
      ],
      # 69  strength.  (tenor, mel.)
      [n: {"C4", 1, "~my"}, n: {"C4", 3, "strength."}],
      # 70  (turn)
      [rest: 4],
      # 71  (turn)
      [rest: 4],
      # 72  (turn)
      [rest: 4],
      # 73  (turn)
      [rest: 4],
      # 74  (turn)
      [rest: 4],
      # 75  (turn)
      [rest: 4],
      # 76  Let it rise  (women unison)
      [rest: 1.5, n: {"F4", 1, "Let"}, n: {"E4", 1, "it"}, n: {"E4", 0.5, "rise"}],
      # 77  up  (women unison)
      [n: {"E4", 1.5, "~rise"}, n: {"D4", 2.5, "up"}],
      # 78  like a riv-  (women unison)
      [rest: 1.5, n: {"E4", 1, "like"}, n: {"D4", 1, "a"}, n: {"D4", 0.5, "riv-"}],
      # 79  er,  (women unison)
      [n: {"D4", 1.5, "~riv-"}, n: {"C4", 2.5, "er,"}],
      # 80  o-ver-flow-  (women unison)
      [rest: 1.5, n: {"F4", 1, "o-"}, n: {"E4", 1, "ver-"}, n: {"E4", 0.5, "flow-"}],
      # 81  ing  (women unison)
      [n: {"E4", 1.5, "~flow-"}, n: {"D4", 2.5, "ing"}],
      # 82  Ho-ly Spir-  (women unison)
      [rest: 1.5, n: {"E4", 1, "Ho-"}, n: {"D4", 1, "ly"}, n: {"D4", 0.5, "Spir-"}],
      # 83  it.  (women unison)
      [n: {"D4", 1.5, "~Spir-"}, n: {"C4", 2.5, "it."}],
      # 84  Let it pour  (women unison)
      [rest: 1.5, n: {"F4", 1, "Let"}, n: {"E4", 1, "it"}, n: {"E4", 0.5, "pour"}],
      # 85  out  (women unison)
      [n: {"E4", 1.5, "~pour"}, n: {"D4", 2.5, "out"}],
      # 86  with no lim-  (women unison)
      [rest: 1.5, n: {"E4", 1, "with"}, n: {"D4", 1, "no"}, n: {"D4", 0.5, "lim-"}],
      # 87  it,  (women unison)
      [n: {"D4", 1.5, "~lim-"}, n: {"C4", 2.5, "it,"}],
      # 88  o-ver-flow-  (women unison)
      [rest: 1.5, n: {"F4", 1, "o-"}, n: {"E4", 1, "ver-"}, n: {"E4", 0.5, "flow-"}],
      # 89  ing  (women unison)
      [n: {"E4", 1.5, "~flow-"}, n: {"D4", 2.5, "ing"}],
      # 90  Ho-ly Spir-  (women unison)
      [rest: 1.5, n: {"E4", 1, "Ho-"}, n: {"D4", 1, "ly"}, n: {"D4", 0.5, "Spir-"}],
      # 91  it.  (women unison)
      [n: {"D4", 1.5, "~Spir-"}, n: {"C4", 2.5, "it."}],
      # 92  Let it rise  (tenor)
      [rest: 1.5, n: {"F4", 1, "Let"}, n: {"E4", 1, "it"}, n: {"E4", 0.5, "rise"}],
      # 93  up  (tenor)
      [n: {"E4", 1.5, "~rise"}, n: {"D4", 2.5, "up"}],
      # 94  like a riv-  (tenor)
      [rest: 1.5, n: {"E4", 1, "like"}, n: {"D4", 1, "a"}, n: {"D4", 0.5, "riv-"}],
      # 95  er,  (tenor)
      [n: {"D4", 1.5, "~riv-"}, n: {"C4", 2.5, "er,"}],
      # 96  o-ver-flow-  (tenor)
      [rest: 1.5, n: {"F4", 1, "o-"}, n: {"E4", 1, "ver-"}, n: {"E4", 0.5, "flow-"}],
      # 97  ing  (tenor)
      [n: {"E4", 1.5, "~flow-"}, n: {"D4", 2.5, "ing"}],
      # 98  Ho-ly Spir-  (tenor)
      [rest: 1.5, n: {"E4", 1, "Ho-"}, n: {"D4", 1, "ly"}, n: {"D4", 0.5, "Spir-"}],
      # 99  it.  (tenor)
      [n: {"D4", 1.5, "~Spir-"}, n: {"C4", 2.5, "it."}],
      # 100  Let it pour  (tenor)
      [rest: 1.5, n: {"F4", 1, "Let"}, n: {"E4", 1, "it"}, n: {"E4", 0.5, "pour"}],
      # 101  out  (tenor)
      [n: {"E4", 1.5, "~pour"}, n: {"D4", 2.5, "out"}],
      # 102  with no lim-  (tenor)
      [rest: 1.5, n: {"E4", 1, "with"}, n: {"D4", 1, "no"}, n: {"D4", 0.5, "lim-"}],
      # 103  it,  (tenor)
      [n: {"D4", 1.5, "~lim-"}, n: {"C4", 2.5, "it,"}],
      # 104  o-ver-flow-  (tenor)
      [rest: 1.5, n: {"F4", 1, "o-"}, n: {"E4", 1, "ver-"}, n: {"E4", 0.5, "flow-"}],
      # 105  ing  (tenor)
      [n: {"E4", 1.5, "~flow-"}, n: {"D4", 2.5, "ing"}],
      # 106  Ho-ly Spir-  (tenor)
      [rest: 1.5, n: {"E4", 1, "Ho-"}, n: {"D4", 1, "ly"}, n: {"D4", 0.5, "Spir-"}],
      # 107  it.  (tenor)
      [n: {"D4", 1.5, "~Spir-"}, n: {"C4", 2.5, "it."}],
      # 108  (tenor)
      [n: {"C4", 3, "~it."}, rest: 1],
      # 109  He rules the
      [n: {"C5", 2, "He"}, n: {"B4", 1.5, "rules"}, n: {"A4", 0.5, "the"}],
      # 110  world with
      [n: {"G4", 2, "world"}, rest: 1, n: {"F4", 1, "with"}],
      # 111  truth and
      [n: {"E4", 2, "truth"}, n: {"D4", 2, "and"}],
      # 112  grace, and
      [n: {"C4", 2, "grace,"}, rest: 1, n: {"G4", 1, "and"}],
      # 113  makes the
      [n: {"A4", 2, "makes"}, rest: 1, n: {"A4", 1, "the"}],
      # 114  na-tions
      [n: {"B4", 3, "na-"}, n: {"B4", 1, "tions"}],
      # 115  prove
      [n: {"C5", 4, "prove"}],
      # 116  the
      [rest: 3, n: {"C5", 1, "the"}],
      # 117  glo-ries
      [n: {"C5", 1, "glo-"}, n: {"B4", 1, "~glo-"}, n: {"A4", 1, "ries"}, n: {"G4", 1, "~ries"}],
      # 118  of His
      [
        n: {"G4", 1.5, "of"},
        n: {"F4", 0.5, "~of"},
        n: {"E4", 0.5, "~of"},
        rest: 0.5,
        n: {"C5", 1, "His"}
      ],
      # 119  right-eous-
      [
        n: {"C5", 1, "right-"},
        n: {"B4", 1, "~right-"},
        n: {"A4", 1, "eous-"},
        n: {"G4", 1, "~eous-"}
      ],
      # 120  ness, and
      [
        n: {"G4", 1.5, "ness,"},
        n: {"F4", 0.5, "~ness,"},
        n: {"E4", 0.5, "~ness,"},
        rest: 0.5,
        n: {"E4", 1, "and"}
      ],
      # 121  won-ders of His
      [n: {"E4", 1, "won-"}, n: {"E4", 1, "ders"}, n: {"E4", 1, "of"}, n: {"F4", 1, "His"}],
      # 122  love, and
      [n: {"G4", 2, "love,"}, rest: 1, n: {"F4", 0.5, "and"}, n: {"E4", 0.5, "~and"}],
      # 123  won-ders of His
      [n: {"D4", 1, "won-"}, n: {"D4", 1, "ders"}, n: {"D4", 1, "of"}, n: {"E4", 1, "His"}],
      # 124  love, and
      [n: {"F4", 2, "love,"}, rest: 1, n: {"E4", 0.5, "and"}, n: {"D4", 0.5, "~and"}],
      # 125  won-ders,
      [n: {"C4", 1, "won-"}, n: {"C5", 2, "~won-"}, n: {"A4", 1, "ders,"}],
      # 126  won-ders
      [
        n: {"G4", 1.5, "won-"},
        n: {"F4", 0.5, "~won-"},
        n: {"E4", 1, "~won-"},
        n: {"F4", 1, "ders"}
      ],
      # 127  of His
      [n: {"E4", 2, "of"}, n: {"D4", 2, "His"}],
      # 128  love.
      [n: {"C4", 4, "love."}],
      # 129  The
      [rest: 3.5, n: {"G3", 0.5, "The"}],
      # 130  joy of the Lord, the  (tenor, mel.)
      [
        n: {"C4", 0.75, "joy"},
        n: {"C4", 0.75, "of"},
        n: {"C4", 0.5, "the"},
        n: {"C4", 1, "Lord,"},
        rest: 0.5,
        n: {"C4", 0.5, "the"}
      ],
      # 131  joy of the Lord is my  (tenor, mel.)
      [
        n: {"C4", 0.75, "joy"},
        n: {"D4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 0.75, "Lord"},
        n: {"D4", 0.75, "is"},
        n: {"C4", 0.5, "my"}
      ],
      # 132  strength.  (tenor, mel.)
      [n: {"C4", 1, "~my"}, n: {"C4", 3, "strength."}],
      # 133  The  (tenor, mel.)
      [rest: 3.5, n: {"G3", 0.5, "The"}],
      # 134  joy of the Lord, the  (tenor, mel.)
      [
        n: {"C4", 0.75, "joy"},
        n: {"C4", 0.75, "of"},
        n: {"C4", 0.5, "the"},
        n: {"C4", 1, "Lord,"},
        rest: 0.5,
        n: {"C4", 0.5, "the"}
      ],
      # 135  joy of the Lord is my  (tenor, mel.)
      [
        n: {"C4", 0.75, "joy"},
        n: {"D4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 0.75, "Lord"},
        n: {"D4", 0.75, "is"},
        n: {"C4", 0.5, "my"}
      ],
      # 136  strength.  (tenor, mel.)
      [n: {"C4", 1, "~my"}, n: {"C4", 3, "strength."}],
      # 137  O  (tenor, mel.)
      [rest: 3.5, n: {"C4", 0.5, "O"}],
      # 138  my soul, bless  (tenor, mel.)
      [
        n: {"C4", 0.5, "~O"},
        n: {"C4", 1, "my"},
        n: {"C4", 1.5, "soul,"},
        rest: 0.5,
        n: {"D4", 0.5, "bless"}
      ],
      # 139  His Name, all  (tenor, mel.)
      [
        n: {"D4", 0.5, "~bless"},
        n: {"D4", 1, "His"},
        n: {"D4", 1.5, "Name,"},
        rest: 0.5,
        n: {"E4", 0.5, "all"}
      ],
      # 140  that is with-in  (tenor, mel.)
      [
        n: {"E4", 0.5, "~all"},
        n: {"E4", 1, "that"},
        n: {"E4", 1.5, "is"},
        n: {"C4", 0.5, "with-"},
        n: {"F4", 0.5, "in"}
      ],
      # 141  me say: O  (tenor, mel.)
      [
        n: {"F4", 0.5, "~in"},
        n: {"E4", 1, "me"},
        n: {"D4", 1.5, "say:"},
        rest: 0.5,
        n: {"C4", 0.5, "O"}
      ],
      # 142  my soul, bless  (tenor, mel.)
      [
        n: {"C4", 0.5, "~O"},
        n: {"C4", 1, "my"},
        n: {"C4", 1.5, "soul,"},
        rest: 0.5,
        n: {"D4", 0.5, "bless"}
      ],
      # 143  His Name, all  (tenor, mel.)
      [
        n: {"D4", 0.5, "~bless"},
        n: {"D4", 1, "His"},
        n: {"D4", 1.5, "Name,"},
        rest: 0.5,
        n: {"E4", 0.5, "all"}
      ],
      # 144  that is with-in  (tenor, mel.)
      [
        n: {"E4", 0.5, "~all"},
        n: {"E4", 1, "that"},
        n: {"E4", 1.5, "is"},
        n: {"C4", 0.5, "with-"},
        n: {"F4", 0.5, "in"}
      ],
      # 145  me say: O  (tenor, mel.)
      [
        n: {"F4", 0.5, "~in"},
        n: {"E4", 1, "me"},
        n: {"D4", 1.5, "say:"},
        rest: 0.5,
        n: {"C4", 0.5, "O"}
      ],
      # 146  my soul, bless  (tenor, mel.)
      [
        n: {"C4", 0.5, "~O"},
        n: {"C4", 1, "my"},
        n: {"C4", 1.5, "soul,"},
        rest: 0.5,
        n: {"D4", 0.5, "bless"}
      ],
      # 147  His Name, all  (tenor, mel.)
      [
        n: {"D4", 0.5, "~bless"},
        n: {"D4", 1, "His"},
        n: {"D4", 1.5, "Name,"},
        rest: 0.5,
        n: {"E4", 0.5, "all"}
      ],
      # 148  that is with-in  (tenor, mel.)
      [
        n: {"E4", 0.5, "~all"},
        n: {"E4", 1, "that"},
        n: {"E4", 1.5, "is"},
        n: {"C4", 0.5, "with-"},
        n: {"F4", 0.5, "in"}
      ],
      # 149  me say: The  (tenor, mel.)
      [
        n: {"F4", 0.5, "~in"},
        n: {"E4", 1, "me"},
        n: {"D4", 1.5, "say:"},
        rest: 0.5,
        n: {"G3", 0.5, "The"}
      ],
      # 150  joy of the Lord, the  (tenor, mel.)
      [
        n: {"C4", 0.75, "joy"},
        n: {"C4", 0.75, "of"},
        n: {"C4", 0.5, "the"},
        n: {"C4", 1, "Lord,"},
        rest: 0.5,
        n: {"C4", 0.5, "the"}
      ],
      # 151  joy of the Lord is my  (tenor, mel.)
      [
        n: {"C4", 0.75, "joy"},
        n: {"D4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 0.75, "Lord"},
        n: {"D4", 0.75, "is"},
        n: {"C4", 0.5, "my"}
      ],
      # 152  strength.  (tenor, mel.)
      [n: {"C4", 1, "~my"}, n: {"C4", 3, "strength."}],
      # 153
      [rest: 4],
      # 154  The  (solo)
      [rest: 3.5, n: {"C4", 0.5, "The"}],
      # 155  joy of the Lord is my  (solo)
      [
        n: {"C4", 0.75, "joy"},
        n: {"D4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 0.75, "Lord"},
        n: {"D4", 0.75, "is"},
        n: {"C4", 0.5, "my"}
      ],
      # 156  strength.  (solo)
      [n: {"C4", 1, "~my"}, n: {"G4", 3, "strength."}],
      # 157  (solo)
      [n: {"G4", 3, "~strength."}, rest: 1],
      # 158  (outro)
      [rest: 4],
      # 159  (outro)
      [rest: 4],
      # 160  (outro)
      [rest: 4]
    ]
  end

  defp soprano_bars do
    [
      # 1  (intro)
      [rest: 4],
      # 2  (intro)
      [rest: 4],
      # 3  (intro)
      [rest: 4],
      # 4  (intro)
      [rest: 4],
      # 5  (intro)
      [rest: 4],
      # 6  (intro)
      [rest: 4],
      # 7  (intro)
      [rest: 4],
      # 8  (intro)
      [rest: 4],
      # 9  (intro)
      [rest: 4],
      # 10  (intro)
      [rest: 4],
      # 11  (intro)
      [rest: 4],
      # 12  (intro)
      [rest: 4],
      # 13  verse 1, unison: Joy to the
      [n: {"C5", 2, "Joy"}, n: {"B4", 1.5, "to"}, n: {"A4", 0.5, "the"}],
      # 14  world, the
      [n: {"G4", 2, "world,"}, rest: 1, n: {"F4", 1, "the"}],
      # 15  Lord is
      [n: {"E4", 2, "Lord"}, n: {"D4", 2, "is"}],
      # 16  come, let
      [n: {"C4", 2, "come,"}, rest: 1, n: {"G4", 1, "let"}],
      # 17  earth re-
      [n: {"A4", 2, "earth"}, rest: 1, n: {"A4", 1, "re-"}],
      # 18  ceive her
      [n: {"B4", 3, "ceive"}, n: {"B4", 1, "her"}],
      # 19  King.
      [n: {"C5", 4, "King."}],
      # 20  Let
      [rest: 3, n: {"C5", 1, "Let"}],
      # 21  ev-'ry
      [n: {"C5", 1, "ev-"}, n: {"B4", 1, "~ev-"}, n: {"A4", 1, "'ry"}, n: {"G4", 1, "~'ry"}],
      # 22  heart pre-
      [
        n: {"G4", 1.5, "heart"},
        n: {"F4", 0.5, "~heart"},
        n: {"E4", 0.5, "~heart"},
        rest: 0.5,
        n: {"C5", 1, "pre-"}
      ],
      # 23  pare Him
      [n: {"C5", 1, "pare"}, n: {"B4", 1, "~pare"}, n: {"A4", 1, "Him"}, n: {"G4", 1, "~Him"}],
      # 24  room, and
      [
        n: {"G4", 1.5, "room,"},
        n: {"F4", 0.5, "~room,"},
        n: {"E4", 0.5, "~room,"},
        rest: 0.5,
        n: {"E4", 1, "and"}
      ],
      # 25  Heav-en and na-ture
      [
        n: {"E4", 0.5, "Heav-"},
        n: {"E4", 0.5, "en"},
        n: {"E4", 1, "and"},
        n: {"E4", 1, "na-"},
        n: {"F4", 1, "ture"}
      ],
      # 26  sing, and
      [n: {"G4", 2, "sing,"}, rest: 1, n: {"F4", 0.5, "and"}, n: {"E4", 0.5, "~and"}],
      # 27  Heav-en and na-ture
      [
        n: {"D4", 0.5, "Heav-"},
        n: {"D4", 0.5, "en"},
        n: {"D4", 1, "and"},
        n: {"D4", 1, "na-"},
        n: {"E4", 1, "ture"}
      ],
      # 28  sing, and
      [n: {"F4", 2, "sing,"}, rest: 1, n: {"E4", 0.5, "and"}, n: {"D4", 0.5, "~and"}],
      # 29  Heav-en and
      [n: {"C4", 1, "Heav-"}, n: {"C5", 2, "en"}, n: {"A4", 1, "and"}],
      # 30  Heav-en and
      [
        n: {"G4", 1.5, "Heav-"},
        n: {"F4", 0.5, "~Heav-"},
        n: {"E4", 1, "en"},
        n: {"F4", 1, "and"}
      ],
      # 31  na-ture
      [n: {"E4", 2, "na-"}, n: {"D4", 2, "ture"}],
      # 32  sing.
      [n: {"C4", 4, "sing."}],
      # 33  (turn)
      [rest: 4],
      # 34  (turn)
      [rest: 4],
      # 35  (turn)
      [rest: 4],
      # 36  verse 2, divided: Joy to the
      [n: {"C5", 2, "Joy"}, n: {"B4", 1.5, "to"}, n: {"A4", 0.5, "the"}],
      # 37  Earth, the
      [n: {"G4", 2, "Earth,"}, rest: 1, n: {"F4", 1, "the"}],
      # 38  Sav-ior
      [n: {"E4", 2, "Sav-"}, n: {"D4", 2, "ior"}],
      # 39  reigns, let
      [n: {"C4", 2, "reigns,"}, rest: 1, n: {"G4", 1, "let"}],
      # 40  all, their
      [n: {"A4", 2, "all,"}, rest: 1, n: {"A4", 1, "their"}],
      # 41  songs em-
      [n: {"B4", 3, "songs"}, n: {"B4", 1, "em-"}],
      # 42  ploy,
      [n: {"C5", 4, "ploy,"}],
      # 43  while
      [rest: 3, n: {"C5", 1, "while"}],
      # 44  fields and
      [
        n: {"C5", 1, "fields"},
        n: {"B4", 1, "~fields"},
        n: {"A4", 1, "and"},
        n: {"G4", 1, "~and"}
      ],
      # 45  floods, rocks,
      [
        n: {"G4", 1.5, "floods,"},
        n: {"F4", 0.5, "~floods,"},
        n: {"E4", 0.5, "~floods,"},
        rest: 0.5,
        n: {"C5", 1, "rocks,"}
      ],
      # 46  hills and
      [n: {"C5", 1, "hills"}, n: {"B4", 1, "~hills"}, n: {"A4", 1, "and"}, n: {"G4", 1, "~and"}],
      # 47  plains re-
      [
        n: {"G4", 1.5, "plains"},
        n: {"F4", 0.5, "~plains"},
        n: {"E4", 0.5, "~plains"},
        rest: 0.5,
        n: {"E4", 1, "re-"}
      ],
      # 48  peat the sound-ing
      [n: {"E4", 1, "peat"}, n: {"E4", 1, "the"}, n: {"E4", 1, "sound-"}, n: {"F4", 1, "ing"}],
      # 49  joy, re-
      [n: {"G4", 2, "joy,"}, rest: 1, n: {"F4", 0.5, "re-"}, n: {"E4", 0.5, "~re-"}],
      # 50  peat the sound-ing
      [n: {"D4", 1, "peat"}, n: {"D4", 1, "the"}, n: {"D4", 1, "sound-"}, n: {"E4", 1, "ing"}],
      # 51  joy, re-
      [n: {"F4", 2, "joy,"}, rest: 1, n: {"E4", 0.5, "re-"}, n: {"D4", 0.5, "~re-"}],
      # 52  peat, re-
      [n: {"C4", 1, "peat,"}, n: {"C5", 2, "~peat,"}, n: {"A4", 1, "re-"}],
      # 53  peat, the
      [
        n: {"G4", 1.5, "peat,"},
        n: {"F4", 0.5, "~peat,"},
        n: {"E4", 1, "~peat,"},
        n: {"F4", 1, "the"}
      ],
      # 54  sound-ing... The
      [n: {"E4", 2, "sound-"}, n: {"D4", 1, "ing..."}, rest: 0.5, n: {"E4", 0.5, "The"}],
      # 55  chorus: joy of the Lord, the
      [
        n: {"G4", 0.75, "joy"},
        n: {"G4", 0.75, "of"},
        n: {"G4", 0.5, "the"},
        n: {"G4", 1, "Lord,"},
        rest: 0.5,
        n: {"G4", 0.5, "the"}
      ],
      # 56  joy of the Lord is my
      [
        n: {"G4", 0.75, "joy"},
        n: {"A4", 0.75, "of"},
        n: {"C5", 0.5, "the"},
        n: {"C5", 0.75, "Lord"},
        n: {"A4", 0.75, "is"},
        n: {"G4", 0.5, "my"}
      ],
      # 57  (my) strength.
      [n: {"G4", 1, "~my"}, n: {"G4", 3, "strength."}],
      # 58  The
      [rest: 3.5, n: {"E4", 0.5, "The"}],
      # 59  joy of the Lord, the
      [
        n: {"G4", 0.75, "joy"},
        n: {"G4", 0.75, "of"},
        n: {"G4", 0.5, "the"},
        n: {"G4", 1, "Lord,"},
        rest: 0.5,
        n: {"G4", 0.5, "the"}
      ],
      # 60  joy of the Lord is my
      [
        n: {"G4", 0.75, "joy"},
        n: {"A4", 0.75, "of"},
        n: {"C5", 0.5, "the"},
        n: {"C5", 0.75, "Lord"},
        n: {"A4", 0.75, "is"},
        n: {"G4", 0.5, "my"}
      ],
      # 61  (my) strength.
      [n: {"G4", 1, "~my"}, n: {"G4", 3, "strength."}],
      # 62  O
      [rest: 3.5, n: {"G4", 0.5, "O"}],
      # 63  (O) my soul, bless
      [
        n: {"G4", 0.5, "~O"},
        n: {"G4", 1, "my"},
        n: {"G4", 1.5, "soul,"},
        rest: 0.5,
        n: {"B4", 0.5, "bless"}
      ],
      # 64  (bless) His Name, all
      [
        n: {"B4", 0.5, "~bless"},
        n: {"B4", 1, "His"},
        n: {"B4", 1.5, "Name,"},
        rest: 0.5,
        n: {"C5", 0.5, "all"}
      ],
      # 65  (all) that is with-in
      [
        n: {"C5", 0.5, "~all"},
        n: {"C5", 1, "that"},
        n: {"C5", 1.5, "is"},
        n: {"G4", 0.5, "with-"},
        n: {"D5", 0.5, "in"}
      ],
      # 66  (in) me say: The
      [
        n: {"D5", 0.5, "~in"},
        n: {"C5", 1, "me"},
        n: {"A4", 1.5, "say:"},
        rest: 0.5,
        n: {"E4", 0.5, "The"}
      ],
      # 67  joy of the Lord, the
      [
        n: {"G4", 0.75, "joy"},
        n: {"G4", 0.75, "of"},
        n: {"G4", 0.5, "the"},
        n: {"G4", 1, "Lord,"},
        rest: 0.5,
        n: {"G4", 0.5, "the"}
      ],
      # 68  joy of the Lord is my
      [
        n: {"G4", 0.75, "joy"},
        n: {"A4", 0.75, "of"},
        n: {"C5", 0.5, "the"},
        n: {"C5", 0.75, "Lord"},
        n: {"A4", 0.75, "is"},
        n: {"G4", 0.5, "my"}
      ],
      # 69  (my) strength.
      [n: {"G4", 1, "~my"}, n: {"G4", 3, "strength."}],
      # 70  (turn)
      [rest: 4],
      # 71  (turn)
      [rest: 4],
      # 72  (turn)
      [rest: 4],
      # 73  (turn)
      [rest: 4],
      # 74  (turn)
      [rest: 4],
      # 75  (turn)
      [rest: 4],
      # 76  unison: Let it rise
      [rest: 1.5, n: {"F4", 1, "Let"}, n: {"E4", 1, "it"}, n: {"E4", 0.5, "rise"}],
      # 77  bridge: (rise) up
      [n: {"E4", 1.5, "~rise"}, n: {"D4", 2.5, "up"}],
      # 78  like a riv-
      [rest: 1.5, n: {"E4", 1, "like"}, n: {"D4", 1, "a"}, n: {"D4", 0.5, "riv-"}],
      # 79  (riv-) er,
      [n: {"D4", 1.5, "~riv-"}, n: {"C4", 2.5, "er,"}],
      # 80  o-ver-flow-
      [rest: 1.5, n: {"F4", 1, "o-"}, n: {"E4", 1, "ver-"}, n: {"E4", 0.5, "flow-"}],
      # 81  (flow-) ing
      [n: {"E4", 1.5, "~flow-"}, n: {"D4", 2.5, "ing"}],
      # 82  Ho-ly Spir-
      [rest: 1.5, n: {"E4", 1, "Ho-"}, n: {"D4", 1, "ly"}, n: {"D4", 0.5, "Spir-"}],
      # 83  (Spir-) it.
      [n: {"D4", 1.5, "~Spir-"}, n: {"C4", 2.5, "it."}],
      # 84  Let it pour
      [rest: 1.5, n: {"F4", 1, "Let"}, n: {"E4", 1, "it"}, n: {"E4", 0.5, "pour"}],
      # 85  (pour) out
      [n: {"E4", 1.5, "~pour"}, n: {"D4", 2.5, "out"}],
      # 86  with no lim-
      [rest: 1.5, n: {"E4", 1, "with"}, n: {"D4", 1, "no"}, n: {"D4", 0.5, "lim-"}],
      # 87  (lim-) it,
      [n: {"D4", 1.5, "~lim-"}, n: {"C4", 2.5, "it,"}],
      # 88  o-ver-flow-
      [rest: 1.5, n: {"F4", 1, "o-"}, n: {"E4", 1, "ver-"}, n: {"E4", 0.5, "flow-"}],
      # 89  (flow-) ing
      [n: {"E4", 1.5, "~flow-"}, n: {"D4", 2.5, "ing"}],
      # 90  Ho-ly Spir-
      [rest: 1.5, n: {"E4", 1, "Ho-"}, n: {"D4", 1, "ly"}, n: {"D4", 0.5, "Spir-"}],
      # 91  (Spir-) it.
      [n: {"D4", 1.5, "~Spir-"}, n: {"C4", 2.5, "it."}],
      # 92  divided: Let it rise
      [rest: 1.5, n: {"D5", 1, "Let"}, n: {"C5", 1, "it"}, n: {"C5", 0.5, "rise"}],
      # 93  bridge 2: (rise) up
      [n: {"C5", 1.5, "~rise"}, n: {"B4", 2.5, "up"}],
      # 94  like a riv-
      [rest: 1.5, n: {"C5", 1, "like"}, n: {"A4", 1, "a"}, n: {"A4", 0.5, "riv-"}],
      # 95  (riv-) er,
      [n: {"A4", 1.5, "~riv-"}, n: {"G4", 2.5, "er,"}],
      # 96  o-ver-flow-
      [rest: 1.5, n: {"D5", 1, "o-"}, n: {"C5", 1, "ver-"}, n: {"C5", 0.5, "flow-"}],
      # 97  (flow-) ing
      [n: {"C5", 1.5, "~flow-"}, n: {"B4", 2.5, "ing"}],
      # 98  Ho-ly Spir-
      [rest: 1.5, n: {"C5", 1, "Ho-"}, n: {"A4", 1, "ly"}, n: {"A4", 0.5, "Spir-"}],
      # 99  (Spir-) it.
      [n: {"A4", 1.5, "~Spir-"}, n: {"G4", 2.5, "it."}],
      # 100  Let it pour
      [rest: 1.5, n: {"D5", 1, "Let"}, n: {"C5", 1, "it"}, n: {"C5", 0.5, "pour"}],
      # 101  (pour) out
      [n: {"C5", 1.5, "~pour"}, n: {"B4", 2.5, "out"}],
      # 102  with no lim-
      [rest: 1.5, n: {"C5", 1, "with"}, n: {"A4", 1, "no"}, n: {"A4", 0.5, "lim-"}],
      # 103  (lim-) it,
      [n: {"A4", 1.5, "~lim-"}, n: {"G4", 2.5, "it,"}],
      # 104  o-ver-flow-
      [rest: 1.5, n: {"D5", 1, "o-"}, n: {"C5", 1, "ver-"}, n: {"C5", 0.5, "flow-"}],
      # 105  (flow-) ing
      [n: {"C5", 1.5, "~flow-"}, n: {"B4", 2.5, "ing"}],
      # 106  Ho-ly Spir-
      [rest: 1.5, n: {"C5", 1, "Ho-"}, n: {"A4", 1, "ly"}, n: {"A4", 0.5, "Spir-"}],
      # 107  (Spir-) it.
      [n: {"A4", 1.5, "~Spir-"}, n: {"G4", 2.5, "it."}],
      # 108  (it.)
      [n: {"G4", 3, "~it."}, rest: 1],
      # 109  verse 3, unison: He rules the
      [n: {"C5", 2, "He"}, n: {"B4", 1.5, "rules"}, n: {"A4", 0.5, "the"}],
      # 110  world with
      [n: {"G4", 2, "world"}, rest: 1, n: {"F4", 1, "with"}],
      # 111  truth and
      [n: {"E4", 2, "truth"}, n: {"D4", 2, "and"}],
      # 112  grace, and
      [n: {"C4", 2, "grace,"}, rest: 1, n: {"G4", 1, "and"}],
      # 113  makes the
      [n: {"A4", 2, "makes"}, rest: 1, n: {"A4", 1, "the"}],
      # 114  na-tions
      [n: {"B4", 3, "na-"}, n: {"B4", 1, "tions"}],
      # 115  prove
      [n: {"C5", 4, "prove"}],
      # 116  the
      [rest: 3, n: {"C5", 1, "the"}],
      # 117  glo-ries
      [n: {"C5", 1, "glo-"}, n: {"B4", 1, "~glo-"}, n: {"A4", 1, "ries"}, n: {"G4", 1, "~ries"}],
      # 118  of His
      [
        n: {"G4", 1.5, "of"},
        n: {"F4", 0.5, "~of"},
        n: {"E4", 0.5, "~of"},
        rest: 0.5,
        n: {"C5", 1, "His"}
      ],
      # 119  right-eous-
      [
        n: {"C5", 1, "right-"},
        n: {"B4", 1, "~right-"},
        n: {"A4", 1, "eous-"},
        n: {"G4", 1, "~eous-"}
      ],
      # 120  ness, and
      [
        n: {"G4", 1.5, "ness,"},
        n: {"F4", 0.5, "~ness,"},
        n: {"E4", 0.5, "~ness,"},
        rest: 0.5,
        n: {"E4", 1, "and"}
      ],
      # 121  won-ders of His
      [n: {"E4", 1, "won-"}, n: {"E4", 1, "ders"}, n: {"E4", 1, "of"}, n: {"F4", 1, "His"}],
      # 122  love, and
      [n: {"G4", 2, "love,"}, rest: 1, n: {"F4", 0.5, "and"}, n: {"E4", 0.5, "~and"}],
      # 123  won-ders of His
      [n: {"D4", 1, "won-"}, n: {"D4", 1, "ders"}, n: {"D4", 1, "of"}, n: {"E4", 1, "His"}],
      # 124  love, and
      [n: {"F4", 2, "love,"}, rest: 1, n: {"E4", 0.5, "and"}, n: {"D4", 0.5, "~and"}],
      # 125  won-ders,
      [n: {"C4", 1, "won-"}, n: {"C5", 2, "~won-"}, n: {"A4", 1, "ders,"}],
      # 126  won-ders
      [
        n: {"G4", 1.5, "won-"},
        n: {"F4", 0.5, "~won-"},
        n: {"E4", 1, "~won-"},
        n: {"F4", 1, "ders"}
      ],
      # 127  of His
      [n: {"E4", 2, "of"}, n: {"D4", 2, "His"}],
      # 128  love.  (divided: upper E4, lower C4)
      [n: {"E4", 4, "love."}],
      # 129  The
      [rest: 3.5, n: {"E4", 0.5, "The"}],
      # 130  chorus: joy of the Lord, the
      [
        n: {"G4", 0.75, "joy"},
        n: {"G4", 0.75, "of"},
        n: {"G4", 0.5, "the"},
        n: {"G4", 1, "Lord,"},
        rest: 0.5,
        n: {"G4", 0.5, "the"}
      ],
      # 131  joy of the Lord is my
      [
        n: {"G4", 0.75, "joy"},
        n: {"A4", 0.75, "of"},
        n: {"C5", 0.5, "the"},
        n: {"C5", 0.75, "Lord"},
        n: {"A4", 0.75, "is"},
        n: {"G4", 0.5, "my"}
      ],
      # 132  (my) strength.
      [n: {"G4", 1, "~my"}, n: {"G4", 3, "strength."}],
      # 133  The
      [rest: 3.5, n: {"E4", 0.5, "The"}],
      # 134  joy of the Lord, the
      [
        n: {"G4", 0.75, "joy"},
        n: {"G4", 0.75, "of"},
        n: {"G4", 0.5, "the"},
        n: {"G4", 1, "Lord,"},
        rest: 0.5,
        n: {"G4", 0.5, "the"}
      ],
      # 135  joy of the Lord is my
      [
        n: {"G4", 0.75, "joy"},
        n: {"A4", 0.75, "of"},
        n: {"C5", 0.5, "the"},
        n: {"C5", 0.75, "Lord"},
        n: {"A4", 0.75, "is"},
        n: {"G4", 0.5, "my"}
      ],
      # 136  (my) strength.
      [n: {"G4", 1, "~my"}, n: {"G4", 3, "strength."}],
      # 137  O
      [rest: 3.5, n: {"G4", 0.5, "O"}],
      # 138  (O) my soul, bless
      [
        n: {"G4", 0.5, "~O"},
        n: {"G4", 1, "my"},
        n: {"G4", 1.5, "soul,"},
        rest: 0.5,
        n: {"B4", 0.5, "bless"}
      ],
      # 139  (bless) His Name, all
      [
        n: {"B4", 0.5, "~bless"},
        n: {"B4", 1, "His"},
        n: {"B4", 1.5, "Name,"},
        rest: 0.5,
        n: {"C5", 0.5, "all"}
      ],
      # 140  (all) that is with-in
      [
        n: {"C5", 0.5, "~all"},
        n: {"C5", 1, "that"},
        n: {"C5", 1.5, "is"},
        n: {"G4", 0.5, "with-"},
        n: {"D5", 0.5, "in"}
      ],
      # 141  (in) me say: O
      [
        n: {"D5", 0.5, "~in"},
        n: {"C5", 1, "me"},
        n: {"A4", 1.5, "say:"},
        rest: 0.5,
        n: {"G4", 0.5, "O"}
      ],
      # 142  tag: (O) my soul, bless
      [
        n: {"G4", 0.5, "~O"},
        n: {"G4", 1, "my"},
        n: {"G4", 1.5, "soul,"},
        rest: 0.5,
        n: {"B4", 0.5, "bless"}
      ],
      # 143  (bless) His Name, all
      [
        n: {"B4", 0.5, "~bless"},
        n: {"B4", 1, "His"},
        n: {"B4", 1.5, "Name,"},
        rest: 0.5,
        n: {"C5", 0.5, "all"}
      ],
      # 144  (all) that is with-in
      [
        n: {"C5", 0.5, "~all"},
        n: {"C5", 1, "that"},
        n: {"C5", 1.5, "is"},
        n: {"G4", 0.5, "with-"},
        n: {"D5", 0.5, "in"}
      ],
      # 145  (in) me say: O
      [
        n: {"D5", 0.5, "~in"},
        n: {"C5", 1, "me"},
        n: {"A4", 1.5, "say:"},
        rest: 0.5,
        n: {"G4", 0.5, "O"}
      ],
      # 146  (O) my soul, bless
      [
        n: {"G4", 0.5, "~O"},
        n: {"G4", 1, "my"},
        n: {"G4", 1.5, "soul,"},
        rest: 0.5,
        n: {"B4", 0.5, "bless"}
      ],
      # 147  (bless) His Name, all
      [
        n: {"B4", 0.5, "~bless"},
        n: {"B4", 1, "His"},
        n: {"B4", 1.5, "Name,"},
        rest: 0.5,
        n: {"C5", 0.5, "all"}
      ],
      # 148  (all) that is with-in
      [
        n: {"C5", 0.5, "~all"},
        n: {"C5", 1, "that"},
        n: {"C5", 1.5, "is"},
        n: {"G4", 0.5, "with-"},
        n: {"D5", 0.5, "in"}
      ],
      # 149  (in) me say: The
      [
        n: {"D5", 0.5, "~in"},
        n: {"C5", 1, "me"},
        n: {"A4", 1.5, "say:"},
        rest: 0.5,
        n: {"E4", 0.5, "The"}
      ],
      # 150  joy of the Lord, the
      [
        n: {"G4", 0.75, "joy"},
        n: {"G4", 0.75, "of"},
        n: {"G4", 0.5, "the"},
        n: {"G4", 1, "Lord,"},
        rest: 0.5,
        n: {"G4", 0.5, "the"}
      ],
      # 151  joy of the Lord is my
      [
        n: {"G4", 0.75, "joy"},
        n: {"A4", 0.75, "of"},
        n: {"C5", 0.5, "the"},
        n: {"C5", 0.75, "Lord"},
        n: {"A4", 0.75, "is"},
        n: {"G4", 0.5, "my"}
      ],
      # 152  outro: (my) strength.
      [n: {"G4", 1, "~my"}, n: {"G4", 3, "strength."}],
      # 153  (piano)
      [rest: 4],
      # 154  (solo)
      [rest: 4],
      # 155  (solo)
      [rest: 4],
      # 156  (solo)
      [rest: 4],
      # 157  (solo)
      [rest: 4],
      # 158  (piano)
      [rest: 4],
      # 159  (piano, rit.)
      [rest: 4],
      # 160  (piano, fermata)
      [rest: 4]
    ]
  end

  defp alto_bars do
    [
      # 1  (piano)
      [rest: 4],
      # 2  (piano)
      [rest: 4],
      # 3  (piano)
      [rest: 4],
      # 4  (piano)
      [rest: 4],
      # 5  (piano)
      [rest: 4],
      # 6  (piano)
      [rest: 4],
      # 7  (piano)
      [rest: 4],
      # 8  (piano)
      [rest: 4],
      # 9  (piano)
      [rest: 4],
      # 10  (piano)
      [rest: 4],
      # 11  (piano)
      [rest: 4],
      # 12  (piano)
      [rest: 4],
      # 13  unison: 1. Joy to the
      [n: {"C5", 2, "Joy"}, n: {"B4", 1.5, "to"}, n: {"A4", 0.5, "the"}],
      # 14  world, the
      [n: {"G4", 2, "world,"}, rest: 1, n: {"F4", 1, "the"}],
      # 15  Lord is
      [n: {"E4", 2, "Lord"}, n: {"D4", 2, "is"}],
      # 16  come, let
      [n: {"C4", 2, "come,"}, rest: 1, n: {"G4", 1, "let"}],
      # 17  earth re-
      [n: {"A4", 2, "earth"}, rest: 1, n: {"A4", 1, "re-"}],
      # 18  ceive her
      [n: {"B4", 3, "ceive"}, n: {"B4", 1, "her"}],
      # 19  King.
      [n: {"C5", 4, "King."}],
      # 20  Let
      [rest: 3, n: {"C5", 1, "Let"}],
      # 21  ev-'ry
      [n: {"C5", 1, "ev-"}, n: {"B4", 1, "~ev-"}, n: {"A4", 1, "'ry"}, n: {"G4", 1, "~'ry"}],
      # 22  heart pre-
      [
        n: {"G4", 1.5, "heart"},
        n: {"F4", 0.5, "~heart"},
        n: {"E4", 0.5, "~heart"},
        rest: 0.5,
        n: {"C5", 1, "pre-"}
      ],
      # 23  pare Him
      [n: {"C5", 1, "pare"}, n: {"B4", 1, "~pare"}, n: {"A4", 1, "Him"}, n: {"G4", 1, "~Him"}],
      # 24  room, and
      [
        n: {"G4", 1.5, "room,"},
        n: {"F4", 0.5, "~room,"},
        n: {"E4", 0.5, "~room,"},
        rest: 0.5,
        n: {"E4", 1, "and"}
      ],
      # 25  Heav-en and na-ture
      [
        n: {"E4", 0.5, "Heav-"},
        n: {"E4", 0.5, "en"},
        n: {"E4", 1, "and"},
        n: {"E4", 1, "na-"},
        n: {"F4", 1, "ture"}
      ],
      # 26  sing, and
      [n: {"G4", 2, "sing,"}, rest: 1, n: {"F4", 0.5, "and"}, n: {"E4", 0.5, "~and"}],
      # 27  Heav-en and na-ture
      [
        n: {"D4", 0.5, "Heav-"},
        n: {"D4", 0.5, "en"},
        n: {"D4", 1, "and"},
        n: {"D4", 1, "na-"},
        n: {"E4", 1, "ture"}
      ],
      # 28  sing, and
      [n: {"F4", 2, "sing,"}, rest: 1, n: {"E4", 0.5, "and"}, n: {"D4", 0.5, "~and"}],
      # 29  Heav-en and
      [n: {"C4", 1, "Heav-"}, n: {"C5", 2, "en"}, n: {"A4", 1, "and"}],
      # 30  Heav-en and
      [
        n: {"G4", 1.5, "Heav-"},
        n: {"F4", 0.5, "~Heav-"},
        n: {"E4", 1, "en"},
        n: {"F4", 1, "and"}
      ],
      # 31  na-ture
      [n: {"E4", 2, "na-"}, n: {"D4", 2, "ture"}],
      # 32  sing.
      [n: {"C4", 4, "sing."}],
      # 33  (turn)
      [rest: 4],
      # 34  (turn)
      [rest: 4],
      # 35  (turn)
      [rest: 4],
      # 36  2. Joy to the
      [n: {"G4", 2, "Joy"}, n: {"G4", 1.5, "to"}, n: {"F4", 0.5, "the"}],
      # 37  Earth, the
      [n: {"E4", 2, "Earth,"}, rest: 1, n: {"C4", 1, "the"}],
      # 38  Sav-ior
      [n: {"C4", 2, "Sav-"}, n: {"A3", 2, "ior"}],
      # 39  reigns, let
      [n: {"G3", 2, "reigns,"}, rest: 1, n: {"E4", 1, "let"}],
      # 40  all, their
      [n: {"F4", 2, "all,"}, rest: 1, n: {"F4", 1, "their"}],
      # 41  songs em-
      [n: {"G4", 3, "songs"}, n: {"G4", 1, "em-"}],
      # 42  ploy,
      [n: {"G4", 4, "ploy,"}],
      # 43  while
      [rest: 3, n: {"G4", 1, "while"}],
      # 44  fields and
      [n: {"G4", 2, "fields"}, n: {"F4", 1, "and"}, n: {"E4", 1, "~and"}],
      # 45  floods, rocks,
      [
        n: {"E4", 1.5, "floods,"},
        n: {"D4", 0.5, "~floods,"},
        n: {"C4", 0.5, "~floods,"},
        rest: 0.5,
        n: {"G4", 1, "rocks,"}
      ],
      # 46  hills and
      [n: {"G4", 2, "hills"}, n: {"F4", 1, "and"}, n: {"E4", 1, "~and"}],
      # 47  plains re-
      [
        n: {"E4", 1.5, "plains"},
        n: {"D4", 0.5, "~plains"},
        n: {"C4", 0.5, "~plains"},
        rest: 0.5,
        n: {"C4", 1, "re-"}
      ],
      # 48  peat the sound-ing
      [n: {"C4", 1, "peat"}, n: {"C4", 1, "the"}, n: {"C4", 1, "sound-"}, n: {"D4", 1, "ing"}],
      # 49  joy, re-
      [n: {"E4", 2, "joy,"}, rest: 1, n: {"D4", 0.5, "re-"}, n: {"C4", 0.5, "~re-"}],
      # 50  peat the sound-ing
      [n: {"B3", 1, "peat"}, n: {"B3", 1, "the"}, n: {"B3", 1, "sound-"}, n: {"C4", 1, "ing"}],
      # 51  joy, re-  (unison eighths)
      [n: {"D4", 2, "joy,"}, rest: 1, n: {"E4", 0.5, "re-"}, n: {"D4", 0.5, "~re-"}],
      # 52  unison: peat, re-
      [n: {"C4", 1, "peat,"}, n: {"C5", 2, "~peat,"}, n: {"A4", 1, "re-"}],
      # 53  peat, the sound-
      [
        n: {"G4", 1.5, "peat,"},
        n: {"F4", 0.5, "~peat,"},
        n: {"E4", 1, "the"},
        n: {"F4", 1, "sound-"}
      ],
      # 54  -ing... The  (tenor has the tune, "mel.")
      [n: {"E4", 2, "~sound-"}, n: {"D4", 1, "ing"}, rest: 0.5, n: {"C4", 0.5, "The"}],
      # 55  joy of the Lord, the
      [
        n: {"E4", 0.75, "joy"},
        n: {"E4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 1, "Lord,"},
        rest: 0.5,
        n: {"E4", 0.5, "the"}
      ],
      # 56  joy of the Lord is my
      [
        n: {"E4", 0.75, "joy"},
        n: {"F4", 0.75, "of"},
        n: {"G4", 0.5, "the"},
        n: {"G4", 0.75, "Lord"},
        n: {"F4", 0.75, "is"},
        n: {"E4", 0.5, "my"}
      ],
      # 57  strength.
      [n: {"E4", 1, "~my"}, n: {"E4", 3, "strength."}],
      # 58  The
      [rest: 3.5, n: {"C4", 0.5, "The"}],
      # 59  joy of the Lord, the
      [
        n: {"E4", 0.75, "joy"},
        n: {"E4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 1, "Lord,"},
        rest: 0.5,
        n: {"E4", 0.5, "the"}
      ],
      # 60  joy of the Lord is my
      [
        n: {"E4", 0.75, "joy"},
        n: {"F4", 0.75, "of"},
        n: {"G4", 0.5, "the"},
        n: {"G4", 0.75, "Lord"},
        n: {"F4", 0.75, "is"},
        n: {"E4", 0.5, "my"}
      ],
      # 61  strength.
      [n: {"E4", 1, "~my"}, n: {"E4", 3, "strength."}],
      # 62  O
      [rest: 3.5, n: {"E4", 0.5, "O"}],
      # 63  my soul, bless
      [
        n: {"E4", 0.5, "~O"},
        n: {"E4", 1, "my"},
        n: {"E4", 1.5, "soul,"},
        rest: 0.5,
        n: {"G4", 0.5, "bless"}
      ],
      # 64  His Name, all
      [
        n: {"G4", 0.5, "~bless"},
        n: {"G4", 1, "His"},
        n: {"G4", 1.5, "Name,"},
        rest: 0.5,
        n: {"G4", 0.5, "all"}
      ],
      # 65  that is with-in
      [
        n: {"G4", 0.5, "~all"},
        n: {"G4", 1, "that"},
        n: {"G4", 1.5, "is"},
        n: {"E4", 0.5, "with-"},
        n: {"A4", 0.5, "in"}
      ],
      # 66  me say: The
      [
        n: {"A4", 0.5, "~in"},
        n: {"G4", 1, "me"},
        n: {"F4", 1.5, "say:"},
        rest: 0.5,
        n: {"C4", 0.5, "The"}
      ],
      # 67  joy of the Lord, the
      [
        n: {"E4", 0.75, "joy"},
        n: {"E4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 1, "Lord,"},
        rest: 0.5,
        n: {"E4", 0.5, "the"}
      ],
      # 68  joy of the Lord is my
      [
        n: {"E4", 0.75, "joy"},
        n: {"F4", 0.75, "of"},
        n: {"G4", 0.5, "the"},
        n: {"G4", 0.75, "Lord"},
        n: {"F4", 0.75, "is"},
        n: {"E4", 0.5, "my"}
      ],
      # 69  strength.
      [n: {"E4", 1, "~my"}, n: {"E4", 3, "strength."}],
      # 70  (turn)
      [rest: 4],
      # 71  (turn)
      [rest: 4],
      # 72  (turn)
      [rest: 4],
      # 73  (turn)
      [rest: 4],
      # 74  (turn)
      [rest: 4],
      # 75  (turn)
      [rest: 4],
      # 76  unison: Let it rise
      [rest: 1.5, n: {"F4", 1, "Let"}, n: {"E4", 1, "it"}, n: {"E4", 0.5, "rise"}],
      # 77  up
      [n: {"E4", 1.5, "~rise"}, n: {"D4", 2.5, "up"}],
      # 78  like a riv-
      [rest: 1.5, n: {"E4", 1, "like"}, n: {"D4", 1, "a"}, n: {"D4", 0.5, "riv-"}],
      # 79  -er,
      [n: {"D4", 1.5, "~riv-"}, n: {"C4", 2.5, "er,"}],
      # 80  o-ver-flow-
      [rest: 1.5, n: {"F4", 1, "o-"}, n: {"E4", 1, "ver-"}, n: {"E4", 0.5, "flow-"}],
      # 81  -ing
      [n: {"E4", 1.5, "~flow-"}, n: {"D4", 2.5, "ing"}],
      # 82  Ho-ly Spir-
      [rest: 1.5, n: {"E4", 1, "Ho-"}, n: {"D4", 1, "ly"}, n: {"D4", 0.5, "Spir-"}],
      # 83  -it.
      [n: {"D4", 1.5, "~Spir-"}, n: {"C4", 2.5, "it."}],
      # 84  Let it pour
      [rest: 1.5, n: {"F4", 1, "Let"}, n: {"E4", 1, "it"}, n: {"E4", 0.5, "pour"}],
      # 85  out
      [n: {"E4", 1.5, "~pour"}, n: {"D4", 2.5, "out"}],
      # 86  with no lim-
      [rest: 1.5, n: {"E4", 1, "with"}, n: {"D4", 1, "no"}, n: {"D4", 0.5, "lim-"}],
      # 87  -it,
      [n: {"D4", 1.5, "~lim-"}, n: {"C4", 2.5, "it,"}],
      # 88  o-ver-flow-
      [rest: 1.5, n: {"F4", 1, "o-"}, n: {"E4", 1, "ver-"}, n: {"E4", 0.5, "flow-"}],
      # 89  -ing
      [n: {"E4", 1.5, "~flow-"}, n: {"D4", 2.5, "ing"}],
      # 90  Ho-ly Spir-
      [rest: 1.5, n: {"E4", 1, "Ho-"}, n: {"D4", 1, "ly"}, n: {"D4", 0.5, "Spir-"}],
      # 91  -it.
      [n: {"D4", 1.5, "~Spir-"}, n: {"C4", 2.5, "it."}],
      # 92  divided: Let it rise
      [rest: 1.5, n: {"A4", 1, "Let"}, n: {"G4", 1, "it"}, n: {"G4", 0.5, "rise"}],
      # 93  up
      [n: {"G4", 1.5, "~rise"}, n: {"G4", 2.5, "up"}],
      # 94  like a riv-
      [rest: 1.5, n: {"G4", 1, "like"}, n: {"F4", 1, "a"}, n: {"F4", 0.5, "riv-"}],
      # 95  -er,
      [n: {"F4", 1.5, "~riv-"}, n: {"E4", 2.5, "er,"}],
      # 96  o-ver-flow-
      [rest: 1.5, n: {"A4", 1, "o-"}, n: {"G4", 1, "ver-"}, n: {"G4", 0.5, "flow-"}],
      # 97  -ing
      [n: {"G4", 1.5, "~flow-"}, n: {"G4", 2.5, "ing"}],
      # 98  Ho-ly Spir-
      [rest: 1.5, n: {"G4", 1, "Ho-"}, n: {"F4", 1, "ly"}, n: {"F4", 0.5, "Spir-"}],
      # 99  -it.
      [n: {"F4", 1.5, "~Spir-"}, n: {"E4", 2.5, "it."}],
      # 100  Let it pour
      [rest: 1.5, n: {"A4", 1, "Let"}, n: {"G4", 1, "it"}, n: {"G4", 0.5, "pour"}],
      # 101  out
      [n: {"G4", 1.5, "~pour"}, n: {"G4", 2.5, "out"}],
      # 102  with no lim-
      [rest: 1.5, n: {"G4", 1, "with"}, n: {"F4", 1, "no"}, n: {"F4", 0.5, "lim-"}],
      # 103  -it,
      [n: {"F4", 1.5, "~lim-"}, n: {"E4", 2.5, "it,"}],
      # 104  o-ver-flow-
      [rest: 1.5, n: {"A4", 1, "o-"}, n: {"G4", 1, "ver-"}, n: {"G4", 0.5, "flow-"}],
      # 105  -ing
      [n: {"G4", 1.5, "~flow-"}, n: {"G4", 2.5, "ing"}],
      # 106  Ho-ly Spir-
      [rest: 1.5, n: {"G4", 1, "Ho-"}, n: {"F4", 1, "ly"}, n: {"F4", 0.5, "Spir-"}],
      # 107  -it.
      [n: {"F4", 1.5, "~Spir-"}, n: {"E4", 2.5, "it."}],
      # 108  (held)
      [n: {"E4", 3, "~it."}, rest: 1],
      # 109  unison: 3. He rules the
      [n: {"C5", 2, "He"}, n: {"B4", 1.5, "rules"}, n: {"A4", 0.5, "the"}],
      # 110  world with
      [n: {"G4", 2, "world"}, rest: 1, n: {"F4", 1, "with"}],
      # 111  truth and
      [n: {"E4", 2, "truth"}, n: {"D4", 2, "and"}],
      # 112  grace, and
      [n: {"C4", 2, "grace,"}, rest: 1, n: {"G4", 1, "and"}],
      # 113  makes the
      [n: {"A4", 2, "makes"}, rest: 1, n: {"A4", 1, "the"}],
      # 114  na-tions
      [n: {"B4", 3, "na-"}, n: {"B4", 1, "tions"}],
      # 115  prove
      [n: {"C5", 4, "prove"}],
      # 116  the
      [rest: 3, n: {"C5", 1, "the"}],
      # 117  glo-ries
      [n: {"C5", 1, "glo-"}, n: {"B4", 1, "~glo-"}, n: {"A4", 1, "ries"}, n: {"G4", 1, "~ries"}],
      # 118  of His
      [
        n: {"G4", 1.5, "of"},
        n: {"F4", 0.5, "~of"},
        n: {"E4", 0.5, "~of"},
        rest: 0.5,
        n: {"C5", 1, "His"}
      ],
      # 119  right-eous-
      [
        n: {"C5", 1, "right-"},
        n: {"B4", 1, "~right-"},
        n: {"A4", 1, "eous-"},
        n: {"G4", 1, "~eous-"}
      ],
      # 120  ness, and
      [
        n: {"G4", 1.5, "ness,"},
        n: {"F4", 0.5, "~ness,"},
        n: {"E4", 0.5, "~ness,"},
        rest: 0.5,
        n: {"E4", 1, "and"}
      ],
      # 121  won-ders of His
      [n: {"E4", 1, "won-"}, n: {"E4", 1, "ders"}, n: {"E4", 1, "of"}, n: {"F4", 1, "His"}],
      # 122  love, and
      [n: {"G4", 2, "love,"}, rest: 1, n: {"F4", 0.5, "and"}, n: {"E4", 0.5, "~and"}],
      # 123  won-ders of His
      [n: {"D4", 1, "won-"}, n: {"D4", 1, "ders"}, n: {"D4", 1, "of"}, n: {"E4", 1, "His"}],
      # 124  love, and
      [n: {"F4", 2, "love,"}, rest: 1, n: {"E4", 0.5, "and"}, n: {"D4", 0.5, "~and"}],
      # 125  won-ders,
      [n: {"C4", 1, "won-"}, n: {"C5", 2, "~won-"}, n: {"A4", 1, "ders,"}],
      # 126  won-ders
      [
        n: {"G4", 1.5, "won-"},
        n: {"F4", 0.5, "~won-"},
        n: {"E4", 1, "~won-"},
        n: {"F4", 1, "ders"}
      ],
      # 127  of His
      [n: {"E4", 2, "of"}, n: {"D4", 2, "His"}],
      # 128  divided: love.
      [n: {"C4", 4, "love."}],
      # 129  The
      [rest: 3.5, n: {"C4", 0.5, "The"}],
      # 130  joy of the Lord, the
      [
        n: {"E4", 0.75, "joy"},
        n: {"E4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 1, "Lord,"},
        rest: 0.5,
        n: {"E4", 0.5, "the"}
      ],
      # 131  joy of the Lord is my
      [
        n: {"E4", 0.75, "joy"},
        n: {"F4", 0.75, "of"},
        n: {"G4", 0.5, "the"},
        n: {"G4", 0.75, "Lord"},
        n: {"F4", 0.75, "is"},
        n: {"E4", 0.5, "my"}
      ],
      # 132  strength.
      [n: {"E4", 1, "~my"}, n: {"E4", 3, "strength."}],
      # 133  The
      [rest: 3.5, n: {"C4", 0.5, "The"}],
      # 134  joy of the Lord, the
      [
        n: {"E4", 0.75, "joy"},
        n: {"E4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 1, "Lord,"},
        rest: 0.5,
        n: {"E4", 0.5, "the"}
      ],
      # 135  joy of the Lord is my
      [
        n: {"E4", 0.75, "joy"},
        n: {"F4", 0.75, "of"},
        n: {"G4", 0.5, "the"},
        n: {"G4", 0.75, "Lord"},
        n: {"F4", 0.75, "is"},
        n: {"E4", 0.5, "my"}
      ],
      # 136  strength.
      [n: {"E4", 1, "~my"}, n: {"E4", 3, "strength."}],
      # 137  O
      [rest: 3.5, n: {"E4", 0.5, "O"}],
      # 138  my soul, bless
      [
        n: {"E4", 0.5, "~O"},
        n: {"E4", 1, "my"},
        n: {"E4", 1.5, "soul,"},
        rest: 0.5,
        n: {"G4", 0.5, "bless"}
      ],
      # 139  His Name, all
      [
        n: {"G4", 0.5, "~bless"},
        n: {"G4", 1, "His"},
        n: {"G4", 1.5, "Name,"},
        rest: 0.5,
        n: {"G4", 0.5, "all"}
      ],
      # 140  that is with-in
      [
        n: {"G4", 0.5, "~all"},
        n: {"G4", 1, "that"},
        n: {"G4", 1.5, "is"},
        n: {"E4", 0.5, "with-"},
        n: {"A4", 0.5, "in"}
      ],
      # 141  me say: O
      [
        n: {"A4", 0.5, "~in"},
        n: {"G4", 1, "me"},
        n: {"F4", 1.5, "say:"},
        rest: 0.5,
        n: {"E4", 0.5, "O"}
      ],
      # 142  (tag) my soul, bless
      [
        n: {"E4", 0.5, "~O"},
        n: {"E4", 1, "my"},
        n: {"E4", 1.5, "soul,"},
        rest: 0.5,
        n: {"G4", 0.5, "bless"}
      ],
      # 143  His Name, all
      [
        n: {"G4", 0.5, "~bless"},
        n: {"G4", 1, "His"},
        n: {"G4", 1.5, "Name,"},
        rest: 0.5,
        n: {"G4", 0.5, "all"}
      ],
      # 144  that is with-in
      [
        n: {"G4", 0.5, "~all"},
        n: {"G4", 1, "that"},
        n: {"G4", 1.5, "is"},
        n: {"E4", 0.5, "with-"},
        n: {"A4", 0.5, "in"}
      ],
      # 145  me say: O
      [
        n: {"A4", 0.5, "~in"},
        n: {"G4", 1, "me"},
        n: {"F4", 1.5, "say:"},
        rest: 0.5,
        n: {"E4", 0.5, "O"}
      ],
      # 146  my soul, bless
      [
        n: {"E4", 0.5, "~O"},
        n: {"E4", 1, "my"},
        n: {"E4", 1.5, "soul,"},
        rest: 0.5,
        n: {"G4", 0.5, "bless"}
      ],
      # 147  His Name, all
      [
        n: {"G4", 0.5, "~bless"},
        n: {"G4", 1, "His"},
        n: {"G4", 1.5, "Name,"},
        rest: 0.5,
        n: {"G4", 0.5, "all"}
      ],
      # 148  that is with-in
      [
        n: {"G4", 0.5, "~all"},
        n: {"G4", 1, "that"},
        n: {"G4", 1.5, "is"},
        n: {"E4", 0.5, "with-"},
        n: {"A4", 0.5, "in"}
      ],
      # 149  me say: The
      [
        n: {"A4", 0.5, "~in"},
        n: {"G4", 1, "me"},
        n: {"F4", 1.5, "say:"},
        rest: 0.5,
        n: {"C4", 0.5, "The"}
      ],
      # 150  joy of the Lord, the
      [
        n: {"E4", 0.75, "joy"},
        n: {"E4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 1, "Lord,"},
        rest: 0.5,
        n: {"E4", 0.5, "the"}
      ],
      # 151  joy of the Lord is my
      [
        n: {"E4", 0.75, "joy"},
        n: {"F4", 0.75, "of"},
        n: {"G4", 0.5, "the"},
        n: {"G4", 0.75, "Lord"},
        n: {"F4", 0.75, "is"},
        n: {"E4", 0.5, "my"}
      ],
      # 152  strength.
      [n: {"E4", 1, "~my"}, n: {"E4", 3, "strength."}],
      # 153  (outro)
      [rest: 4],
      # 154  (solo)
      [rest: 4],
      # 155  (solo)
      [rest: 4],
      # 156  (solo)
      [rest: 4],
      # 157  (solo)
      [rest: 4],
      # 158  (piano)
      [rest: 4],
      # 159  (piano, rit.)
      [rest: 4],
      # 160  (piano, fermata)
      [rest: 4]
    ]
  end

  defp tenor_bars do
    [
      # 1  (intro)
      [rest: 4],
      # 2
      [rest: 4],
      # 3
      [rest: 4],
      # 4
      [rest: 4],
      # 5
      [rest: 4],
      # 6
      [rest: 4],
      # 7
      [rest: 4],
      # 8
      [rest: 4],
      # 9
      [rest: 4],
      # 10
      [rest: 4],
      # 11
      [rest: 4],
      # 12
      [rest: 4],
      # 13  Joy to the  (verse 1, men in unison)
      [n: {"C4", 2, "Joy"}, n: {"B3", 1.5, "to"}, n: {"A3", 0.5, "the"}],
      # 14  world, the
      [n: {"G3", 2, "world,"}, rest: 1, n: {"F3", 1, "the"}],
      # 15  Lord is
      [n: {"E3", 2, "Lord"}, n: {"D3", 2, "is"}],
      # 16  come, let
      [n: {"C3", 2, "come,"}, rest: 1, n: {"G3", 1, "let"}],
      # 17  earth re-
      [n: {"A3", 2, "earth"}, rest: 1, n: {"A3", 1, "re-"}],
      # 18  ceive her
      [n: {"B3", 3, "ceive"}, n: {"B3", 1, "her"}],
      # 19  King.
      [n: {"C4", 4, "King."}],
      # 20  Let
      [rest: 3, n: {"C4", 1, "Let"}],
      # 21  ev-'ry
      [n: {"C4", 1, "ev-"}, n: {"B3", 1, "~ev-"}, n: {"A3", 1, "'ry"}, n: {"G3", 1, "~'ry"}],
      # 22  heart pre-
      [
        n: {"G3", 1.5, "heart"},
        n: {"F3", 0.5, "~heart"},
        n: {"E3", 0.5, "~heart"},
        rest: 0.5,
        n: {"C4", 1, "pre-"}
      ],
      # 23  pare Him
      [n: {"C4", 1, "pare"}, n: {"B3", 1, "~pare"}, n: {"A3", 1, "Him"}, n: {"G3", 1, "~Him"}],
      # 24  room, and
      [
        n: {"G3", 1.5, "room,"},
        n: {"F3", 0.5, "~room,"},
        n: {"E3", 0.5, "~room,"},
        rest: 0.5,
        n: {"E3", 1, "and"}
      ],
      # 25  Heav-en and na-ture
      [
        n: {"E3", 0.5, "Heav-"},
        n: {"E3", 0.5, "en"},
        n: {"E3", 1, "and"},
        n: {"E3", 1, "na-"},
        n: {"F3", 1, "ture"}
      ],
      # 26  sing, and
      [n: {"G3", 2, "sing,"}, rest: 1, n: {"F3", 0.5, "and"}, n: {"E3", 0.5, "~and"}],
      # 27  Heav-en and na-ture
      [
        n: {"D3", 0.5, "Heav-"},
        n: {"D3", 0.5, "en"},
        n: {"D3", 1, "and"},
        n: {"D3", 1, "na-"},
        n: {"E3", 1, "ture"}
      ],
      # 28  sing, and
      [n: {"F3", 2, "sing,"}, rest: 1, n: {"E3", 0.5, "and"}, n: {"D3", 0.5, "~and"}],
      # 29  Heav-en and  (divides on "and")
      [n: {"C3", 1, "Heav-"}, n: {"C4", 2, "en"}, n: {"D4", 1, "and"}],
      # 30  Heav-en and
      [
        n: {"E4", 1.5, "Heav-"},
        n: {"F4", 0.5, "~Heav-"},
        n: {"E4", 1, "en"},
        n: {"F4", 1, "and"}
      ],
      # 31  na-ture
      [n: {"E4", 2, "na-"}, n: {"D4", 2, "ture"}],
      # 32  sing.
      [n: {"C4", 4, "sing."}],
      # 33  (turn)
      [rest: 4],
      # 34
      [rest: 4],
      # 35
      [rest: 4],
      # 36  Joy to the  (verse 2, divided)
      [n: {"E4", 2, "Joy"}, n: {"D4", 1.5, "to"}, n: {"C4", 0.5, "the"}],
      # 37  Earth, the
      [n: {"C4", 2, "Earth,"}, rest: 1, n: {"A3", 1, "the"}],
      # 38  Sav-ior
      [n: {"G3", 2, "Sav-"}, n: {"F3", 2, "ior"}],
      # 39  reigns, let
      [n: {"E3", 2, "reigns,"}, rest: 1, n: {"C4", 1, "let"}],
      # 40  all, their
      [n: {"C4", 2, "all,"}, rest: 1, n: {"C4", 1, "their"}],
      # 41  songs em-
      [n: {"D4", 3, "songs"}, n: {"D4", 1, "em-"}],
      # 42  ploy,
      [n: {"E4", 4, "ploy,"}],
      # 43  while
      [rest: 3, n: {"E4", 1, "while"}],
      # 44  fields and
      [n: {"E4", 1, "fields"}, n: {"D4", 1, "~fields"}, n: {"C4", 2, "and"}],
      # 45  floods, rocks,
      [
        n: {"C4", 1.5, "floods,"},
        n: {"A3", 0.5, "~floods,"},
        n: {"G3", 0.5, "~floods,"},
        rest: 0.5,
        n: {"E4", 1, "rocks,"}
      ],
      # 46  hills and
      [n: {"E4", 1, "hills"}, n: {"D4", 1, "~hills"}, n: {"C4", 2, "and"}],
      # 47  plains re-
      [
        n: {"C4", 1.5, "plains"},
        n: {"A3", 0.5, "~plains"},
        n: {"G3", 0.5, "~plains"},
        rest: 0.5,
        n: {"G3", 1, "re-"}
      ],
      # 48  peat the sound-ing
      [n: {"G3", 1, "peat"}, n: {"G3", 1, "the"}, n: {"G3", 1, "sound-"}, n: {"A3", 1, "ing"}],
      # 49  joy, re-
      [n: {"C4", 2, "joy,"}, rest: 1, n: {"G3", 1, "re-"}],
      # 50  peat the sound-ing  (unison)
      [n: {"G3", 1, "peat"}, n: {"G3", 1, "the"}, n: {"G3", 1, "sound-"}, n: {"G3", 1, "ing"}],
      # 51  joy, re-
      [n: {"G3", 2, "joy,"}, rest: 1, n: {"E3", 0.5, "re-"}, n: {"D3", 0.5, "~re-"}],
      # 52  peat, re-  (divides on "re-")
      [n: {"C3", 1, "peat,"}, n: {"C4", 2, "~peat,"}, n: {"D4", 1, "re-"}],
      # 53  peat, the
      [
        n: {"E4", 1.5, "peat,"},
        n: {"F4", 0.5, "~peat,"},
        n: {"E4", 1, "~peat,"},
        n: {"F4", 1, "the"}
      ],
      # 54  sound-ing... The
      [n: {"E4", 2, "sound-"}, n: {"D4", 1, "ing…"}, rest: 0.5, n: {"G3", 0.5, "The"}],
      # 55  joy of the Lord, the  (chorus)
      [
        n: {"C4", 0.75, "joy"},
        n: {"C4", 0.75, "of"},
        n: {"C4", 0.5, "the"},
        n: {"C4", 1, "Lord,"},
        rest: 0.5,
        n: {"C4", 0.5, "the"}
      ],
      # 56  joy of the Lord is my
      [
        n: {"C4", 0.75, "joy"},
        n: {"D4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 0.75, "Lord"},
        n: {"D4", 0.75, "is"},
        n: {"C4", 0.5, "my"}
      ],
      # 57  (my) strength.
      [n: {"C4", 1, "~my"}, n: {"C4", 3, "strength."}],
      # 58  The
      [rest: 3.5, n: {"G3", 0.5, "The"}],
      # 59  joy of the Lord, the
      [
        n: {"C4", 0.75, "joy"},
        n: {"C4", 0.75, "of"},
        n: {"C4", 0.5, "the"},
        n: {"C4", 1, "Lord,"},
        rest: 0.5,
        n: {"C4", 0.5, "the"}
      ],
      # 60  joy of the Lord is my
      [
        n: {"C4", 0.75, "joy"},
        n: {"D4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 0.75, "Lord"},
        n: {"D4", 0.75, "is"},
        n: {"C4", 0.5, "my"}
      ],
      # 61  (my) strength.
      [n: {"C4", 1, "~my"}, n: {"C4", 3, "strength."}],
      # 62  O
      [rest: 3.5, n: {"C4", 0.5, "O"}],
      # 63  (O) my soul, bless
      [
        n: {"C4", 0.5, "~O"},
        n: {"C4", 1, "my"},
        n: {"C4", 1.5, "soul,"},
        rest: 0.5,
        n: {"D4", 0.5, "bless"}
      ],
      # 64  (bless) His Name, all
      [
        n: {"D4", 0.5, "~bless"},
        n: {"D4", 1, "His"},
        n: {"D4", 1.5, "Name,"},
        rest: 0.5,
        n: {"E4", 0.5, "all"}
      ],
      # 65  (all) that is with-in
      [
        n: {"E4", 0.5, "~all"},
        n: {"E4", 1, "that"},
        n: {"E4", 1.5, "is"},
        n: {"C4", 0.5, "with-"},
        n: {"F4", 0.5, "in"}
      ],
      # 66  (in) me say: The
      [
        n: {"F4", 0.5, "~in"},
        n: {"E4", 1, "me"},
        n: {"D4", 1.5, "say:"},
        rest: 0.5,
        n: {"G3", 0.5, "The"}
      ],
      # 67  joy of the Lord, the
      [
        n: {"C4", 0.75, "joy"},
        n: {"C4", 0.75, "of"},
        n: {"C4", 0.5, "the"},
        n: {"C4", 1, "Lord,"},
        rest: 0.5,
        n: {"C4", 0.5, "the"}
      ],
      # 68  joy of the Lord is my
      [
        n: {"C4", 0.75, "joy"},
        n: {"D4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 0.75, "Lord"},
        n: {"D4", 0.75, "is"},
        n: {"C4", 0.5, "my"}
      ],
      # 69  (my) strength.
      [n: {"C4", 1, "~my"}, n: {"C4", 3, "strength."}],
      # 70  (turn)
      [rest: 4],
      # 71
      [rest: 4],
      # 72
      [rest: 4],
      # 73
      [rest: 4],
      # 74
      [rest: 4],
      # 75
      [rest: 4],
      # 76  Let it rise  (men in octaves; tenor upper)
      [rest: 1.5, n: {"F4", 1, "Let"}, n: {"E4", 1, "it"}, n: {"E4", 0.5, "rise"}],
      # 77  (rise) up  (bridge)
      [n: {"E4", 1.5, "~rise"}, n: {"D4", 2.5, "up"}],
      # 78  like a riv-
      [rest: 1.5, n: {"E4", 1, "like"}, n: {"D4", 1, "a"}, n: {"D4", 0.5, "riv-"}],
      # 79  (riv-)er,
      [n: {"D4", 1.5, "~riv-"}, n: {"C4", 2.5, "er,"}],
      # 80  o-ver-flow-
      [rest: 1.5, n: {"F4", 1, "o-"}, n: {"E4", 1, "ver-"}, n: {"E4", 0.5, "flow-"}],
      # 81  (flow-)ing
      [n: {"E4", 1.5, "~flow-"}, n: {"D4", 2.5, "ing"}],
      # 82  Ho-ly Spir-
      [rest: 1.5, n: {"E4", 1, "Ho-"}, n: {"D4", 1, "ly"}, n: {"D4", 0.5, "Spir-"}],
      # 83  (Spir-)it.
      [n: {"D4", 1.5, "~Spir-"}, n: {"C4", 2.5, "it."}],
      # 84  Let it pour
      [rest: 1.5, n: {"F4", 1, "Let"}, n: {"E4", 1, "it"}, n: {"E4", 0.5, "pour"}],
      # 85  (pour) out
      [n: {"E4", 1.5, "~pour"}, n: {"D4", 2.5, "out"}],
      # 86  with no lim-
      [rest: 1.5, n: {"E4", 1, "with"}, n: {"D4", 1, "no"}, n: {"D4", 0.5, "lim-"}],
      # 87  (lim-)it,
      [n: {"D4", 1.5, "~lim-"}, n: {"C4", 2.5, "it,"}],
      # 88  o-ver-flow-
      [rest: 1.5, n: {"F4", 1, "o-"}, n: {"E4", 1, "ver-"}, n: {"E4", 0.5, "flow-"}],
      # 89  (flow-)ing
      [n: {"E4", 1.5, "~flow-"}, n: {"D4", 2.5, "ing"}],
      # 90  Ho-ly Spir-
      [rest: 1.5, n: {"E4", 1, "Ho-"}, n: {"D4", 1, "ly"}, n: {"D4", 0.5, "Spir-"}],
      # 91  (Spir-)it.
      [n: {"D4", 1.5, "~Spir-"}, n: {"C4", 2.5, "it."}],
      # 92  Let it rise
      [rest: 1.5, n: {"F4", 1, "Let"}, n: {"E4", 1, "it"}, n: {"E4", 0.5, "rise"}],
      # 93  (rise) up  (bridge 2)
      [n: {"E4", 1.5, "~rise"}, n: {"D4", 2.5, "up"}],
      # 94  like a riv-
      [rest: 1.5, n: {"E4", 1, "like"}, n: {"D4", 1, "a"}, n: {"D4", 0.5, "riv-"}],
      # 95  (riv-)er,
      [n: {"D4", 1.5, "~riv-"}, n: {"C4", 2.5, "er,"}],
      # 96  o-ver-flow-
      [rest: 1.5, n: {"F4", 1, "o-"}, n: {"E4", 1, "ver-"}, n: {"E4", 0.5, "flow-"}],
      # 97  (flow-)ing
      [n: {"E4", 1.5, "~flow-"}, n: {"D4", 2.5, "ing"}],
      # 98  Ho-ly Spir-
      [rest: 1.5, n: {"E4", 1, "Ho-"}, n: {"D4", 1, "ly"}, n: {"D4", 0.5, "Spir-"}],
      # 99  (Spir-)it.
      [n: {"D4", 1.5, "~Spir-"}, n: {"C4", 2.5, "it."}],
      # 100  Let it pour
      [rest: 1.5, n: {"F4", 1, "Let"}, n: {"E4", 1, "it"}, n: {"E4", 0.5, "pour"}],
      # 101  (pour) out
      [n: {"E4", 1.5, "~pour"}, n: {"D4", 2.5, "out"}],
      # 102  with no lim-
      [rest: 1.5, n: {"E4", 1, "with"}, n: {"D4", 1, "no"}, n: {"D4", 0.5, "lim-"}],
      # 103  (lim-)it,
      [n: {"D4", 1.5, "~lim-"}, n: {"C4", 2.5, "it,"}],
      # 104  o-ver-flow-
      [rest: 1.5, n: {"F4", 1, "o-"}, n: {"E4", 1, "ver-"}, n: {"E4", 0.5, "flow-"}],
      # 105  (flow-)ing
      [n: {"E4", 1.5, "~flow-"}, n: {"D4", 2.5, "ing"}],
      # 106  Ho-ly Spir-
      [rest: 1.5, n: {"E4", 1, "Ho-"}, n: {"D4", 1, "ly"}, n: {"D4", 0.5, "Spir-"}],
      # 107  (Spir-)it.
      [n: {"D4", 1.5, "~Spir-"}, n: {"C4", 2.5, "it."}],
      # 108  (it.)
      [n: {"C4", 3, "~it."}, rest: 1],
      # 109  He rules the  (verse 3, men in unison)
      [n: {"C4", 2, "He"}, n: {"B3", 1.5, "rules"}, n: {"A3", 0.5, "the"}],
      # 110  world with
      [n: {"G3", 2, "world"}, rest: 1, n: {"F3", 1, "with"}],
      # 111  truth and
      [n: {"E3", 2, "truth"}, n: {"D3", 2, "and"}],
      # 112  grace, and
      [n: {"C3", 2, "grace,"}, rest: 1, n: {"G3", 1, "and"}],
      # 113  makes the
      [n: {"A3", 2, "makes"}, rest: 1, n: {"A3", 1, "the"}],
      # 114  na-tions
      [n: {"B3", 3, "na-"}, n: {"B3", 1, "tions"}],
      # 115  prove
      [n: {"C4", 4, "prove"}],
      # 116  the
      [rest: 3, n: {"C4", 1, "the"}],
      # 117  glo-ries
      [n: {"C4", 1, "glo-"}, n: {"B3", 1, "~glo-"}, n: {"A3", 1, "ries"}, n: {"G3", 1, "~ries"}],
      # 118  of His
      [
        n: {"G3", 1.5, "of"},
        n: {"F3", 0.5, "~of"},
        n: {"E3", 0.5, "~of"},
        rest: 0.5,
        n: {"C4", 1, "His"}
      ],
      # 119  right-eous-
      [
        n: {"C4", 1, "right-"},
        n: {"B3", 1, "~right-"},
        n: {"A3", 1, "eous-"},
        n: {"G3", 1, "~eous-"}
      ],
      # 120  ness, and
      [
        n: {"G3", 1.5, "ness,"},
        n: {"F3", 0.5, "~ness,"},
        n: {"E3", 0.5, "~ness,"},
        rest: 0.5,
        n: {"E3", 1, "and"}
      ],
      # 121  won-ders of His
      [n: {"E3", 1, "won-"}, n: {"E3", 1, "ders"}, n: {"E3", 1, "of"}, n: {"F3", 1, "His"}],
      # 122  love, and
      [n: {"G3", 2, "love,"}, rest: 1, n: {"F3", 0.5, "and"}, n: {"E3", 0.5, "~and"}],
      # 123  won-ders of His
      [n: {"D3", 1, "won-"}, n: {"D3", 1, "ders"}, n: {"D3", 1, "of"}, n: {"E3", 1, "His"}],
      # 124  love, and
      [n: {"F3", 2, "love,"}, rest: 1, n: {"E3", 0.5, "and"}, n: {"D3", 0.5, "~and"}],
      # 125  won-ders,  (divides on "ders,")
      [n: {"C3", 1, "won-"}, n: {"C4", 2, "~won-"}, n: {"D4", 1, "ders,"}],
      # 126  won-ders
      [
        n: {"E4", 1.5, "won-"},
        n: {"F4", 0.5, "~won-"},
        n: {"E4", 1, "~won-"},
        n: {"F4", 1, "ders"}
      ],
      # 127  of His
      [n: {"E4", 2, "of"}, n: {"D4", 2, "His"}],
      # 128  love.
      [n: {"C4", 4, "love."}],
      # 129  The
      [rest: 3.5, n: {"G3", 0.5, "The"}],
      # 130  joy of the Lord, the  (chorus)
      [
        n: {"C4", 0.75, "joy"},
        n: {"C4", 0.75, "of"},
        n: {"C4", 0.5, "the"},
        n: {"C4", 1, "Lord,"},
        rest: 0.5,
        n: {"C4", 0.5, "the"}
      ],
      # 131  joy of the Lord is my
      [
        n: {"C4", 0.75, "joy"},
        n: {"D4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 0.75, "Lord"},
        n: {"D4", 0.75, "is"},
        n: {"C4", 0.5, "my"}
      ],
      # 132  (my) strength.
      [n: {"C4", 1, "~my"}, n: {"C4", 3, "strength."}],
      # 133  The
      [rest: 3.5, n: {"G3", 0.5, "The"}],
      # 134  joy of the Lord, the
      [
        n: {"C4", 0.75, "joy"},
        n: {"C4", 0.75, "of"},
        n: {"C4", 0.5, "the"},
        n: {"C4", 1, "Lord,"},
        rest: 0.5,
        n: {"C4", 0.5, "the"}
      ],
      # 135  joy of the Lord is my
      [
        n: {"C4", 0.75, "joy"},
        n: {"D4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 0.75, "Lord"},
        n: {"D4", 0.75, "is"},
        n: {"C4", 0.5, "my"}
      ],
      # 136  (my) strength.
      [n: {"C4", 1, "~my"}, n: {"C4", 3, "strength."}],
      # 137  O
      [rest: 3.5, n: {"C4", 0.5, "O"}],
      # 138  (O) my soul, bless
      [
        n: {"C4", 0.5, "~O"},
        n: {"C4", 1, "my"},
        n: {"C4", 1.5, "soul,"},
        rest: 0.5,
        n: {"D4", 0.5, "bless"}
      ],
      # 139  (bless) His Name, all
      [
        n: {"D4", 0.5, "~bless"},
        n: {"D4", 1, "His"},
        n: {"D4", 1.5, "Name,"},
        rest: 0.5,
        n: {"E4", 0.5, "all"}
      ],
      # 140  (all) that is with-in
      [
        n: {"E4", 0.5, "~all"},
        n: {"E4", 1, "that"},
        n: {"E4", 1.5, "is"},
        n: {"C4", 0.5, "with-"},
        n: {"F4", 0.5, "in"}
      ],
      # 141  (in) me say: O
      [
        n: {"F4", 0.5, "~in"},
        n: {"E4", 1, "me"},
        n: {"D4", 1.5, "say:"},
        rest: 0.5,
        n: {"C4", 0.5, "O"}
      ],
      # 142  (O) my soul, bless  (tag)
      [
        n: {"C4", 0.5, "~O"},
        n: {"C4", 1, "my"},
        n: {"C4", 1.5, "soul,"},
        rest: 0.5,
        n: {"D4", 0.5, "bless"}
      ],
      # 143  (bless) His Name, all
      [
        n: {"D4", 0.5, "~bless"},
        n: {"D4", 1, "His"},
        n: {"D4", 1.5, "Name,"},
        rest: 0.5,
        n: {"E4", 0.5, "all"}
      ],
      # 144  (all) that is with-in
      [
        n: {"E4", 0.5, "~all"},
        n: {"E4", 1, "that"},
        n: {"E4", 1.5, "is"},
        n: {"C4", 0.5, "with-"},
        n: {"F4", 0.5, "in"}
      ],
      # 145  (in) me say: O
      [
        n: {"F4", 0.5, "~in"},
        n: {"E4", 1, "me"},
        n: {"D4", 1.5, "say:"},
        rest: 0.5,
        n: {"C4", 0.5, "O"}
      ],
      # 146  (O) my soul, bless
      [
        n: {"C4", 0.5, "~O"},
        n: {"C4", 1, "my"},
        n: {"C4", 1.5, "soul,"},
        rest: 0.5,
        n: {"D4", 0.5, "bless"}
      ],
      # 147  (bless) His Name, all
      [
        n: {"D4", 0.5, "~bless"},
        n: {"D4", 1, "His"},
        n: {"D4", 1.5, "Name,"},
        rest: 0.5,
        n: {"E4", 0.5, "all"}
      ],
      # 148  (all) that is with-in
      [
        n: {"E4", 0.5, "~all"},
        n: {"E4", 1, "that"},
        n: {"E4", 1.5, "is"},
        n: {"C4", 0.5, "with-"},
        n: {"F4", 0.5, "in"}
      ],
      # 149  (in) me say: The
      [
        n: {"F4", 0.5, "~in"},
        n: {"E4", 1, "me"},
        n: {"D4", 1.5, "say:"},
        rest: 0.5,
        n: {"G3", 0.5, "The"}
      ],
      # 150  joy of the Lord, the
      [
        n: {"C4", 0.75, "joy"},
        n: {"C4", 0.75, "of"},
        n: {"C4", 0.5, "the"},
        n: {"C4", 1, "Lord,"},
        rest: 0.5,
        n: {"C4", 0.5, "the"}
      ],
      # 151  joy of the Lord is my
      [
        n: {"C4", 0.75, "joy"},
        n: {"D4", 0.75, "of"},
        n: {"E4", 0.5, "the"},
        n: {"E4", 0.75, "Lord"},
        n: {"D4", 0.75, "is"},
        n: {"C4", 0.5, "my"}
      ],
      # 152  (my) strength.
      [n: {"C4", 1, "~my"}, n: {"C4", 3, "strength."}],
      # 153  (outro)
      [rest: 4],
      # 154  (solo)
      [rest: 4],
      # 155
      [rest: 4],
      # 156
      [rest: 4],
      # 157
      [rest: 4],
      # 158
      [rest: 4],
      # 159  (rit.)
      [rest: 4],
      # 160  (fermata)
      [rest: 4]
    ]
  end
end
