defmodule ChoirCoach.Songs.ThisIsJesus do
  @moduledoc """
  "This Is Jesus" (traditional American melody, words and new music by Kyle Williams, Darren
  Mulligan, Drake Kennedy and Tony Wood, arr. Russell Mauldin), bass part, bars 1–81.

  Transcribed from the Drive score, bar by bar, and checked note by note
  against the Bass rehearsal track with the pitch detector: every note it
  hears off the written pitch was re-read at 400 dpi (most are the tenor,
  who shares the channel, or a scoop into the note).

  Timing is the Bass rehearsal track's, fitted with `scripts/align_track.exs`:
  bar 1 starts 560 ms in, ♩ = 76.98 (marked 77), the rit. in bar 80 and the
  final fermata as `bar_ms`. The Demo opens with the narration (12.6 s);
  Split and Demo offsets come from cross-correlating their accompaniment
  with the rehearsal track's.
  """

  alias ChoirCoach.Song

  @doc "Where bar 1 falls on each track (ms), and which channel holds the voices."
  def tracks do
    %{
      piano: %{file: "this_is_jesus/piano.mp3", bar1_ms: 560.0, voice: :left, label: "Piano"},
      rehearsal: %{
        file: "this_is_jesus/bass.mp3",
        bar1_ms: 560.0,
        voice: :left,
        label: "Bass rehearsal"
      },
      split: %{
        file: "this_is_jesus/split.mp3",
        bar1_ms: 1_066.0,
        voice: :right,
        label: "Split track"
      },
      demo: %{file: "this_is_jesus/demo.mp3", bar1_ms: 12_574.0, voice: :mixed, label: "Demo"}
    }
  end

  @spec bass() :: Song.t()
  def bass do
    Song.build(
      title: "This Is Jesus",
      part: :bass,
      clef: :bass,
      key: -2,
      tempo_bpm: 76.98,
      beats_per_bar: 3,
      first_bar: 1,
      start_ms: 560.0,
      bar_ms: %{80 => 2_851.0, 81 => 5_731.0},
      bars: [
        # 1  (piano)
        [rest: 3],
        # 2  (piano)
        [rest: 3],
        # 3  (piano)
        [rest: 3],
        # 4  (piano)
        [rest: 3],
        # 5  (piano)
        [rest: 3],
        # 6  (piano)
        [rest: 3],
        # 7  (piano)
        [rest: 3],
        # 8  Night of
        [rest: 2, n: {"D3", 0.5, "Night"}, n: {"C3", 0.5, "of"}],
        # 9  won-der, still, and
        [
          n: {"Bb2", 1, "won-"},
          n: {"Bb2", 1, "der,"},
          n: {"D3", 0.5, "still,"},
          n: {"F3", 0.5, "and"}
        ],
        # 10  si-lent, Heav-en's
        [
          n: {"C3", 1, "si-"},
          n: {"C3", 0.5, "lent,"},
          rest: 0.5,
          n: {"D3", 0.5, "Heav-"},
          n: {"F3", 0.5, "en's"}
        ],
        # 11  bril-liance from a-
        [
          n: {"G3", 1, "bril-"},
          n: {"F3", 1, "liance"},
          n: {"D3", 0.5, "from"},
          n: {"C3", 0.5, "a-"}
        ],
        # 12  bove. Light of
        [n: {"Bb2", 1, "bove."}, rest: 1, n: {"D3", 0.5, "Light"}, n: {"C3", 0.5, "of"}],
        # 13  Glo-ry pierced the
        [
          n: {"Bb2", 1, "Glo-"},
          n: {"Bb2", 1, "ry"},
          n: {"D3", 0.5, "pierced"},
          n: {"F3", 0.5, "the"}
        ],
        # 14  dark-ness. Mer-cy
        [
          n: {"C3", 1, "dark-"},
          n: {"C3", 0.5, "ness."},
          rest: 0.5,
          n: {"D3", 0.5, "Mer-"},
          n: {"F3", 0.5, "cy"}
        ],
        # 15  pierced my heart with
        [
          n: {"G3", 1, "pierced"},
          n: {"F3", 1, "my"},
          n: {"D3", 0.5, "heart"},
          n: {"C3", 0.5, "with"}
        ],
        # 16  love. This is__
        [
          n: {"Bb2", 1, "love."},
          rest: 1,
          n: {"F3", 0.5, "This"},
          n: {"G3", 0.25, "is"},
          n: {"A3", 0.25, "~is"}
        ],
        # 17  Je-sus, King of
        [
          n: {"G3", 0.75, "Je-"},
          n: {"F3", 0.25, "~Je-"},
          n: {"F3", 1, "sus,"},
          n: {"F3", 0.5, "King"},
          # ? last chord's two noteheads are cramped; lower read as F3
          n: {"F3", 0.5, "of"}
        ],
        # 18  Glo-ry, here to__
        [
          n: {"Eb3", 1, "Glo-"},
          n: {"D3", 0.5, "ry,"},
          rest: 0.5,
          n: {"F3", 0.5, "here"},
          n: {"G3", 0.25, "to"},
          n: {"A3", 0.25, "~to"}
        ],
        # 19  res-cue from the
        [
          n: {"G3", 0.75, "res-"},
          n: {"F3", 0.25, "~res-"},
          n: {"F3", 1, "cue"},
          n: {"F3", 0.5, "from"},
          n: {"F3", 0.5, "the"}
        ],
        # 20  fall. Son of (harm.)
        [n: {"Eb3", 1, "fall."}, rest: 1, n: {"F3", 0.5, "Son"}, n: {"Eb3", 0.5, "of"}],
        # 21  God who comes to
        [
          n: {"D3", 1, "God"},
          n: {"D3", 1, "who"},
          n: {"F3", 0.5, "comes"},
          n: {"Bb3", 0.5, "to"}
        ],
        # 22  save us: Prince of
        [
          n: {"A3", 1, "save"},
          n: {"A3", 0.5, "us:"},
          rest: 0.5,
          n: {"A3", 0.5, "Prince"},
          n: {"A3", 0.5, "of"}
        ],
        # 23  Peace and Lord of__
        [
          n: {"Bb3", 1, "Peace"},
          n: {"Bb3", 1, "and"},
          n: {"F3", 0.5, "Lord"},
          n: {"Eb3", 0.25, "of"},
          n: {"D3", 0.25, "~of"}
        ],
        # 24  All.
        [n: {"D3", 3, "All."}],
        # 25
        [rest: 3],
        # 26
        [rest: 3],
        # 27
        [rest: 3],
        # 28  Oh, the (MEN)
        [rest: 2, n: {"D3", 0.5, "Oh,"}, n: {"C3", 0.5, "the"}],
        # 29  mys-t'ry, who could
        [
          n: {"Bb2", 1, "mys-"},
          n: {"Bb2", 1, "t'ry,"},
          n: {"D3", 0.5, "who"},
          n: {"F3", 0.5, "could"}
        ],
        # 30  fath-om? God would
        [
          n: {"C3", 1, "fath-"},
          n: {"C3", 0.5, "om?"},
          rest: 0.5,
          n: {"D3", 0.5, "God"},
          n: {"F3", 0.5, "would"}
        ],
        # 31  leave His Ho-ly
        [n: {"G3", 1, "leave"}, n: {"F3", 1, "His"}, n: {"D3", 0.5, "Ho-"}, n: {"C3", 0.5, "ly"}],
        # 32  throne (then WOMEN)
        [n: {"Bb2", 1, "throne"}, rest: 2],
        # 33  (WOMEN: man-ger, for a)
        [rest: 3],
        # 34  (sin-ner,) for us (ALL)
        [rest: 2, n: {"D3", 0.5, "for"}, n: {"F3", 0.5, "us"}],
        # 35  all to be His
        [n: {"G3", 1, "all"}, n: {"F3", 1, "to"}, n: {"D3", 0.5, "be"}, n: {"C3", 0.5, "His"}],
        # 36  own. This is__
        [
          n: {"Bb2", 1, "own."},
          rest: 1,
          n: {"F3", 0.5, "This"},
          n: {"G3", 0.25, "is"},
          n: {"A3", 0.25, "~is"}
        ],
        # 37  Je-sus, King of
        [
          n: {"G3", 0.75, "Je-"},
          n: {"F3", 0.25, "~Je-"},
          n: {"F3", 1, "sus,"},
          n: {"F3", 0.5, "King"},
          # ? last chord cramped; lower read as F3
          n: {"F3", 0.5, "of"}
        ],
        # 38  Glo-ry, here to__
        [
          n: {"Eb3", 1, "Glo-"},
          n: {"D3", 0.5, "ry,"},
          rest: 0.5,
          n: {"F3", 0.5, "here"},
          n: {"G3", 0.25, "to"},
          n: {"A3", 0.25, "~to"}
        ],
        # 39  res-cue from the
        [
          n: {"G3", 0.75, "res-"},
          n: {"F3", 0.25, "~res-"},
          n: {"F3", 1, "cue"},
          n: {"F3", 0.5, "from"},
          n: {"F3", 0.5, "the"}
        ],
        # 40  fall. Son of
        [n: {"Eb3", 1, "fall."}, rest: 1, n: {"F3", 0.5, "Son"}, n: {"Eb3", 0.5, "of"}],
        # 41  God who comes to
        [
          n: {"D3", 1, "God"},
          n: {"D3", 1, "who"},
          n: {"F3", 0.5, "comes"},
          n: {"Bb3", 0.5, "to"}
        ],
        # 42  save us: Prince of
        [
          n: {"A3", 1, "save"},
          n: {"A3", 0.5, "us:"},
          rest: 0.5,
          n: {"A3", 0.5, "Prince"},
          n: {"A3", 0.5, "of"}
        ],
        # 43  Peace and Lord of
        [
          n: {"Bb3", 1, "Peace"},
          n: {"Bb3", 1, "and"},
          n: {"F3", 0.5, "Lord"},
          n: {"Eb3", 0.25, "of"},
          n: {"D3", 0.25, "~of"}
        ],
        # 44  All.
        [n: {"D3", 3, "All."}],
        # 45
        [rest: 3],
        # 46
        [rest: 3],
        # 47
        [rest: 3],
        # 48  Re-
        [rest: 2.5, n: {"Bb2", 0.5, "Re-"}],
        # 49  joice! He is
        [n: {"Bb2", 1, "joice!"}, n: {"C3", 1.5, "He"}, n: {"Bb2", 0.5, "is"}],
        # 50  with us. Re-
        [
          n: {"Eb3", 0.5, "with"},
          n: {"D3", 0.5, "~with"},
          n: {"D3", 1, "us."},
          rest: 0.5,
          n: {"Bb2", 0.5, "Re-"}
        ],
        # 51  joice! Hope is
        [n: {"Bb2", 1, "joice!"}, n: {"C3", 1.5, "Hope"}, n: {"Bb2", 0.5, "is"}],
        # 52  here. Re-
        [n: {"Bb2", 2, "here."}, rest: 0.5, n: {"Bb2", 0.5, "Re-"}],
        # 53  joice! He is
        [n: {"Bb2", 1, "joice!"}, n: {"C3", 1.5, "He"}, n: {"Bb2", 0.5, "is"}],
        # 54  with us. Re-
        [
          n: {"Eb3", 0.5, "with"},
          n: {"F3", 0.5, "~with"},
          n: {"F3", 1, "us."},
          rest: 0.5,
          n: {"F3", 0.5, "Re-"}
        ],
        # 55  joice! Hope is
        [n: {"G3", 1, "joice!"}, n: {"F3", 1.5, "Hope"}, n: {"Bb3", 0.5, "is"}],
        # 56  here. Re-
        [n: {"Bb3", 2, "here."}, rest: 0.5, n: {"Eb3", 0.5, "Re-"}],
        # 57  joice! He is
        [n: {"G3", 1, "joice!"}, n: {"F3", 1.5, "He"}, n: {"F3", 0.5, "is"}],
        # 58  with us. Re-
        [n: {"Eb3", 1, "with"}, n: {"Bb2", 1, "us."}, rest: 0.5, n: {"Bb2", 0.5, "Re-"}],
        # 59  joice! Hope is
        [n: {"G3", 1, "joice!"}, n: {"F3", 1.5, "Hope"}, n: {"F3", 0.5, "is"}],
        # 60  here. Re-
        [n: {"Eb3", 2, "here."}, rest: 0.5, n: {"Eb3", 0.5, "Re-"}],
        # 61  joice! He is
        [n: {"G3", 1, "joice!"}, n: {"F3", 1.5, "He"}, n: {"F3", 0.5, "is"}],
        # 62  with us. Re-
        [n: {"Eb3", 1, "with"}, n: {"Bb2", 1, "us."}, rest: 0.5, n: {"Bb2", 0.5, "Re-"}],
        # 63  joice! Hope is
        [n: {"G3", 1, "joice!"}, n: {"F3", 1.5, "Hope"}, n: {"F3", 0.5, "is"}],
        # 64  here. This is
        [n: {"Eb3", 1, "here."}, rest: 1, n: {"Eb3", 0.5, "This"}, n: {"Eb3", 0.5, "is"}],
        # 65  Je-sus, King of
        [n: {"G3", 1, "Je-"}, n: {"F3", 1, "sus,"}, n: {"F3", 0.5, "King"}, n: {"F3", 0.5, "of"}],
        # 66  Glo-ry, here to
        [
          n: {"Eb3", 1, "Glo-"},
          n: {"Bb2", 0.5, "ry,"},
          rest: 0.5,
          n: {"Bb2", 0.5, "here"},
          n: {"Bb2", 0.5, "to"}
        ],
        # 67  res-cue from the
        [
          n: {"G3", 1, "res-"},
          n: {"F3", 1, "cue"},
          n: {"F3", 0.5, "from"},
          n: {"F3", 0.5, "the"}
        ],
        # 68  fall. Son of
        [n: {"Eb3", 1, "fall."}, rest: 1, n: {"Eb3", 0.5, "Son"}, n: {"Eb3", 0.5, "of"}],
        # 69  God who comes to
        [n: {"G3", 1, "God"}, n: {"F3", 1, "who"}, n: {"F3", 0.5, "comes"}, n: {"F3", 0.5, "to"}],
        # 70  save us: Prince of
        [
          n: {"Eb3", 1, "save"},
          n: {"Bb2", 0.5, "us:"},
          rest: 0.5,
          n: {"Bb2", 0.5, "Prince"},
          n: {"Bb2", 0.5, "of"}
        ],
        # 71  Peace and Lord of
        [
          n: {"G3", 1, "Peace"},
          n: {"F3", 1, "and"},
          n: {"F3", 0.75, "Lord"},
          n: {"F3", 0.25, "of"}
        ],
        # 72  All.
        [n: {"Eb3", 3, "All."}],
        # 73  (All.) For the
        [n: {"Eb3", 1, "~All."}, rest: 1, n: {"D3", 0.5, "For"}, n: {"C3", 0.5, "the"}],
        # 74  heart so prone to
        [
          n: {"Bb2", 1, "heart"},
          n: {"Bb2", 1, "so"},
          n: {"D3", 0.5, "prone"},
          n: {"F3", 0.5, "to"}
        ],
        # 75  wan-der, for these
        [
          n: {"C3", 1, "wan-"},
          n: {"C3", 0.5, "der,"},
          rest: 0.5,
          n: {"D3", 0.5, "for"},
          n: {"F3", 0.5, "these"}
        ],
        # 76  feet so quick to
        [n: {"G3", 1, "feet"}, n: {"F3", 1, "so"}, n: {"D3", 0.5, "quick"}, n: {"C3", 0.5, "to"}],
        # 77  flee, God is
        [n: {"Bb2", 1, "flee,"}, rest: 1, n: {"D3", 0.5, "God"}, n: {"C3", 0.5, "is"}],
        # 78  here, and Love is
        [
          n: {"Bb2", 1, "here,"},
          n: {"Bb2", 1, "and"},
          n: {"D3", 0.5, "Love"},
          n: {"F3", 0.5, "is"}
        ],
        # 79  reach-ing for the
        [
          n: {"C3", 1, "reach-"},
          n: {"C3", 0.5, "ing"},
          rest: 0.5,
          n: {"D3", 0.5, "for"},
          n: {"F3", 0.5, "the"}
        ],
        # 80  lost and least of (rit.)
        [
          n: {"G3", 1, "lost"},
          n: {"F3", 1, "and"},
          n: {"D3", 0.5, "least"},
          n: {"C3", 0.5, "of"}
        ],
        # 81  these. (fermata)
        [n: {"Bb2", 3, "these."}]
      ]
    )
  end
end
