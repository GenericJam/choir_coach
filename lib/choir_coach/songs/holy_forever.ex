defmodule ChoirCoach.Songs.HolyForever do
  @moduledoc """
  "Holy Forever (Christmas)" (Phil Wickham, Jason Ingram, Chris Tomlin, Chris Davenport, Jenn Johnson
  and Brian Johnson, arr. Russell Mauldin), bass part, bars 1–98.

  Transcribed from the Drive score, bar by bar, and checked note by note
  against the Bass rehearsal track with the pitch detector: every note it
  hears off the written pitch was re-read at 400 dpi (most are the tenor,
  who shares the channel, or a scoop into the note).

  Timing is the Bass rehearsal track's, fitted with `scripts/align_track.exs`:
  bar 1 starts 750 ms in, ♩ = 72 steady, the rit. over bar 97 and the final
  fermata (a rest; its length is a choice) as `bar_ms`. Split and Demo offsets
  come from cross-correlating their accompaniment with the rehearsal track's.
  """

  alias ChoirCoach.Song

  @doc "Where bar 1 falls on each track (ms), and which channel holds the voices."
  def tracks do
    %{
      rehearsal: %{
        file: "holy_forever/bass.mp3",
        bar1_ms: 750.0,
        voice: :left,
        label: "Bass rehearsal"
      },
      split: %{
        file: "holy_forever/split.mp3",
        bar1_ms: 816.0,
        voice: :right,
        label: "Split track"
      },
      demo: %{file: "holy_forever/demo.mp3", bar1_ms: 614.0, voice: :mixed, label: "Demo"}
    }
  end

  @spec bass() :: Song.t()
  def bass do
    Song.build(
      title: "Holy Forever (Christmas)",
      part: :bass,
      clef: :bass,
      key: 2,
      tempo_bpm: 72,
      beats_per_bar: 4,
      first_bar: 1,
      start_ms: 750.0,
      bar_ms: %{97 => 4_427.0, 98 => 6_000.0},
      bars: [
        # 1  (bass tacet)
        [rest: 4],
        # 2  (bass tacet)
        [rest: 4],
        # 3  (bass tacet)
        [rest: 4],
        # 4  (bass tacet)
        [rest: 4],
        # 5  (bass tacet)
        [rest: 4],
        # 6  (bass tacet)
        [rest: 4],
        # 7  (bass tacet)
        [rest: 4],
        # 8  (bass tacet)
        [rest: 4],
        # 9  (bass tacet)
        [rest: 4],
        # 10  (bass tacet)
        [rest: 4],
        # 11  (bass tacet)
        [rest: 4],
        # 12  (bass tacet)
        [rest: 4],
        # 13  (bass tacet)
        [rest: 4],
        # 14  (bass tacet)
        [rest: 4],
        # 15  (bass tacet)
        [rest: 4],
        # 16  (bass tacet)
        [rest: 4],
        # 17  (bass tacet)
        [rest: 4],
        # 18  (bass tacet)
        [rest: 4],
        # 19  (bass tacet)
        [rest: 4],
        # 20  all. And the an-gels cry,  (add BASSES after beat 1)
        [
          rest: 1.5,
          n: {"D3", 0.25, "And"},
          n: {"E3", 0.25, "the"},
          n: {"F#3", 0.75, "an-"},
          n: {"A3", 0.75, "gels"},
          n: {"G3", 0.5, "cry,"}
        ],
        # 21  "Ho-
        [n: {"G3", 1, "~cry,"}, rest: 1, n: {"G3", 1, "Ho-"}, n: {"B3", 1, "~Ho-"}],
        # 22  ly." All cre-a-tion cries,
        [
          n: {"A3", 1, "ly."},
          rest: 0.5,
          n: {"A3", 0.25, "All"},
          n: {"B3", 0.25, "cre-"},
          n: {"A3", 0.75, "a-"},
          n: {"A3", 0.75, "tion"},
          n: {"F#3", 0.5, "cries,"}
        ],
        # 23  "Ho-
        [n: {"F#3", 1, "~cries,"}, rest: 1, n: {"F#3", 2, "Ho-"}],
        # 24  ly." You are lift-ed high,
        [
          n: {"B2", 1, "ly."},
          rest: 0.5,
          n: {"B2", 0.25, "You"},
          n: {"B2", 0.25, "are"},
          n: {"B2", 0.75, "lift-"},
          n: {"B2", 0.75, "ed"},
          n: {"E3", 0.5, "high,"}
        ],
        # 25  ho-
        [n: {"E3", 1, "~high,"}, rest: 1, n: {"E3", 2, "ho-"}],
        # 26  ly! Ho-ly for-ev-
        [
          n: {"A3", 1, "ly!"},
          rest: 1,
          n: {"A3", 0.5, "Ho-"},
          n: {"A3", 0.5, "ly"},
          n: {"A3", 0.5, "for-"},
          n: {"D3", 0.5, "ev-"}
        ],
        # 27  er!
        [n: {"D3", 0.5, "~ev-"}, n: {"D3", 3.5, "er!"}],
        # 28  In the
        [rest: 3.5, n: {"F#3", 0.25, "In"}, n: {"G3", 0.25, "the"}],
        # 29  hum-ble town of Da-vid, a
        [
          n: {"A3", 0.5, "hum-"},
          n: {"A3", 0.25, "ble"},
          n: {"A3", 0.75, "town"},
          n: {"G3", 0.25, "of"},
          n: {"G3", 0.5, "Da-"},
          n: {"F#3", 0.75, "vid,"},
          rest: 0.75,
          n: {"F#3", 0.25, "a"}
        ],
        # 30  Sav-ior born to-day, the
        [
          n: {"G3", 0.5, "Sav-"},
          n: {"G3", 0.25, "ior"},
          n: {"G3", 0.75, "born"},
          n: {"F#3", 0.25, "to-"},
          n: {"A3", 1.25, "day,"},
          rest: 0.75,
          n: {"A3", 0.25, "the"}
        ],
        # 31  One who would be called Em-man-u-el.
        [
          n: {"B3", 0.5, "One"},
          n: {"B3", 0.25, "who"},
          n: {"B3", 0.75, "would"},
          n: {"B3", 0.25, "be"},
          n: {"A3", 0.75, "called"},
          n: {"A3", 0.25, "Em-"},
          n: {"A3", 0.75, "man-"},
          n: {"G3", 0.25, "u-"},
          n: {"G3", 0.25, "el."}
        ],
        # 32  (el.) Be-
        [n: {"G3", 2, "~el."}, rest: 1, rest: 0.75, n: {"G3", 0.25, "Be-"}],
        # 33  hold the host of heav-en with
        [
          n: {"A3", 0.5, "hold"},
          n: {"A3", 0.25, "the"},
          n: {"A3", 0.75, "host"},
          n: {"G3", 0.25, "of"},
          n: {"G3", 0.5, "heav-"},
          n: {"F#3", 0.75, "en"},
          rest: 0.75,
          n: {"F#3", 0.25, "with"}
        ],
        # 34  ho-ly roar pro-claim the
        [
          n: {"G3", 0.5, "ho-"},
          n: {"G3", 0.25, "ly"},
          n: {"G3", 0.75, "roar"},
          n: {"F#3", 0.25, "pro-"},
          n: {"A3", 1.25, "claim"},
          rest: 0.75,
          n: {"A3", 0.25, "the"}
        ],
        # 35  One who would be called Em-man-u-el.
        [
          n: {"B3", 0.5, "One"},
          n: {"B3", 0.25, "who"},
          n: {"B3", 0.75, "would"},
          n: {"B3", 0.25, "be"},
          n: {"A3", 0.75, "called"},
          n: {"A3", 0.25, "Em-"},
          n: {"A3", 0.75, "man-"},
          n: {"G3", 0.25, "u-"},
          n: {"G3", 0.25, "el."}
        ],
        # 36  (el.) The Mes-
        [
          n: {"G3", 2, "~el."},
          rest: 1,
          rest: 0.5,
          n: {"G3", 0.25, "The"},
          n: {"G3", 0.25, "Mes-"}
        ],
        # 37  si-ah, our God, is with us now!
        [
          n: {"B3", 0.75, "si-"},
          n: {"B3", 0.75, "ah,"},
          rest: 0.25,
          n: {"B3", 0.25, "our"},
          n: {"B3", 0.75, "God,"},
          n: {"A3", 0.25, "is"},
          n: {"A3", 0.25, "with"},
          n: {"G3", 0.5, "us"},
          n: {"G3", 0.25, "now!"}
        ],
        # 38  (now!) And the an-gels cry,
        [
          n: {"G3", 1, "~now!"},
          rest: 0.5,
          n: {"D3", 0.25, "And"},
          n: {"E3", 0.25, "the"},
          n: {"F#3", 0.75, "an-"},
          n: {"A3", 0.75, "gels"},
          n: {"G3", 0.5, "cry,"}
        ],
        # 39  (cry,) "Ho-
        [n: {"G3", 1, "~cry,"}, rest: 1, n: {"G3", 2, "\"Ho-"}],
        # 40  ly." All cre-a-tion cries,
        [
          n: {"A3", 1, "ly.\""},
          rest: 0.5,
          n: {"A3", 0.25, "All"},
          n: {"B3", 0.25, "cre-"},
          n: {"A3", 0.75, "a-"},
          n: {"A3", 0.75, "tion"},
          n: {"F#3", 0.5, "cries,"}
        ],
        # 41  (cries,) "Ho-
        [n: {"F#3", 1, "~cries,"}, rest: 1, n: {"F#3", 2, "\"Ho-"}],
        # 42  ly." You are lift-ed high,
        [
          n: {"B2", 1, "ly.\""},
          rest: 0.5,
          n: {"B2", 0.25, "You"},
          n: {"B2", 0.25, "are"},
          n: {"B2", 0.75, "lift-"},
          n: {"B2", 0.75, "ed"},
          n: {"E3", 0.5, "high,"}
        ],
        # 43  (high,) ho-
        [n: {"E3", 1, "~high,"}, rest: 1, n: {"E3", 2, "ho-"}],
        # 44  ly! Ho-ly for-ev-
        [
          n: {"A3", 1, "ly!"},
          rest: 1,
          n: {"A3", 0.5, "Ho-"},
          n: {"A3", 0.5, "ly"},
          n: {"A3", 0.5, "for-"},
          n: {"D3", 0.5, "ev-"}
        ],
        # 45  (ev-) er!
        [n: {"D3", 0.5, "~ev-"}, n: {"D3", 3.5, "er!"}],
        # 46  Hear Your peo-ple sing,
        [
          rest: 1,
          rest: 0.5,
          n: {"A3", 0.25, "Hear"},
          n: {"B3", 0.25, "Your"},
          n: {"A3", 0.75, "peo-"},
          n: {"F#3", 0.75, "ple"},
          n: {"G3", 0.5, "sing,"}
        ],
        # 47  (sing,) "Ho-
        [n: {"G3", 1, "~sing,"}, rest: 1, n: {"G3", 2, "\"Ho-"}],
        # 48  ly" to the King of kings,
        [
          n: {"A3", 1, "ly\""},
          rest: 0.5,
          n: {"A3", 0.25, "to"},
          n: {"B3", 0.25, "the"},
          n: {"A3", 0.75, "King"},
          n: {"A3", 0.75, "of"},
          n: {"F#3", 0.5, "kings,"}
        ],
        # 49  (kings,) "Ho-
        [n: {"F#3", 1, "~kings,"}, rest: 1, n: {"F#3", 2, "\"Ho-"}],
        # 50  ly." You will al-ways be
        [
          n: {"B2", 1, "ly.\""},
          rest: 0.5,
          n: {"B2", 0.25, "You"},
          n: {"B2", 0.25, "will"},
          n: {"B2", 0.75, "al-"},
          n: {"B2", 0.75, "ways"},
          n: {"E3", 0.5, "be"}
        ],
        # 51  (be) ho-
        [n: {"E3", 1, "~be"}, rest: 1, n: {"E3", 2, "ho-"}],
        # 52  ly! Ho-ly for-ev-
        [
          n: {"A3", 1, "ly!"},
          rest: 1,
          n: {"A3", 0.5, "Ho-"},
          n: {"A3", 0.5, "ly"},
          n: {"A3", 0.5, "for-"},
          n: {"D3", 0.5, "ev-"}
        ],
        # 53  (~er!)
        [n: {"D3", 4, "~er!"}],
        # 54  (tenors only from here)
        [rest: 4],
        # 55  Your name is the highest (tenors only)
        [rest: 4],
        # 56
        [rest: 4],
        # 57
        [rest: 4],
        # 58
        [rest: 4],
        # 59
        [rest: 4],
        # 60
        [rest: 4],
        # 61
        [rest: 4],
        # 62  (all.) Your  -- "add BASSES" on the pickup
        [rest: 3.5, n: {"B3", 0.5, "Your"}],
        # 63  name is the high-est, Your
        [
          n: {"B3", 1, "name"},
          rest: 0.5,
          n: {"B3", 0.25, "is"},
          n: {"B3", 0.25, "the"},
          n: {"B3", 0.75, "high-"},
          n: {"A3", 0.25, "est,"},
          rest: 0.5,
          n: {"A3", 0.5, "Your"}
        ],
        # 64  name is the great-est. Your
        [
          n: {"A3", 1, "name"},
          rest: 0.5,
          n: {"A3", 0.25, "is"},
          n: {"A3", 0.25, "the"},
          n: {"A3", 0.75, "great-"},
          n: {"A3", 0.25, "est."},
          rest: 0.5,
          n: {"A3", 0.5, "Your"}
        ],
        # 65  name stands a-bove them
        [
          n: {"B3", 1, "name"},
          rest: 1,
          n: {"B3", 0.75, "stands"},
          n: {"A3", 0.25, "a-"},
          n: {"A3", 0.75, "bove"},
          n: {"G3", 0.25, "them"}
        ],
        # 66  all. All
        [n: {"G3", 2, "all."}, rest: 1.5, n: {"B3", 0.5, "All"}],
        # 67  thrones and do-min-ions, all
        [
          n: {"B3", 1, "thrones"},
          rest: 0.5,
          n: {"B3", 0.25, "and"},
          n: {"B3", 0.25, "do-"},
          n: {"B3", 0.75, "min-"},
          n: {"A3", 0.25, "ions,"},
          rest: 0.5,
          n: {"A3", 0.5, "all"}
        ],
        # 68  pow'rs and po-si-tions. Your
        [
          n: {"A3", 1, "pow'rs"},
          rest: 0.5,
          n: {"A3", 0.25, "and"},
          n: {"A3", 0.25, "po-"},
          n: {"A3", 0.75, "si-"},
          n: {"A3", 0.25, "tions."},
          rest: 0.5,
          n: {"A3", 0.5, "Your"}
        ],
        # 69  name stands a-bove them
        [
          n: {"B3", 1, "name"},
          rest: 1,
          n: {"B3", 0.75, "stands"},
          n: {"A3", 0.25, "a-"},
          n: {"A3", 0.75, "bove"},
          n: {"G3", 0.25, "them"}
        ],
        # 70  all. And the an-gels cry,
        [
          n: {"G3", 1, "all."},
          rest: 0.5,
          n: {"D3", 0.25, "And"},
          n: {"E3", 0.25, "the"},
          n: {"F#3", 0.75, "an-"},
          n: {"A3", 0.75, "gels"},
          n: {"G3", 0.5, "cry,"}
        ],
        # 71  (cry,) "Ho-
        # ? beat 3: shared stem G3/D4 then single B3, slurs above and below; read bass G3 -> B3
        [n: {"G3", 1, "~cry,"}, rest: 1, n: {"G3", 1, "\"Ho-"}, n: {"B3", 1, "~\"Ho-"}],
        # 72  ly." All cre-a-tion cries,
        [
          n: {"A3", 1, "ly.\""},
          rest: 0.5,
          n: {"A3", 0.25, "All"},
          n: {"B3", 0.25, "cre-"},
          n: {"A3", 0.75, "a-"},
          n: {"A3", 0.75, "tion"},
          n: {"F#3", 0.5, "cries,"}
        ],
        # 73  (cries,) "Ho-
        [n: {"F#3", 1, "~cries,"}, rest: 1, n: {"F#3", 2, "\"Ho-"}],
        # 74  ly." You are lift-ed high,
        [
          n: {"B2", 1, "ly.\""},
          rest: 0.5,
          n: {"B2", 0.25, "You"},
          n: {"B2", 0.25, "are"},
          n: {"B2", 0.75, "lift-"},
          n: {"B2", 0.75, "ed"},
          n: {"E3", 0.5, "high,"}
        ],
        # 75  ho-
        [n: {"E3", 1, "~high,"}, rest: 1, n: {"E3", 2, "ho-"}],
        # 76  ly! Ho-ly for-ev-
        [
          n: {"A3", 1, "ly!"},
          rest: 1,
          n: {"A3", 0.5, "Ho-"},
          n: {"A3", 0.5, "ly"},
          n: {"A3", 0.5, "for-"},
          n: {"D3", 0.5, "ev-"}
        ],
        # 77  er!
        [n: {"D3", 0.5, "~ev-"}, n: {"D3", 3.5, "er!"}],
        # 78  Hear Your peo-ple sing,
        [
          rest: 1.5,
          n: {"A3", 0.25, "Hear"},
          n: {"B3", 0.25, "Your"},
          n: {"A3", 0.75, "peo-"},
          n: {"F#3", 0.75, "ple"},
          n: {"G3", 0.5, "sing,"}
        ],
        # 79  "Ho-
        [n: {"G3", 1, "~sing,"}, rest: 1, n: {"G3", 1, "\"Ho-"}, n: {"B3", 1, "~Ho-"}],
        # 80  ly" to the King of kings,
        [
          n: {"A3", 1, "ly\""},
          rest: 0.5,
          n: {"A3", 0.25, "to"},
          n: {"B3", 0.25, "the"},
          n: {"A3", 0.75, "King"},
          n: {"A3", 0.75, "of"},
          n: {"F#3", 0.5, "kings,"}
        ],
        # 81  "Ho-
        [n: {"F#3", 1, "~kings,"}, rest: 1, n: {"F#3", 2, "\"Ho-"}],
        # 82  ly." You will al-ways be
        [
          n: {"B2", 1, "ly.\""},
          rest: 0.5,
          n: {"B2", 0.25, "You"},
          n: {"B2", 0.25, "will"},
          n: {"B2", 0.75, "al-"},
          n: {"B2", 0.75, "ways"},
          n: {"E3", 0.5, "be"}
        ],
        # 83  ho-
        [n: {"E3", 1, "~be"}, rest: 1, n: {"E3", 2, "ho-"}],
        # 84  ly! Ho-ly for-ev-
        [
          n: {"A3", 1, "ly!"},
          rest: 1,
          n: {"A3", 0.5, "Ho-"},
          n: {"A3", 0.5, "ly"},
          n: {"A3", 0.5, "for-"},
          n: {"D3", 0.5, "ev-"}
        ],
        # 85  er!
        [n: {"D3", 0.5, "~ev-"}, n: {"D3", 3.5, "er!"}],
        # 86  You will al-ways be,
        [
          rest: 1.5,
          n: {"D3", 0.25, "You"},
          n: {"D3", 0.25, "will"},
          n: {"D3", 0.75, "al-"},
          n: {"D3", 0.75, "ways"},
          n: {"E3", 0.5, "be,"}
        ],
        # 87  Ho-
        [n: {"E3", 1, "~be,"}, rest: 1, n: {"E3", 2, "Ho-"}],
        # 88  ly! Ho-ly for-ev-
        [
          n: {"A3", 1, "ly!"},
          rest: 1,
          n: {"E3", 0.5, "Ho-"},
          n: {"F#3", 0.5, "ly"},
          n: {"G3", 0.5, "for-"},
          n: {"G3", 0.5, "ev-"}
        ],
        # 89  er, and ev-
        [
          n: {"G3", 0.5, "~ev-"},
          n: {"F#3", 2.5, "er,"},
          n: {"E3", 0.5, "and"},
          n: {"E3", 0.5, "ev-"}
        ],
        # 90  er. (WOMEN: You will always be)
        [n: {"E3", 0.5, "~ev-"}, n: {"D3", 0.5, "er."}, rest: 3],
        # 91  (MEN) Ho-
        [rest: 2, n: {"G3", 1, "Ho-"}, n: {"F#3", 1, "~Ho-"}],
        # 92  ly!
        [n: {"E3", 2, "ly!"}, rest: 2],
        # 93  Ho-ly, Ho-
        [rest: 2, n: {"E3", 1, "Ho-"}, n: {"F#3", 0.5, "ly,"}, n: {"E3", 0.5, "Ho-"}],
        # 94  ly!
        [n: {"E3", 0.5, "~Ho-"}, n: {"D3", 1.5, "ly!"}, rest: 2],
        # 95  (ALL) Ho-
        [rest: 2, n: {"G3", 1, "Ho-"}, n: {"F#3", 1, "~Ho-"}],
        # 96  ly! Ho-ly for-ev-
        [
          n: {"E3", 1, "ly!"},
          rest: 1,
          n: {"C#3", 0.5, "Ho-"},
          n: {"D3", 0.5, "ly"},
          n: {"E3", 0.5, "for-"},
          n: {"E3", 0.5, "ev-"}
        ],
        # 97  er! (rit.)
        [n: {"E3", 0.5, "~ev-"}, n: {"D3", 3.5, "er!"}],
        # 98  (fermata rest, final bar)
        [rest: 4]
      ]
    )
  end
end
