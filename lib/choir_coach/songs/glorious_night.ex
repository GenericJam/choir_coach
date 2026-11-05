defmodule ChoirCoach.Songs.GloriousNight do
  @moduledoc """
  "What a Glorious Night" (arr. Russell Mauldin), bass part, bars 20–27.

  Transcribed from the Drive score (pages 2–3). In this verse the men sing the
  melody an octave below the women, so these are the bass-clef noteheads.
  Tempo is the opening marking (♩ = 105); bar timings are not yet aligned to
  the rehearsal track.
  """

  alias ChoirCoach.Song

  @spec verse_excerpt() :: Song.t()
  def verse_excerpt do
    Song.build(
      title: "What a Glorious Night",
      part: :bass,
      clef: :bass,
      key_name: "C major",
      tempo_bpm: 105,
      beats_per_bar: 4,
      first_bar: 20,
      bars: [
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
        # 23  (side, tied) — rest
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
        [n: {"C3", 2, "night."}, rest: 2]
      ]
    )
  end
end
