defmodule ChoirCoach.Songs.ThisIsJesus do
  @moduledoc """
  "This Is Jesus" (traditional American melody, words and new music by Kyle Williams, Darren
  Mulligan, Drake Kennedy and Tony Wood, arr. Russell Mauldin), all four voice parts and the melody, bars 1–81.

  Transcribed from the Drive score, bar by bar, and checked note by note
  against the Bass rehearsal track with the pitch detector: every note it
  hears off the written pitch was re-read at 400 dpi (most are the tenor,
  who shares the channel, or a scoop into the note).

  Timing is the Bass rehearsal track's, fitted with `scripts/align_track.exs`:
  bar 1 starts 560 ms in, ♩ = 76.98 (marked 77), the rit. in bar 80 and the
  final fermata as `bar_ms`. The Demo opens with the narration (12.6 s);
  Split and Demo offsets come from cross-correlating their accompaniment
  with the rehearsal track's.

  The melody is the tune wherever a voice sings it, in the women's register:
  the unison line, the soprano where the voices divide, the men's line an
  octave up where they sing alone. Checked against the Soprano and Alto
  rehearsal tracks with the detector; the notes no recording confirms were
  re-read at 400 dpi and match the score.

  The soprano, alto and tenor parts are transcribed on the same bars: the
  upper and lower voices of the treble staff and the upper voice of the bass
  staff, the unison line where a staff prints one, rests where the part is
  tacet. Each was checked against its own rehearsal track (Soprano, Alto,
  Tenor) with the detector, and every note it heard off the written pitch
  re-read at 400 dpi.
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
          file: "this_is_jesus/split.mp3",
          bar1_ms: 1_066.0,
          voice: :right,
          label: "Split track"
        },
        demo: %{file: "this_is_jesus/demo.mp3", bar1_ms: 12_574.0, voice: :mixed, label: "Demo"}
      },
      part_tracks(part)
    )
  end

  defp part_tracks(:bass) do
    %{
      piano: %{file: "this_is_jesus/piano_bass.mp3", bar1_ms: 560.0, voice: :left, label: "Piano"},
      rehearsal: %{
        file: "this_is_jesus/bass.mp3",
        bar1_ms: 560.0,
        voice: :left,
        label: "Bass rehearsal"
      }
    }
  end

  defp part_tracks(:melody) do
    %{
      rehearsal: %{
        file: "this_is_jesus/soprano.mp3",
        bar1_ms: 560.0,
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
        file: "this_is_jesus/piano_#{part}.mp3",
        bar1_ms: 560.0,
        voice: :left,
        label: "Piano"
      },
      rehearsal: %{
        file: "this_is_jesus/#{part}.mp3",
        bar1_ms: 560.0,
        voice: :left,
        label: "#{name} rehearsal"
      }
    }
  end

  # Every part shares the bar timeline (and so every track's offsets).
  defp timing do
    [
      title: "This Is Jesus",
      key: -2,
      tempo_bpm: 76.98,
      beats_per_bar: 3,
      first_bar: 1,
      start_ms: 560.0,
      bar_ms: %{80 => 2_851.0, 81 => 5_731.0}
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
  end

  defp melody_bars do
    [
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
      # 8  unison (women): Night of  ok: score clear, women+men unison 8ve; recording quiet pickup
      [rest: 2, n: {"D4", 0.5, "Night"}, n: {"C4", 0.5, "of"}],
      # 9  unison: won-der, still, and
      [
        n: {"Bb3", 1, "won-"},
        n: {"Bb3", 1, "der,"},
        n: {"D4", 0.5, "still,"},
        n: {"F4", 0.5, "and"}
      ],
      # 10  unison: si-lent, Heav-en's
      [
        n: {"C4", 1, "si-"},
        n: {"C4", 0.5, "lent,"},
        rest: 0.5,
        n: {"D4", 0.5, "Heav-"},
        n: {"F4", 0.5, "en's"}
      ],
      # 11  unison: bril-liance from a-
      [
        n: {"G4", 1, "bril-"},
        n: {"F4", 1, "liance"},
        n: {"D4", 0.5, "from"},
        n: {"C4", 0.5, "a-"}
      ],
      # 12  unison: bove. Light of
      [n: {"Bb3", 1, "bove."}, rest: 1, n: {"D4", 0.5, "Light"}, n: {"C4", 0.5, "of"}],
      # 13  unison: Glo-ry pierced the
      [
        n: {"Bb3", 1, "Glo-"},
        n: {"Bb3", 1, "ry"},
        n: {"D4", 0.5, "pierced"},
        n: {"F4", 0.5, "the"}
      ],
      # 14  unison: dark-ness. Mer-cy
      [
        n: {"C4", 1, "dark-"},
        n: {"C4", 0.5, "ness."},
        rest: 0.5,
        n: {"D4", 0.5, "Mer-"},
        n: {"F4", 0.5, "cy"}
      ],
      # 15  unison: pierced my heart with
      [
        n: {"G4", 1, "pierced"},
        n: {"F4", 1, "my"},
        n: {"D4", 0.5, "heart"},
        n: {"C4", 0.5, "with"}
      ],
      # 16  unison: love. This is
      [
        n: {"Bb3", 1, "love."},
        rest: 1,
        n: {"F4", 0.5, "This"},
        n: {"G4", 0.25, "is"},
        n: {"A4", 0.25, "~is"}
      ],
      # 17  sop: Je-sus, King of
      [
        n: {"Bb4", 0.75, "Je-"},
        n: {"A4", 0.25, "~Je-"},
        n: {"A4", 1, "sus,"},
        n: {"G4", 0.5, "King"},
        n: {"F4", 0.5, "of"}
      ],
      # 18  sop: Glo-ry, here to  ok: score clear (G4/Eb4, F4/D4 sop/alto thirds)
      [
        n: {"G4", 0.5, "Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"D4", 0.5, "ry,"},
        rest: 0.5,
        n: {"F4", 0.5, "here"},
        n: {"G4", 0.25, "to"},
        n: {"A4", 0.25, "~to"}
      ],
      # 19  sop: res-cue from the  ok: score clear (A4 over F4)
      [
        n: {"Bb4", 0.75, "res-"},
        n: {"A4", 0.25, "~res-"},
        n: {"A4", 1, "cue"},
        n: {"G4", 0.5, "from"},
        n: {"F4", 0.5, "the"}
      ],
      # 20  sop: fall. Son of
      [n: {"Bb4", 1, "fall."}, rest: 1, n: {"D4", 0.5, "Son"}, n: {"C4", 0.5, "of"}],
      # 21  sop: God who comes to
      [n: {"Bb3", 1, "God"}, n: {"Bb3", 1, "who"}, n: {"D4", 0.5, "comes"}, n: {"F4", 0.5, "to"}],
      # 22  sop: save us: Prince of  ok: score clear, C4 ledger line, unison with men
      [
        n: {"C4", 1, "save"},
        n: {"C4", 0.5, "us:"},
        rest: 0.5,
        n: {"D4", 0.5, "Prince"},
        n: {"F4", 0.5, "of"}
      ],
      # 23  sop: Peace and Lord of
      [
        n: {"G4", 1, "Peace"},
        n: {"F4", 1, "and"},
        n: {"D4", 0.5, "Lord"},
        n: {"C4", 0.25, "of"},
        n: {"Bb3", 0.25, "~of"}
      ],
      # 24  sop: All.
      [n: {"Bb3", 3, "All."}],
      # 25  (piano)
      [rest: 3],
      # 26  (piano)
      [rest: 3],
      # 27  (piano)
      [rest: 3],
      # 28  men (8va): Oh, the
      [rest: 2, n: {"D4", 0.5, "Oh,"}, n: {"C4", 0.5, "the"}],
      # 29  men (8va): mys-t'ry, who could
      [
        n: {"Bb3", 1, "mys-"},
        n: {"Bb3", 1, "t'ry,"},
        n: {"D4", 0.5, "who"},
        n: {"F4", 0.5, "could"}
      ],
      # 30  men (8va): fath-om? God would
      [
        n: {"C4", 1, "fath-"},
        n: {"C4", 0.5, "om?"},
        rest: 0.5,
        n: {"D4", 0.5, "God"},
        n: {"F4", 0.5, "would"}
      ],
      # 31  men (8va): leave His Ho-ly
      [n: {"G4", 1, "leave"}, n: {"F4", 1, "His"}, n: {"D4", 0.5, "Ho-"}, n: {"C4", 0.5, "ly"}],
      # 32  men (8va): throne; women: for a
      [n: {"Bb3", 1, "throne"}, rest: 1, n: {"D4", 0.5, "for"}, n: {"C4", 0.5, "a"}],
      # 33  women unison: man-ger, for a
      [n: {"Bb3", 1, "man-"}, n: {"Bb3", 1, "ger,"}, n: {"D4", 0.5, "for"}, n: {"F4", 0.5, "a"}],
      # 34  women, then all unison: sin-ner, for us
      [
        n: {"C4", 1, "sin-"},
        n: {"C4", 0.5, "ner,"},
        rest: 0.5,
        n: {"D4", 0.5, "for"},
        n: {"F4", 0.5, "us"}
      ],
      # 35  unison: all to be His
      [n: {"G4", 1, "all"}, n: {"F4", 1, "to"}, n: {"D4", 0.5, "be"}, n: {"C4", 0.5, "His"}],
      # 36  unison: own. This is
      [
        n: {"Bb3", 1, "own."},
        rest: 1,
        n: {"F4", 0.5, "This"},
        n: {"G4", 0.25, "is"},
        n: {"A4", 0.25, "~is"}
      ],
      # 37  sop: Je-sus, King of
      [
        n: {"Bb4", 0.75, "Je-"},
        n: {"A4", 0.25, "~Je-"},
        n: {"A4", 1, "sus,"},
        n: {"G4", 0.5, "King"},
        n: {"F4", 0.5, "of"}
      ],
      # 38  sop: Glo-ry, here to  ok: score clear (G4/Eb4, F4/D4 sop/alto thirds)
      [
        n: {"G4", 0.5, "Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"D4", 0.5, "ry,"},
        rest: 0.5,
        n: {"F4", 0.5, "here"},
        n: {"G4", 0.25, "to"},
        n: {"A4", 0.25, "~to"}
      ],
      # 39  sop: res-cue from the  ok: score clear (A4 over F4)
      [
        n: {"Bb4", 0.75, "res-"},
        n: {"A4", 0.25, "~res-"},
        n: {"A4", 1, "cue"},
        n: {"G4", 0.5, "from"},
        n: {"F4", 0.5, "the"}
      ],
      # 40  sop: fall. Son of
      [n: {"Bb4", 1, "fall."}, rest: 1, n: {"D4", 0.5, "Son"}, n: {"C4", 0.5, "of"}],
      # 41  unison: God who comes to
      [n: {"Bb3", 1, "God"}, n: {"Bb3", 1, "who"}, n: {"D4", 0.5, "comes"}, n: {"F4", 0.5, "to"}],
      # 42  unison: save us: Prince of
      [
        n: {"C4", 1, "save"},
        n: {"C4", 0.5, "us:"},
        rest: 0.5,
        n: {"D4", 0.5, "Prince"},
        n: {"F4", 0.5, "of"}
      ],
      # 43  unison: Peace and Lord of
      [
        n: {"G4", 1, "Peace"},
        n: {"F4", 1, "and"},
        n: {"D4", 0.5, "Lord"},
        n: {"C4", 0.25, "of"},
        n: {"Bb3", 0.25, "~of"}
      ],
      # 44  unison: All.
      [n: {"Bb3", 3, "All."}],
      # 45  (piano)
      [rest: 3],
      # 46  (piano)
      [rest: 3],
      # 47  (piano)
      [rest: 3],
      # 48  unison: Re-
      [rest: 2.5, n: {"Bb3", 0.5, "Re-"}],
      # 49  unison: joice! He is
      [n: {"Bb3", 1, "joice!"}, n: {"C4", 1.5, "He"}, n: {"Bb3", 0.5, "is"}],
      # 50  unison: with us. Re-
      [
        n: {"Eb4", 0.5, "with"},
        n: {"D4", 0.5, "~with"},
        n: {"D4", 1, "us."},
        rest: 0.5,
        n: {"Bb3", 0.5, "Re-"}
      ],
      # 51  unison: joice! Hope is
      [n: {"Bb3", 1, "joice!"}, n: {"C4", 1.5, "Hope"}, n: {"Bb3", 0.5, "is"}],
      # 52  unison: here. Re-
      [n: {"Bb3", 2, "here."}, rest: 0.5, n: {"Bb3", 0.5, "Re-"}],
      # 53  unison: joice! He is
      [n: {"Bb3", 1, "joice!"}, n: {"C4", 1.5, "He"}, n: {"Bb3", 0.5, "is"}],
      # 54  unison: with us. Re-
      [
        n: {"Eb4", 0.5, "with"},
        n: {"D4", 0.5, "~with"},
        n: {"D4", 1, "us."},
        rest: 0.5,
        n: {"Bb3", 0.5, "Re-"}
      ],
      # 55  unison: joice! Hope is
      [n: {"Bb3", 1, "joice!"}, n: {"C4", 1.5, "Hope"}, n: {"Bb3", 0.5, "is"}],
      # 56  unison, then sop: here. Re-
      [n: {"Bb3", 2, "here."}, rest: 0.5, n: {"Bb4", 0.5, "Re-"}],
      # 57  sop: joice! He is
      [n: {"Bb4", 1, "joice!"}, n: {"C5", 1.5, "He"}, n: {"Bb4", 0.5, "is"}],
      # 58  sop: with us. Re-
      [
        n: {"Eb5", 0.5, "with"},
        n: {"D5", 0.5, "~with"},
        n: {"D5", 1, "us."},
        rest: 0.5,
        n: {"Bb4", 0.5, "Re-"}
      ],
      # 59  sop: joice! Hope is
      [n: {"Bb4", 1, "joice!"}, n: {"C5", 1.5, "Hope"}, n: {"Bb4", 0.5, "is"}],
      # 60  sop: here. Re-
      [n: {"Bb4", 2, "here."}, rest: 0.5, n: {"Bb4", 0.5, "Re-"}],
      # 61  sop: joice! He is
      [n: {"Bb4", 1, "joice!"}, n: {"C5", 1.5, "He"}, n: {"Bb4", 0.5, "is"}],
      # 62  sop: with us. Re-
      [
        n: {"Eb5", 0.5, "with"},
        n: {"D5", 0.5, "~with"},
        n: {"D5", 1, "us."},
        rest: 0.5,
        n: {"Bb4", 0.5, "Re-"}
      ],
      # 63  sop: joice! Hope is
      [n: {"Bb4", 1, "joice!"}, n: {"C5", 1.5, "Hope"}, n: {"Bb4", 0.5, "is"}],
      # 64  sop: here. This is
      [n: {"Bb4", 1, "here."}, rest: 1, n: {"Bb4", 0.5, "This"}, n: {"Bb4", 0.5, "is"}],
      # 65  sop: Je-sus, King of
      [n: {"D5", 1, "Je-"}, n: {"C5", 1, "sus,"}, n: {"Bb4", 0.5, "King"}, n: {"Bb4", 0.5, "of"}],
      # 66  sop: Glo-ry, here to
      [
        n: {"Eb5", 0.5, "Glo-"},
        n: {"D5", 0.5, "~Glo-"},
        n: {"D5", 0.5, "ry,"},
        rest: 0.5,
        n: {"Bb4", 0.5, "here"},
        n: {"Bb4", 0.5, "to"}
      ],
      # 67  sop: res-cue from the
      [
        n: {"D5", 1, "res-"},
        n: {"C5", 1, "cue"},
        n: {"Bb4", 0.5, "from"},
        n: {"Bb4", 0.5, "the"}
      ],
      # 68  sop: fall. Son of
      [n: {"Bb4", 1, "fall."}, rest: 1, n: {"Bb4", 0.5, "Son"}, n: {"Bb4", 0.5, "of"}],
      # 69  sop: God who comes to
      [n: {"D5", 1, "God"}, n: {"C5", 1, "who"}, n: {"Bb4", 0.5, "comes"}, n: {"Bb4", 0.5, "to"}],
      # 70  sop: save us: Prince of
      [
        n: {"Eb5", 0.5, "save"},
        n: {"D5", 0.5, "~save"},
        n: {"D5", 0.5, "us:"},
        rest: 0.5,
        n: {"Bb4", 0.5, "Prince"},
        n: {"Bb4", 0.5, "of"}
      ],
      # 71  sop: Peace and Lord of
      [
        n: {"D5", 1, "Peace"},
        n: {"C5", 1, "and"},
        n: {"Bb4", 0.75, "Lord"},
        n: {"Bb4", 0.25, "of"}
      ],
      # 72  sop: All.
      [n: {"Bb4", 3, "All."}],
      # 73  sop, then unison: (All.) For the
      [n: {"Bb4", 1, "~All."}, rest: 1, n: {"D4", 0.5, "For"}, n: {"C4", 0.5, "the"}],
      # 74  unison: heart so prone to
      [
        n: {"Bb3", 1, "heart"},
        n: {"Bb3", 1, "so"},
        n: {"D4", 0.5, "prone"},
        n: {"F4", 0.5, "to"}
      ],
      # 75  unison: wan-der, for these
      [
        n: {"C4", 1, "wan-"},
        n: {"C4", 0.5, "der,"},
        rest: 0.5,
        n: {"D4", 0.5, "for"},
        n: {"F4", 0.5, "these"}
      ],
      # 76  unison: feet so quick to
      [n: {"G4", 1, "feet"}, n: {"F4", 1, "so"}, n: {"D4", 0.5, "quick"}, n: {"C4", 0.5, "to"}],
      # 77  unison: flee, God is
      [n: {"Bb3", 1, "flee,"}, rest: 1, n: {"D4", 0.5, "God"}, n: {"C4", 0.5, "is"}],
      # 78  unison: here, and Love is
      [
        n: {"Bb3", 1, "here,"},
        n: {"Bb3", 1, "and"},
        n: {"D4", 0.5, "Love"},
        n: {"F4", 0.5, "is"}
      ],
      # 79  unison: reach-ing for the
      [
        n: {"C4", 1, "reach-"},
        n: {"C4", 0.5, "ing"},
        rest: 0.5,
        n: {"D4", 0.5, "for"},
        n: {"F4", 0.5, "the"}
      ],
      # 80  unison: lost and least of (rit.)
      [n: {"G4", 1, "lost"}, n: {"F4", 1, "and"}, n: {"D4", 0.5, "least"}, n: {"C4", 0.5, "of"}],
      # 81  unison: these. (fermata)
      [n: {"Bb3", 3, "these."}]
    ]
  end

  defp soprano_bars do
    [
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
      # 8  unison: Night of  ok: score clear, women+men unison 8ve; recording quiet pickup  ok:
      #   quiet pickup, heard low
      [rest: 2, n: {"D4", 0.5, "Night"}, n: {"C4", 0.5, "of"}],
      # 9  unison: won-der, still, and
      [
        n: {"Bb3", 1, "won-"},
        n: {"Bb3", 1, "der,"},
        n: {"D4", 0.5, "still,"},
        n: {"F4", 0.5, "and"}
      ],
      # 10  unison: si-lent, Heav-en's
      [
        n: {"C4", 1, "si-"},
        n: {"C4", 0.5, "lent,"},
        rest: 0.5,
        n: {"D4", 0.5, "Heav-"},
        n: {"F4", 0.5, "en's"}
      ],
      # 11  unison: bril-liance from a-  ok: from/Light a scoop (~-0.7 st)
      [
        n: {"G4", 1, "bril-"},
        n: {"F4", 1, "liance"},
        n: {"D4", 0.5, "from"},
        n: {"C4", 0.5, "a-"}
      ],
      # 12  unison: bove. Light of  ok: Light scooped
      [n: {"Bb3", 1, "bove."}, rest: 1, n: {"D4", 0.5, "Light"}, n: {"C4", 0.5, "of"}],
      # 13  unison: Glo-ry pierced the
      [
        n: {"Bb3", 1, "Glo-"},
        n: {"Bb3", 1, "ry"},
        n: {"D4", 0.5, "pierced"},
        n: {"F4", 0.5, "the"}
      ],
      # 14  unison: dark-ness. Mer-cy
      [
        n: {"C4", 1, "dark-"},
        n: {"C4", 0.5, "ness."},
        rest: 0.5,
        n: {"D4", 0.5, "Mer-"},
        n: {"F4", 0.5, "cy"}
      ],
      # 15  unison: pierced my heart with
      [
        n: {"G4", 1, "pierced"},
        n: {"F4", 1, "my"},
        n: {"D4", 0.5, "heart"},
        n: {"C4", 0.5, "with"}
      ],
      # 16  unison: love. This is
      [
        n: {"Bb3", 1, "love."},
        rest: 1,
        n: {"F4", 0.5, "This"},
        n: {"G4", 0.25, "is"},
        n: {"A4", 0.25, "~is"}
      ],
      # 17  Je-sus, King of  (top of the women's thirds)
      [
        n: {"Bb4", 0.75, "Je-"},
        n: {"A4", 0.25, "~Je-"},
        n: {"A4", 1, "sus,"},
        n: {"G4", 0.5, "King"},
        n: {"F4", 0.5, "of"}
      ],
      # 18  Glo-ry, here to__  (top of the thirds; here to__ unison)  ok: score clear; Glo- slur
      #   heard Bb4 = detector's fourth-up error (a 4th above, another voice's note)
      [
        n: {"G4", 0.5, "Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"D4", 0.5, "ry,"},
        rest: 0.5,
        n: {"F4", 0.5, "here"},
        n: {"G4", 0.25, "to"},
        n: {"A4", 0.25, "~to"}
      ],
      # 19  res-cue from the  ok: score clear (res- 16th heard F4 = alto bleed)
      [
        n: {"Bb4", 0.75, "res-"},
        n: {"A4", 0.25, "~res-"},
        n: {"A4", 1, "cue"},
        n: {"G4", 0.5, "from"},
        n: {"F4", 0.5, "the"}
      ],
      # 20  fall. Son of
      [n: {"Bb4", 1, "fall."}, rest: 1, n: {"D4", 0.5, "Son"}, n: {"C4", 0.5, "of"}],
      # 21  unison: God who comes to  ok: who/to heard a 4th up = detector's fourth-up error (a
      #   4th above, another voice's note)
      [n: {"Bb3", 1, "God"}, n: {"Bb3", 1, "who"}, n: {"D4", 0.5, "comes"}, n: {"F4", 0.5, "to"}],
      # 22  unison: save us: Prince of  ok: score clear, C4 ledger line, unison with men  ok:
      #   score clear C4; us: falls to Bb3 on the release (alto track too)
      [
        n: {"C4", 1, "save"},
        n: {"C4", 0.5, "us:"},
        rest: 0.5,
        n: {"D4", 0.5, "Prince"},
        n: {"F4", 0.5, "of"}
      ],
      # 23  unison: Peace and Lord of  ok: of heard sharp, passing
      [
        n: {"G4", 1, "Peace"},
        n: {"F4", 1, "and"},
        n: {"D4", 0.5, "Lord"},
        n: {"C4", 0.25, "of"},
        n: {"Bb3", 0.25, "~of"}
      ],
      # 24  unison: All.
      [n: {"Bb3", 3, "All."}],
      # 25  (piano)
      [rest: 3],
      # 26  (piano)
      [rest: 3],
      # 27  (piano)
      [rest: 3],
      # 28  (MEN)
      [rest: 3],
      # 29  (MEN)
      [rest: 3],
      # 30  (MEN)
      [rest: 3],
      # 31  (MEN)
      [rest: 3],
      # 32  (MEN: throne) WOMEN: for a  ok: for scooped
      [rest: 2, n: {"D4", 0.5, "for"}, n: {"C4", 0.5, "a"}],
      # 33  WOMEN: man-ger, for a
      [n: {"Bb3", 1, "man-"}, n: {"Bb3", 1, "ger,"}, n: {"D4", 0.5, "for"}, n: {"F4", 0.5, "a"}],
      # 34  WOMEN: sin-ner, then ALL: for us
      [
        n: {"C4", 1, "sin-"},
        n: {"C4", 0.5, "ner,"},
        rest: 0.5,
        n: {"D4", 0.5, "for"},
        n: {"F4", 0.5, "us"}
      ],
      # 35  unison: all to be His
      [n: {"G4", 1, "all"}, n: {"F4", 1, "to"}, n: {"D4", 0.5, "be"}, n: {"C4", 0.5, "His"}],
      # 36  unison: own. This is  ok: is heard sharp, passing 16th
      [
        n: {"Bb3", 1, "own."},
        rest: 1,
        n: {"F4", 0.5, "This"},
        n: {"G4", 0.25, "is"},
        n: {"A4", 0.25, "~is"}
      ],
      # 37  Je-sus, King of  (top of the women's thirds)
      [
        n: {"Bb4", 0.75, "Je-"},
        n: {"A4", 0.25, "~Je-"},
        n: {"A4", 1, "sus,"},
        n: {"G4", 0.5, "King"},
        n: {"F4", 0.5, "of"}
      ],
      # 38  Glo-ry, here to__  (top of the thirds; here to__ unison)  ok: score clear; Glo- heard
      #   Bb4 = detector's fourth-up error (a 4th above, another voice's note)
      [
        n: {"G4", 0.5, "Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"D4", 0.5, "ry,"},
        rest: 0.5,
        n: {"F4", 0.5, "here"},
        n: {"G4", 0.25, "to"},
        n: {"A4", 0.25, "~to"}
      ],
      # 39  res-cue from the  ok: res- heard flat, scoop
      [
        n: {"Bb4", 0.75, "res-"},
        n: {"A4", 0.25, "~res-"},
        n: {"A4", 1, "cue"},
        n: {"G4", 0.5, "from"},
        n: {"F4", 0.5, "the"}
      ],
      # 40  fall. Son of
      [n: {"Bb4", 1, "fall."}, rest: 1, n: {"D4", 0.5, "Son"}, n: {"C4", 0.5, "of"}],
      # 41  unison: God who comes to  ok: who/to heard a 4th up = detector's fourth-up error (a
      #   4th above, another voice's note)
      [n: {"Bb3", 1, "God"}, n: {"Bb3", 1, "who"}, n: {"D4", 0.5, "comes"}, n: {"F4", 0.5, "to"}],
      # 42  unison: save us: Prince of
      [
        n: {"C4", 1, "save"},
        n: {"C4", 0.5, "us:"},
        rest: 0.5,
        n: {"D4", 0.5, "Prince"},
        n: {"F4", 0.5, "of"}
      ],
      # 43  unison: Peace and Lord of  ok: of heard sharp, passing
      [
        n: {"G4", 1, "Peace"},
        n: {"F4", 1, "and"},
        n: {"D4", 0.5, "Lord"},
        n: {"C4", 0.25, "of"},
        n: {"Bb3", 0.25, "~of"}
      ],
      # 44  unison: All.
      [n: {"Bb3", 3, "All."}],
      # 45  (piano)
      [rest: 3],
      # 46  (piano)
      [rest: 3],
      # 47  (piano)
      [rest: 3],
      # 48  unison: Re-
      [rest: 2.5, n: {"Bb3", 0.5, "Re-"}],
      # 49  unison: joice! He is
      [n: {"Bb3", 1, "joice!"}, n: {"C4", 1.5, "He"}, n: {"Bb3", 0.5, "is"}],
      # 50  unison: with us. Re-
      [
        n: {"Eb4", 0.5, "with"},
        n: {"D4", 0.5, "~with"},
        n: {"D4", 1, "us."},
        rest: 0.5,
        n: {"Bb3", 0.5, "Re-"}
      ],
      # 51  unison: joice! Hope is
      [n: {"Bb3", 1, "joice!"}, n: {"C4", 1.5, "Hope"}, n: {"Bb3", 0.5, "is"}],
      # 52  unison: here. Re-
      [n: {"Bb3", 2, "here."}, rest: 0.5, n: {"Bb3", 0.5, "Re-"}],
      # 53  unison: joice! He is
      [n: {"Bb3", 1, "joice!"}, n: {"C4", 1.5, "He"}, n: {"Bb3", 0.5, "is"}],
      # 54  unison: with us. Re-  ok: Re- heard a 4th up = detector's fourth-up error (a 4th
      #   above, another voice's note)
      [
        n: {"Eb4", 0.5, "with"},
        n: {"D4", 0.5, "~with"},
        n: {"D4", 1, "us."},
        rest: 0.5,
        n: {"Bb3", 0.5, "Re-"}
      ],
      # 55  unison: joice! Hope is
      [n: {"Bb3", 1, "joice!"}, n: {"C4", 1.5, "Hope"}, n: {"Bb3", 0.5, "is"}],
      # 56  WOMEN unison: here. ALL: Re-
      [n: {"Bb3", 2, "here."}, rest: 0.5, n: {"Bb4", 0.5, "Re-"}],
      # 57  joice! He is
      [n: {"Bb4", 1, "joice!"}, n: {"C5", 1.5, "He"}, n: {"Bb4", 0.5, "is"}],
      # 58  with us. Re-  ok: with heard D5, early move to D5
      [
        n: {"Eb5", 0.5, "with"},
        n: {"D5", 0.5, "~with"},
        n: {"D5", 1, "us."},
        rest: 0.5,
        n: {"Bb4", 0.5, "Re-"}
      ],
      # 59  joice! Hope is
      [n: {"Bb4", 1, "joice!"}, n: {"C5", 1.5, "Hope"}, n: {"Bb4", 0.5, "is"}],
      # 60  here. Re-
      [n: {"Bb4", 2, "here."}, rest: 0.5, n: {"Bb4", 0.5, "Re-"}],
      # 61  joice! He is
      [n: {"Bb4", 1, "joice!"}, n: {"C5", 1.5, "He"}, n: {"Bb4", 0.5, "is"}],
      # 62  with us. Re-  ok: with heard D5, early move to D5
      [
        n: {"Eb5", 0.5, "with"},
        n: {"D5", 0.5, "~with"},
        n: {"D5", 1, "us."},
        rest: 0.5,
        n: {"Bb4", 0.5, "Re-"}
      ],
      # 63  joice! Hope is
      [n: {"Bb4", 1, "joice!"}, n: {"C5", 1.5, "Hope"}, n: {"Bb4", 0.5, "is"}],
      # 64  here. This is
      [n: {"Bb4", 1, "here."}, rest: 1, n: {"Bb4", 0.5, "This"}, n: {"Bb4", 0.5, "is"}],
      # 65  Je- sus, King of
      [n: {"D5", 1, "Je-"}, n: {"C5", 1, "sus,"}, n: {"Bb4", 0.5, "King"}, n: {"Bb4", 0.5, "of"}],
      # 66  Glo- ry, here to
      [
        n: {"Eb5", 0.5, "Glo-"},
        n: {"D5", 0.5, "~Glo-"},
        n: {"D5", 0.5, "ry,"},
        rest: 0.5,
        n: {"Bb4", 0.5, "here"},
        n: {"Bb4", 0.5, "to"}
      ],
      # 67  res- cue from the
      [
        n: {"D5", 1, "res-"},
        n: {"C5", 1, "cue"},
        n: {"Bb4", 0.5, "from"},
        n: {"Bb4", 0.5, "the"}
      ],
      # 68  fall. Son of
      [n: {"Bb4", 1, "fall."}, rest: 1, n: {"Bb4", 0.5, "Son"}, n: {"Bb4", 0.5, "of"}],
      # 69  God who comes to
      [n: {"D5", 1, "God"}, n: {"C5", 1, "who"}, n: {"Bb4", 0.5, "comes"}, n: {"Bb4", 0.5, "to"}],
      # 70  save us: Prince of
      [
        n: {"Eb5", 0.5, "save"},
        n: {"D5", 0.5, "~save"},
        n: {"D5", 0.5, "us:"},
        rest: 0.5,
        n: {"Bb4", 0.5, "Prince"},
        n: {"Bb4", 0.5, "of"}
      ],
      # 71  Peace and Lord of
      [
        n: {"D5", 1, "Peace"},
        n: {"C5", 1, "and"},
        n: {"Bb4", 0.75, "Lord"},
        n: {"Bb4", 0.25, "of"}
      ],
      # 72  All.
      [n: {"Bb4", 3, "All."}],
      # 73  (All.) then unison: For the
      [n: {"Bb4", 1, "~All."}, rest: 1, n: {"D4", 0.5, "For"}, n: {"C4", 0.5, "the"}],
      # 74  unison: heart so prone to
      [
        n: {"Bb3", 1, "heart"},
        n: {"Bb3", 1, "so"},
        n: {"D4", 0.5, "prone"},
        n: {"F4", 0.5, "to"}
      ],
      # 75  unison: wan-der, for these
      [
        n: {"C4", 1, "wan-"},
        n: {"C4", 0.5, "der,"},
        rest: 0.5,
        n: {"D4", 0.5, "for"},
        n: {"F4", 0.5, "these"}
      ],
      # 76  unison: feet so quick to
      [n: {"G4", 1, "feet"}, n: {"F4", 1, "so"}, n: {"D4", 0.5, "quick"}, n: {"C4", 0.5, "to"}],
      # 77  unison: flee, God is
      [n: {"Bb3", 1, "flee,"}, rest: 1, n: {"D4", 0.5, "God"}, n: {"C4", 0.5, "is"}],
      # 78  unison: here, and Love is
      [
        n: {"Bb3", 1, "here,"},
        n: {"Bb3", 1, "and"},
        n: {"D4", 0.5, "Love"},
        n: {"F4", 0.5, "is"}
      ],
      # 79  unison: reach-ing for the
      [
        n: {"C4", 1, "reach-"},
        n: {"C4", 0.5, "ing"},
        rest: 0.5,
        n: {"D4", 0.5, "for"},
        n: {"F4", 0.5, "the"}
      ],
      # 80  unison: lost and least of (rit.)
      [n: {"G4", 1, "lost"}, n: {"F4", 1, "and"}, n: {"D4", 0.5, "least"}, n: {"C4", 0.5, "of"}],
      # 81  unison: these. (fermata)
      [n: {"Bb3", 3, "these."}]
    ]
  end

  defp alto_bars do
    [
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
      # 8  unison: Night of  ok: score clear, women+men unison 8ve; recording quiet pickup  ok:
      #   quiet pickup
      [rest: 2, n: {"D4", 0.5, "Night"}, n: {"C4", 0.5, "of"}],
      # 9  unison: won-der, still, and
      [
        n: {"Bb3", 1, "won-"},
        n: {"Bb3", 1, "der,"},
        n: {"D4", 0.5, "still,"},
        n: {"F4", 0.5, "and"}
      ],
      # 10  unison: si-lent, Heav-en's
      [
        n: {"C4", 1, "si-"},
        n: {"C4", 0.5, "lent,"},
        rest: 0.5,
        n: {"D4", 0.5, "Heav-"},
        n: {"F4", 0.5, "en's"}
      ],
      # 11  unison: bril-liance from a-
      [
        n: {"G4", 1, "bril-"},
        n: {"F4", 1, "liance"},
        n: {"D4", 0.5, "from"},
        n: {"C4", 0.5, "a-"}
      ],
      # 12  unison: bove. Light of  ok: Light scooped
      [n: {"Bb3", 1, "bove."}, rest: 1, n: {"D4", 0.5, "Light"}, n: {"C4", 0.5, "of"}],
      # 13  unison: Glo-ry pierced the
      [
        n: {"Bb3", 1, "Glo-"},
        n: {"Bb3", 1, "ry"},
        n: {"D4", 0.5, "pierced"},
        n: {"F4", 0.5, "the"}
      ],
      # 14  unison: dark-ness. Mer-cy
      [
        n: {"C4", 1, "dark-"},
        n: {"C4", 0.5, "ness."},
        rest: 0.5,
        n: {"D4", 0.5, "Mer-"},
        n: {"F4", 0.5, "cy"}
      ],
      # 15  unison: pierced my heart with
      [
        n: {"G4", 1, "pierced"},
        n: {"F4", 1, "my"},
        n: {"D4", 0.5, "heart"},
        n: {"C4", 0.5, "with"}
      ],
      # 16  unison: love. This is  ok: is heard sharp, passing
      [
        n: {"Bb3", 1, "love."},
        rest: 1,
        n: {"F4", 0.5, "This"},
        n: {"G4", 0.25, "is"},
        n: {"A4", 0.25, "~is"}
      ],
      # 17  Je-sus, King of  (G4 F4 F4 C4 C4, under the sop)  ok: 400 dpi, lower notes C4
      #   (ledger); ~Je- heard G4 = held over the 16th; of heard F4 = soprano bleed
      [
        n: {"G4", 0.75, "Je-"},
        n: {"F4", 0.25, "~Je-"},
        n: {"F4", 1, "sus,"},
        n: {"C4", 0.5, "King"},
        n: {"C4", 0.5, "of"}
      ],
      # 18  Glo-ry, here to__  (Eb4 D4 Bb3; here to__ unison)  ok: to heard sharp, passing
      [
        n: {"Eb4", 0.5, "Glo-"},
        n: {"D4", 0.5, "~Glo-"},
        n: {"Bb3", 0.5, "ry,"},
        rest: 0.5,
        n: {"F4", 0.5, "here"},
        n: {"G4", 0.25, "to"},
        n: {"A4", 0.25, "~to"}
      ],
      # 19  res-cue from the  ok: 400 dpi, from/the C4 (ledger); heard E4/Eb4 = soprano/tenor
      #   bleed (bar 39 on pitch)
      [
        n: {"G4", 0.75, "res-"},
        n: {"F4", 0.25, "~res-"},
        n: {"F4", 1, "cue"},
        n: {"C4", 0.5, "from"},
        n: {"C4", 0.5, "the"}
      ],
      # 20  fall. Son of  (Son of unison)
      [n: {"Eb4", 1, "fall."}, rest: 1, n: {"D4", 0.5, "Son"}, n: {"C4", 0.5, "of"}],
      # 21  unison: God who comes to  ok: to heard sharp
      [n: {"Bb3", 1, "God"}, n: {"Bb3", 1, "who"}, n: {"D4", 0.5, "comes"}, n: {"F4", 0.5, "to"}],
      # 22  unison: save us: Prince of  ok: score clear, C4 ledger line, unison with men  ok:
      #   score clear C4; save heard F4 = detector's fourth-up error (a 4th above, another voice's
      #   note); us: falls to Bb3 on the release
      [
        n: {"C4", 1, "save"},
        n: {"C4", 0.5, "us:"},
        rest: 0.5,
        n: {"D4", 0.5, "Prince"},
        n: {"F4", 0.5, "of"}
      ],
      # 23  unison: Peace and Lord of
      [
        n: {"G4", 1, "Peace"},
        n: {"F4", 1, "and"},
        n: {"D4", 0.5, "Lord"},
        n: {"C4", 0.25, "of"},
        n: {"Bb3", 0.25, "~of"}
      ],
      # 24  unison: All.
      [n: {"Bb3", 3, "All."}],
      # 25  (piano)
      [rest: 3],
      # 26  (piano)
      [rest: 3],
      # 27  (piano)
      [rest: 3],
      # 28  (MEN)
      [rest: 3],
      # 29  (MEN)
      [rest: 3],
      # 30  (MEN)
      [rest: 3],
      # 31  (MEN)
      [rest: 3],
      # 32  (MEN: throne) WOMEN: for a
      [rest: 2, n: {"D4", 0.5, "for"}, n: {"C4", 0.5, "a"}],
      # 33  WOMEN: man-ger, for a
      [n: {"Bb3", 1, "man-"}, n: {"Bb3", 1, "ger,"}, n: {"D4", 0.5, "for"}, n: {"F4", 0.5, "a"}],
      # 34  WOMEN: sin-ner, then ALL: for us
      [
        n: {"C4", 1, "sin-"},
        n: {"C4", 0.5, "ner,"},
        rest: 0.5,
        n: {"D4", 0.5, "for"},
        n: {"F4", 0.5, "us"}
      ],
      # 35  unison: all to be His
      [n: {"G4", 1, "all"}, n: {"F4", 1, "to"}, n: {"D4", 0.5, "be"}, n: {"C4", 0.5, "His"}],
      # 36  unison: own. This is  ok: is heard sharp
      [
        n: {"Bb3", 1, "own."},
        rest: 1,
        n: {"F4", 0.5, "This"},
        n: {"G4", 0.25, "is"},
        n: {"A4", 0.25, "~is"}
      ],
      # 37  Je-sus, King of  (G4 F4 F4 C4 C4, under the sop)  ok: ~Je- heard G4 = held over the
      #   16th
      [
        n: {"G4", 0.75, "Je-"},
        n: {"F4", 0.25, "~Je-"},
        n: {"F4", 1, "sus,"},
        n: {"C4", 0.5, "King"},
        n: {"C4", 0.5, "of"}
      ],
      # 38  Glo-ry, here to__  (Eb4 D4 Bb3; here to__ unison)  ok: ry, heard sharp
      [
        n: {"Eb4", 0.5, "Glo-"},
        n: {"D4", 0.5, "~Glo-"},
        n: {"Bb3", 0.5, "ry,"},
        rest: 0.5,
        n: {"F4", 0.5, "here"},
        n: {"G4", 0.25, "to"},
        n: {"A4", 0.25, "~to"}
      ],
      # 39  res-cue from the
      [
        n: {"G4", 0.75, "res-"},
        n: {"F4", 0.25, "~res-"},
        n: {"F4", 1, "cue"},
        n: {"C4", 0.5, "from"},
        n: {"C4", 0.5, "the"}
      ],
      # 40  fall. Son of  (Son of unison)
      [n: {"Eb4", 1, "fall."}, rest: 1, n: {"D4", 0.5, "Son"}, n: {"C4", 0.5, "of"}],
      # 41  unison: God who comes to
      [n: {"Bb3", 1, "God"}, n: {"Bb3", 1, "who"}, n: {"D4", 0.5, "comes"}, n: {"F4", 0.5, "to"}],
      # 42  unison: save us: Prince of  ok: save heard F4 = detector's fourth-up error (a 4th
      #   above, another voice's note)
      [
        n: {"C4", 1, "save"},
        n: {"C4", 0.5, "us:"},
        rest: 0.5,
        n: {"D4", 0.5, "Prince"},
        n: {"F4", 0.5, "of"}
      ],
      # 43  unison: Peace and Lord of
      [
        n: {"G4", 1, "Peace"},
        n: {"F4", 1, "and"},
        n: {"D4", 0.5, "Lord"},
        n: {"C4", 0.25, "of"},
        n: {"Bb3", 0.25, "~of"}
      ],
      # 44  unison: All.
      [n: {"Bb3", 3, "All."}],
      # 45  (piano)
      [rest: 3],
      # 46  (piano)
      [rest: 3],
      # 47  (piano)
      [rest: 3],
      # 48  unison: Re-
      [rest: 2.5, n: {"Bb3", 0.5, "Re-"}],
      # 49  unison: joice! He is
      [n: {"Bb3", 1, "joice!"}, n: {"C4", 1.5, "He"}, n: {"Bb3", 0.5, "is"}],
      # 50  unison: with us. Re-
      [
        n: {"Eb4", 0.5, "with"},
        n: {"D4", 0.5, "~with"},
        n: {"D4", 1, "us."},
        rest: 0.5,
        n: {"Bb3", 0.5, "Re-"}
      ],
      # 51  unison: joice! Hope is
      [n: {"Bb3", 1, "joice!"}, n: {"C4", 1.5, "Hope"}, n: {"Bb3", 0.5, "is"}],
      # 52  unison: here. Re-
      [n: {"Bb3", 2, "here."}, rest: 0.5, n: {"Bb3", 0.5, "Re-"}],
      # 53  unison: joice! He is
      [n: {"Bb3", 1, "joice!"}, n: {"C4", 1.5, "He"}, n: {"Bb3", 0.5, "is"}],
      # 54  unison: with us. Re-
      [
        n: {"Eb4", 0.5, "with"},
        n: {"D4", 0.5, "~with"},
        n: {"D4", 1, "us."},
        rest: 0.5,
        n: {"Bb3", 0.5, "Re-"}
      ],
      # 55  unison: joice! Hope is
      [n: {"Bb3", 1, "joice!"}, n: {"C4", 1.5, "Hope"}, n: {"Bb3", 0.5, "is"}],
      # 56  WOMEN unison: here. ALL: Re-
      [n: {"Bb3", 2, "here."}, rest: 0.5, n: {"Eb4", 0.5, "Re-"}],
      # 57  joice! He is
      [n: {"D4", 1, "joice!"}, n: {"F4", 1.5, "He"}, n: {"F4", 0.5, "is"}],
      # 58  with us. Re-  ok: score clear; F4s heard Bb4/A4 = soprano bleed / detector's fourth-up
      #   error (a 4th above, another voice's note)
      [
        n: {"G4", 0.5, "with"},
        n: {"F4", 0.5, "~with"},
        n: {"F4", 1, "us."},
        rest: 0.5,
        n: {"F4", 0.5, "Re-"}
      ],
      # 59  joice! Hope is
      [n: {"D4", 1, "joice!"}, n: {"F4", 1.5, "Hope"}, n: {"F4", 0.5, "is"}],
      # 60  here. Re-
      [n: {"Eb4", 2, "here."}, rest: 0.5, n: {"Eb4", 0.5, "Re-"}],
      # 61  joice! He is  ok: is heard Bb4 = soprano bleed
      [n: {"D4", 1, "joice!"}, n: {"F4", 1.5, "He"}, n: {"F4", 0.5, "is"}],
      # 62  with us. Re-
      [
        n: {"G4", 0.5, "with"},
        n: {"F4", 0.5, "~with"},
        n: {"F4", 1, "us."},
        rest: 0.5,
        n: {"F4", 0.5, "Re-"}
      ],
      # 63  joice! Hope is  ok: is heard Bb4 = soprano bleed
      [n: {"D4", 1, "joice!"}, n: {"F4", 1.5, "Hope"}, n: {"F4", 0.5, "is"}],
      # 64  here. This is
      [n: {"Eb4", 1, "here."}, rest: 1, n: {"Eb4", 0.5, "This"}, n: {"Eb4", 0.5, "is"}],
      # 65  Je- sus, King of  ok: score clear F4; heard Bb4 = soprano bleed
      [n: {"G4", 1, "Je-"}, n: {"F4", 1, "sus,"}, n: {"F4", 0.5, "King"}, n: {"F4", 0.5, "of"}],
      # 66  Glo- ry, here to  ok: score clear F4; heard Bb4 = soprano bleed
      [
        n: {"G4", 0.5, "Glo-"},
        n: {"F4", 0.5, "~Glo-"},
        n: {"F4", 0.5, "ry,"},
        rest: 0.5,
        n: {"F4", 0.5, "here"},
        n: {"F4", 0.5, "to"}
      ],
      # 67  res- cue from the  ok: the heard Bb4 = soprano bleed
      [n: {"G4", 1, "res-"}, n: {"F4", 1, "cue"}, n: {"F4", 0.5, "from"}, n: {"F4", 0.5, "the"}],
      # 68  fall. Son of
      [n: {"Eb4", 1, "fall."}, rest: 1, n: {"Eb4", 0.5, "Son"}, n: {"Eb4", 0.5, "of"}],
      # 69  God who comes to  ok: to heard Bb4 = soprano bleed
      [n: {"G4", 1, "God"}, n: {"F4", 1, "who"}, n: {"F4", 0.5, "comes"}, n: {"F4", 0.5, "to"}],
      # 70  save us: Prince of  ok: save heard Bb4 = soprano bleed; Prince scooped
      [
        n: {"G4", 0.5, "save"},
        n: {"F4", 0.5, "~save"},
        n: {"F4", 0.5, "us:"},
        rest: 0.5,
        n: {"F4", 0.5, "Prince"},
        n: {"F4", 0.5, "of"}
      ],
      # 71  Peace and Lord of  ok: of heard Bb4 = soprano bleed
      [
        n: {"G4", 1, "Peace"},
        n: {"F4", 1, "and"},
        n: {"F4", 0.75, "Lord"},
        n: {"F4", 0.25, "of"}
      ],
      # 72  All.
      [n: {"Eb4", 3, "All."}],
      # 73  (All.) then unison: For the
      [n: {"Eb4", 1, "~All."}, rest: 1, n: {"D4", 0.5, "For"}, n: {"C4", 0.5, "the"}],
      # 74  unison: heart so prone to
      [
        n: {"Bb3", 1, "heart"},
        n: {"Bb3", 1, "so"},
        n: {"D4", 0.5, "prone"},
        n: {"F4", 0.5, "to"}
      ],
      # 75  unison: wan-der, for these
      [
        n: {"C4", 1, "wan-"},
        n: {"C4", 0.5, "der,"},
        rest: 0.5,
        n: {"D4", 0.5, "for"},
        n: {"F4", 0.5, "these"}
      ],
      # 76  unison: feet so quick to
      [n: {"G4", 1, "feet"}, n: {"F4", 1, "so"}, n: {"D4", 0.5, "quick"}, n: {"C4", 0.5, "to"}],
      # 77  unison: flee, God is
      [n: {"Bb3", 1, "flee,"}, rest: 1, n: {"D4", 0.5, "God"}, n: {"C4", 0.5, "is"}],
      # 78  unison: here, and Love is
      [
        n: {"Bb3", 1, "here,"},
        n: {"Bb3", 1, "and"},
        n: {"D4", 0.5, "Love"},
        n: {"F4", 0.5, "is"}
      ],
      # 79  unison: reach-ing for the
      [
        n: {"C4", 1, "reach-"},
        n: {"C4", 0.5, "ing"},
        rest: 0.5,
        n: {"D4", 0.5, "for"},
        n: {"F4", 0.5, "the"}
      ],
      # 80  unison: lost and least of (rit.)
      [n: {"G4", 1, "lost"}, n: {"F4", 1, "and"}, n: {"D4", 0.5, "least"}, n: {"C4", 0.5, "of"}],
      # 81  unison: these. (fermata)
      [n: {"Bb3", 3, "these."}]
    ]
  end

  defp tenor_bars do
    [
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
      # 8  unison: Night of  ok: quiet pickup
      [rest: 2, n: {"D3", 0.5, "Night"}, n: {"C3", 0.5, "of"}],
      # 9  unison: won-der, still, and
      [
        n: {"Bb2", 1, "won-"},
        n: {"Bb2", 1, "der,"},
        n: {"D3", 0.5, "still,"},
        n: {"F3", 0.5, "and"}
      ],
      # 10  unison: si-lent, Heav-en's
      [
        n: {"C3", 1, "si-"},
        n: {"C3", 0.5, "lent,"},
        rest: 0.5,
        n: {"D3", 0.5, "Heav-"},
        n: {"F3", 0.5, "en's"}
      ],
      # 11  unison: bril-liance from a-  ok: from scooped
      [
        n: {"G3", 1, "bril-"},
        n: {"F3", 1, "liance"},
        n: {"D3", 0.5, "from"},
        n: {"C3", 0.5, "a-"}
      ],
      # 12  unison: bove. Light of  ok: Light scooped
      [n: {"Bb2", 1, "bove."}, rest: 1, n: {"D3", 0.5, "Light"}, n: {"C3", 0.5, "of"}],
      # 13  unison: Glo-ry pierced the
      [
        n: {"Bb2", 1, "Glo-"},
        n: {"Bb2", 1, "ry"},
        n: {"D3", 0.5, "pierced"},
        n: {"F3", 0.5, "the"}
      ],
      # 14  unison: dark-ness. Mer-cy
      [
        n: {"C3", 1, "dark-"},
        n: {"C3", 0.5, "ness."},
        rest: 0.5,
        n: {"D3", 0.5, "Mer-"},
        n: {"F3", 0.5, "cy"}
      ],
      # 15  unison: pierced my heart with  ok: heart scooped
      [
        n: {"G3", 1, "pierced"},
        n: {"F3", 1, "my"},
        n: {"D3", 0.5, "heart"},
        n: {"C3", 0.5, "with"}
      ],
      # 16  unison: love. This is__
      [
        n: {"Bb2", 1, "love."},
        rest: 1,
        n: {"F3", 0.5, "This"},
        n: {"G3", 0.25, "is"},
        n: {"A3", 0.25, "~is"}
      ],
      # 17  Je-sus, King of  (upper of the bass staff)  ok: 400 dpi, D4 C4 C4 Bb3 A3 over the
      #   bass; Je-/King heard a 4th off = detector's fourth-up error (a 4th above, another
      #   voice's note) (bar 37 Je- on D4)
      [
        n: {"D4", 0.75, "Je-"},
        n: {"C4", 0.25, "~Je-"},
        n: {"C4", 1, "sus,"},
        n: {"Bb3", 0.5, "King"},
        n: {"A3", 0.5, "of"}
      ],
      # 18  Glo-ry, here to__  (Bb3 F3; here to__ unison)  ok: ry,/to heard sharp, passing
      [
        n: {"Bb3", 1, "Glo-"},
        n: {"F3", 0.5, "ry,"},
        rest: 0.5,
        n: {"F3", 0.5, "here"},
        n: {"G3", 0.25, "to"},
        n: {"A3", 0.25, "~to"}
      ],
      # 19  res-cue from the  ok: 400 dpi, C4; cue heard F4 = detector's fourth-up error (a 4th
      #   above, another voice's note)
      [
        n: {"D4", 0.75, "res-"},
        n: {"C4", 0.25, "~res-"},
        n: {"C4", 1, "cue"},
        n: {"Bb3", 0.5, "from"},
        n: {"A3", 0.5, "the"}
      ],
      # 20  fall. Son of  (G3; men unison harm.)  ok: fall. heard sharp
      [n: {"G3", 1, "fall."}, rest: 1, n: {"F3", 0.5, "Son"}, n: {"Eb3", 0.5, "of"}],
      # 21  unison: God who comes to
      [
        n: {"D3", 1, "God"},
        n: {"D3", 1, "who"},
        n: {"F3", 0.5, "comes"},
        n: {"Bb3", 0.5, "to"}
      ],
      # 22  unison: save us: Prince of  ok: Prince heard sharp
      [
        n: {"A3", 1, "save"},
        n: {"A3", 0.5, "us:"},
        rest: 0.5,
        n: {"A3", 0.5, "Prince"},
        n: {"A3", 0.5, "of"}
      ],
      # 23  unison: Peace and Lord of__  ok: of scooped
      [
        n: {"Bb3", 1, "Peace"},
        n: {"Bb3", 1, "and"},
        n: {"F3", 0.5, "Lord"},
        n: {"Eb3", 0.25, "of"},
        n: {"D3", 0.25, "~of"}
      ],
      # 24  unison: All.
      [n: {"D3", 3, "All."}],
      # 25  (piano)
      [rest: 3],
      # 26  (piano)
      [rest: 3],
      # 27  (piano)
      [rest: 3],
      # 28  unison: Oh, the (MEN)  ok: Oh, quiet pickup
      [rest: 2, n: {"D3", 0.5, "Oh,"}, n: {"C3", 0.5, "the"}],
      # 29  unison: mys-t'ry, who could
      [
        n: {"Bb2", 1, "mys-"},
        n: {"Bb2", 1, "t'ry,"},
        n: {"D3", 0.5, "who"},
        n: {"F3", 0.5, "could"}
      ],
      # 30  unison: fath-om? God would
      [
        n: {"C3", 1, "fath-"},
        n: {"C3", 0.5, "om?"},
        rest: 0.5,
        n: {"D3", 0.5, "God"},
        n: {"F3", 0.5, "would"}
      ],
      # 31  unison: leave His Ho-ly  ok: Ho- scooped
      [n: {"G3", 1, "leave"}, n: {"F3", 1, "His"}, n: {"D3", 0.5, "Ho-"}, n: {"C3", 0.5, "ly"}],
      # 32  MEN: throne (then WOMEN)
      [n: {"Bb2", 1, "throne"}, rest: 2],
      # 33  (WOMEN: man-ger, for a)
      [rest: 3],
      # 34  (sin-ner,) ALL: for us
      [rest: 2, n: {"D3", 0.5, "for"}, n: {"F3", 0.5, "us"}],
      # 35  unison: all to be His
      [n: {"G3", 1, "all"}, n: {"F3", 1, "to"}, n: {"D3", 0.5, "be"}, n: {"C3", 0.5, "His"}],
      # 36  unison: own. This is__  ok: is heard sharp
      [
        n: {"Bb2", 1, "own."},
        rest: 1,
        n: {"F3", 0.5, "This"},
        n: {"G3", 0.25, "is"},
        n: {"A3", 0.25, "~is"}
      ],
      # 37  Je-sus, King of  (upper of the bass staff)  ok: Je- 16th / sus, heard off = detector's
      #   fourth-up error (a 4th above, another voice's note)
      [
        n: {"D4", 0.75, "Je-"},
        n: {"C4", 0.25, "~Je-"},
        n: {"C4", 1, "sus,"},
        n: {"Bb3", 0.5, "King"},
        n: {"A3", 0.5, "of"}
      ],
      # 38  Glo-ry, here to__  (Bb3 F3; here to__ unison)  ok: to heard sharp
      [
        n: {"Bb3", 1, "Glo-"},
        n: {"F3", 0.5, "ry,"},
        rest: 0.5,
        n: {"F3", 0.5, "here"},
        n: {"G3", 0.25, "to"},
        n: {"A3", 0.25, "~to"}
      ],
      # 39  res-cue from the  ok: res-/cue heard F4 = detector's fourth-up error (a 4th above,
      #   another voice's note)
      [
        n: {"D4", 0.75, "res-"},
        n: {"C4", 0.25, "~res-"},
        n: {"C4", 1, "cue"},
        n: {"Bb3", 0.5, "from"},
        n: {"A3", 0.5, "the"}
      ],
      # 40  fall. Son of  (G3; men unison harm.)
      [n: {"G3", 1, "fall."}, rest: 1, n: {"F3", 0.5, "Son"}, n: {"Eb3", 0.5, "of"}],
      # 41  unison: God who comes to
      [
        n: {"D3", 1, "God"},
        n: {"D3", 1, "who"},
        n: {"F3", 0.5, "comes"},
        n: {"Bb3", 0.5, "to"}
      ],
      # 42  unison: save us: Prince of
      [
        n: {"A3", 1, "save"},
        n: {"A3", 0.5, "us:"},
        rest: 0.5,
        n: {"A3", 0.5, "Prince"},
        n: {"A3", 0.5, "of"}
      ],
      # 43  unison: Peace and Lord of  ok: Peace heard Eb4 = detector's fourth-up error (a 4th
      #   above, another voice's note); of scooped
      [
        n: {"Bb3", 1, "Peace"},
        n: {"Bb3", 1, "and"},
        n: {"F3", 0.5, "Lord"},
        n: {"Eb3", 0.25, "of"},
        n: {"D3", 0.25, "~of"}
      ],
      # 44  unison: All.
      [n: {"D3", 3, "All."}],
      # 45  (piano)
      [rest: 3],
      # 46  (piano)
      [rest: 3],
      # 47  (piano)
      [rest: 3],
      # 48  unison: Re-
      [rest: 2.5, n: {"Bb2", 0.5, "Re-"}],
      # 49  unison: joice! He is
      [n: {"Bb2", 1, "joice!"}, n: {"C3", 1.5, "He"}, n: {"Bb2", 0.5, "is"}],
      # 50  unison: with us. Re-  ok: with heard D3 = early slur to D3
      [
        n: {"Eb3", 0.5, "with"},
        n: {"D3", 0.5, "~with"},
        n: {"D3", 1, "us."},
        rest: 0.5,
        n: {"Bb2", 0.5, "Re-"}
      ],
      # 51  unison: joice! Hope is
      [n: {"Bb2", 1, "joice!"}, n: {"C3", 1.5, "Hope"}, n: {"Bb2", 0.5, "is"}],
      # 52  unison: here. Re-
      [n: {"Bb2", 2, "here."}, rest: 0.5, n: {"Bb2", 0.5, "Re-"}],
      # 53  unison: joice! He is
      [n: {"Bb2", 1, "joice!"}, n: {"C3", 1.5, "He"}, n: {"Bb2", 0.5, "is"}],
      # 54  unison: with us. Re-
      [
        n: {"Eb3", 0.5, "with"},
        n: {"F3", 0.5, "~with"},
        n: {"F3", 1, "us."},
        rest: 0.5,
        n: {"F3", 0.5, "Re-"}
      ],
      # 55  unison: joice! Hope is
      [n: {"G3", 1, "joice!"}, n: {"F3", 1.5, "Hope"}, n: {"Bb3", 0.5, "is"}],
      # 56  MEN unison: here. ALL: Re-  ok: 400 dpi, G3 over Eb3; heard Bb3 = soprano's Bb4 an
      #   octave down
      [n: {"Bb3", 2, "here."}, rest: 0.5, n: {"G3", 0.5, "Re-"}],
      # 57  joice! He is  ok: He heard slightly sharp
      [n: {"Bb3", 1, "joice!"}, n: {"A3", 1.5, "He"}, n: {"Bb3", 0.5, "is"}],
      # 58  with us. Re-  ok: with heard D4 = detector's fourth-up error (a 4th above, another
      #   voice's note)
      [n: {"Bb3", 1, "with"}, n: {"Bb3", 1, "us."}, rest: 0.5, n: {"D4", 0.5, "Re-"}],
      # 59  joice! Hope is
      [n: {"Bb3", 1, "joice!"}, n: {"A3", 1.5, "Hope"}, n: {"Bb3", 0.5, "is"}],
      # 60  here. Re-  ok: 400 dpi, G3/Eb3 half; heard Bb3 = soprano's Bb4 an octave down
      [n: {"G3", 2, "here."}, rest: 0.5, n: {"G3", 0.5, "Re-"}],
      # 61  joice! He is  ok: score clear A3 (over F3); heard C4 = soprano's C5 an octave down
      [n: {"Bb3", 1, "joice!"}, n: {"A3", 1.5, "He"}, n: {"Bb3", 0.5, "is"}],
      # 62  with us. Re-
      [n: {"Bb3", 1, "with"}, n: {"Bb3", 1, "us."}, rest: 0.5, n: {"D4", 0.5, "Re-"}],
      # 63  joice! Hope is  ok: Hope heard flat
      [n: {"Bb3", 1, "joice!"}, n: {"A3", 1.5, "Hope"}, n: {"Bb3", 0.5, "is"}],
      # 64  here. This is  ok: G3 under Eb chord; heard Bb3 = soprano's Bb4 an octave down
      [n: {"G3", 1, "here."}, rest: 1, n: {"G3", 0.5, "This"}, n: {"G3", 0.5, "is"}],
      # 65  Je- sus, King of
      [
        n: {"Bb3", 1, "Je-"},
        n: {"A3", 1, "sus,"},
        n: {"Bb3", 0.5, "King"},
        n: {"Bb3", 0.5, "of"}
      ],
      # 66  Glo- ry, here to  ok: heard sharp, intonation
      [
        n: {"Bb3", 1, "Glo-"},
        n: {"Bb3", 0.5, "ry,"},
        rest: 0.5,
        n: {"D4", 0.5, "here"},
        n: {"D4", 0.5, "to"}
      ],
      # 67  res- cue from the
      [
        n: {"Bb3", 1, "res-"},
        n: {"A3", 1, "cue"},
        n: {"Bb3", 0.5, "from"},
        n: {"Bb3", 0.5, "the"}
      ],
      # 68  fall. Son of
      [n: {"G3", 1, "fall."}, rest: 1, n: {"G3", 0.5, "Son"}, n: {"G3", 0.5, "of"}],
      # 69  God who comes to  ok: score clear A3; who heard C4 = soprano's C5 an octave down
      [
        n: {"Bb3", 1, "God"},
        n: {"A3", 1, "who"},
        n: {"Bb3", 0.5, "comes"},
        n: {"Bb3", 0.5, "to"}
      ],
      # 70  save us: Prince of  ok: save heard sharp
      [
        n: {"Bb3", 1, "save"},
        n: {"Bb3", 0.5, "us:"},
        rest: 0.5,
        n: {"D4", 0.5, "Prince"},
        n: {"D4", 0.5, "of"}
      ],
      # 71  Peace and Lord of
      [
        n: {"Bb3", 1, "Peace"},
        n: {"A3", 1, "and"},
        n: {"Bb3", 0.75, "Lord"},
        n: {"Bb3", 0.25, "of"}
      ],
      # 72  All.
      [n: {"G3", 3, "All."}],
      # 73  (All.) then unison: For the  ok: For scooped
      [n: {"G3", 1, "~All."}, rest: 1, n: {"D3", 0.5, "For"}, n: {"C3", 0.5, "the"}],
      # 74  unison: heart so prone to
      [
        n: {"Bb2", 1, "heart"},
        n: {"Bb2", 1, "so"},
        n: {"D3", 0.5, "prone"},
        n: {"F3", 0.5, "to"}
      ],
      # 75  unison: wan-der, for these
      [
        n: {"C3", 1, "wan-"},
        n: {"C3", 0.5, "der,"},
        rest: 0.5,
        n: {"D3", 0.5, "for"},
        n: {"F3", 0.5, "these"}
      ],
      # 76  unison: feet so quick to
      [n: {"G3", 1, "feet"}, n: {"F3", 1, "so"}, n: {"D3", 0.5, "quick"}, n: {"C3", 0.5, "to"}],
      # 77  unison: flee, God is
      [n: {"Bb2", 1, "flee,"}, rest: 1, n: {"D3", 0.5, "God"}, n: {"C3", 0.5, "is"}],
      # 78  unison: here, and Love is
      [
        n: {"Bb2", 1, "here,"},
        n: {"Bb2", 1, "and"},
        n: {"D3", 0.5, "Love"},
        n: {"F3", 0.5, "is"}
      ],
      # 79  unison: reach-ing for the
      [
        n: {"C3", 1, "reach-"},
        n: {"C3", 0.5, "ing"},
        rest: 0.5,
        n: {"D3", 0.5, "for"},
        n: {"F3", 0.5, "the"}
      ],
      # 80  unison: lost and least of (rit.)
      [
        n: {"G3", 1, "lost"},
        n: {"F3", 1, "and"},
        n: {"D3", 0.5, "least"},
        n: {"C3", 0.5, "of"}
      ],
      # 81  unison: these. (fermata)
      [n: {"Bb2", 3, "these."}]
    ]
  end
end
