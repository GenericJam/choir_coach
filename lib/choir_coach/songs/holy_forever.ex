defmodule ChoirCoach.Songs.HolyForever do
  @moduledoc """
  "Holy Forever (Christmas)" (Phil Wickham, Jason Ingram, Chris Tomlin, Chris Davenport, Jenn Johnson
  and Brian Johnson, arr. Russell Mauldin), bass part and melody, bars 1–98.

  Transcribed from the Drive score, bar by bar, and checked note by note
  against the Bass rehearsal track with the pitch detector: every note it
  hears off the written pitch was re-read at 400 dpi (most are the tenor,
  who shares the channel, or a scoop into the note).

  Timing is the Bass rehearsal track's, fitted with `scripts/align_track.exs`:
  bar 1 starts 750 ms in, ♩ = 72 steady, the rit. over bar 97 and the final
  fermata (a rest; its length is a choice) as `bar_ms`. Split and Demo offsets
  come from cross-correlating their accompaniment with the rehearsal track's.

  The melody is the tune wherever a voice sings it, in the women's register:
  the women's line, or the soprano where they divide, the men's echoes an
  octave up. Checked against the Soprano rehearsal track with the detector;
  the notes no recording confirms were re-read at 400 dpi and match the score
  (in some divided bars the recorded sopranos sing above the printed line).
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
          file: "holy_forever/split.mp3",
          bar1_ms: 816.0,
          voice: :right,
          label: "Split track"
        },
        demo: %{file: "holy_forever/demo.mp3", bar1_ms: 614.0, voice: :mixed, label: "Demo"}
      },
      part_tracks(part)
    )
  end

  defp part_tracks(:bass) do
    %{
      piano: %{file: "holy_forever/piano_bass.mp3", bar1_ms: 750.0, voice: :left, label: "Piano"},
      rehearsal: %{
        file: "holy_forever/bass.mp3",
        bar1_ms: 750.0,
        voice: :left,
        label: "Bass rehearsal"
      }
    }
  end

  defp part_tracks(:melody) do
    %{
      rehearsal: %{
        file: "holy_forever/soprano.mp3",
        bar1_ms: 750.0,
        voice: :left,
        label: "Soprano rehearsal"
      }
    }
  end

  # Every part shares the bar timeline (and so every track's offsets).
  defp timing do
    [
      title: "Holy Forever (Christmas)",
      key: 2,
      tempo_bpm: 72,
      beats_per_bar: 4,
      first_bar: 1,
      start_ms: 750.0,
      bar_ms: %{97 => 4_427.0, 98 => 6_000.0}
    ]
  end

  @spec bass() :: Song.t()
  def bass, do: Song.build(timing() ++ [part: :bass, clef: :bass, bars: bass_bars()])

  @spec melody() :: Song.t()
  def melody, do: Song.build(timing() ++ [part: :melody, clef: :treble, bars: melody_bars()])

  defp bass_bars do
    [
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
  end

  defp melody_bars do
    [
      # 1  (piano intro)
      [rest: 4],
      # 2  (piano)
      [rest: 4],
      # 3  (piano)
      [rest: 4],
      # 4  (piano)
      [rest: 4],
      # 5  solo (women opt. solo): Held with-in a man-ger, the
      [
        n: {"F#4", 0.5, "Held"},
        n: {"F#4", 0.25, "with-"},
        n: {"F#4", 0.25, "in"},
        n: {"F#4", 0.5, "~in"},
        n: {"E4", 0.25, "a"},
        n: {"E4", 0.25, "man-"},
        n: {"E4", 0.25, "~man-"},
        n: {"D4", 0.75, "ger,"},
        rest: 0.75,
        n: {"D4", 0.25, "the"}
      ],
      # 6  solo: Son of God ar-rived, the   ok: key D, B natural; recording ~semitone flat throughout
      [
        n: {"B4", 0.5, "Son"},
        n: {"B4", 0.25, "of"},
        n: {"B4", 0.25, "God"},
        n: {"B4", 0.5, "~God"},
        n: {"A4", 0.25, "ar-"},
        n: {"F#4", 0.25, "rived,"},
        n: {"F#4", 1, "~rived,"},
        rest: 0.75,
        n: {"D4", 0.25, "the"}
      ],
      # 7  solo: One who would be called Em-man-u-el
      [
        n: {"F#4", 0.5, "One"},
        n: {"F#4", 0.25, "who"},
        n: {"G4", 0.25, "would"},
        n: {"G4", 0.5, "~would"},
        n: {"F#4", 0.25, "be"},
        n: {"F#4", 0.25, "called"},
        n: {"F#4", 0.5, "~called"},
        n: {"E4", 0.25, "Em-"},
        n: {"E4", 0.25, "man-"},
        n: {"E4", 0.5, "~man-"},
        n: {"D4", 0.25, "u-"},
        n: {"D4", 0.25, "el."}
      ],
      # 8  solo: (el.) The
      [n: {"D4", 2, "~el."}, rest: 1, rest: 0.75, n: {"D4", 0.25, "The"}],
      # 9  solo: Prom-ise was de-liv-ered un-
      [
        n: {"F#4", 0.5, "Prom-"},
        n: {"F#4", 0.25, "ise"},
        n: {"F#4", 0.25, "was"},
        n: {"F#4", 0.5, "~was"},
        n: {"E4", 0.25, "de-"},
        n: {"E4", 0.25, "liv-"},
        n: {"E4", 0.25, "~liv-"},
        n: {"D4", 0.75, "ered"},
        rest: 0.75,
        n: {"D4", 0.25, "un-"}
      ],
      # 10  solo: to a vir-gin bride, the
      [
        n: {"B4", 0.5, "to"},
        n: {"B4", 0.25, "a"},
        n: {"B4", 0.25, "vir-"},
        n: {"B4", 0.25, "~vir-"},
        n: {"A4", 0.5, "gin"},
        n: {"F#4", 0.25, "bride,"},
        n: {"F#4", 1, "~bride,"},
        rest: 0.75,
        n: {"D4", 0.25, "the"}
      ],
      # 11  solo: One who would be called Em-man-u-el
      [
        n: {"F#4", 0.5, "One"},
        n: {"F#4", 0.25, "who"},
        n: {"G4", 0.25, "would"},
        n: {"G4", 0.5, "~would"},
        n: {"F#4", 0.25, "be"},
        n: {"F#4", 0.25, "called"},
        n: {"F#4", 0.5, "~called"},
        n: {"E4", 0.25, "Em-"},
        n: {"E4", 0.25, "man-"},
        n: {"E4", 0.5, "~man-"},
        n: {"D4", 0.25, "u-"},
        n: {"D4", 0.25, "el."}
      ],
      # 12  solo: (el.) / unison choir: Your
      [n: {"D4", 2, "~el."}, rest: 1, rest: 0.5, n: {"B3", 0.5, "Your"}],
      # 13  unison (women + tenors): name is the high-est, Your
      [
        n: {"B3", 1, "name"},
        rest: 0.5,
        n: {"B3", 0.25, "is"},
        n: {"B3", 0.25, "the"},
        n: {"B3", 0.75, "high-"},
        n: {"A3", 0.25, "est,"},
        rest: 0.5,
        n: {"C#4", 0.5, "Your"}
      ],
      # 14  unison: name is the great-est. Your
      [
        n: {"C#4", 1, "name"},
        rest: 0.5,
        n: {"C#4", 0.25, "is"},
        n: {"C#4", 0.25, "the"},
        n: {"C#4", 0.75, "great-"},
        n: {"B3", 0.25, "est."},
        rest: 0.5,
        n: {"D4", 0.5, "Your"}
      ],
      # 15  unison: name stands a-bove them
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"B3", 0.25, "them"}
      ],
      # 16  unison: all. All
      [n: {"B3", 2, "all."}, rest: 1, rest: 0.5, n: {"B3", 0.5, "All"}],
      # 17  unison: thrones and do-min-ions, all
      [
        n: {"B3", 1, "thrones"},
        rest: 0.5,
        n: {"B3", 0.25, "and"},
        n: {"B3", 0.25, "do-"},
        n: {"B3", 0.75, "min-"},
        n: {"A3", 0.25, "ions,"},
        rest: 0.5,
        n: {"C#4", 0.5, "all"}
      ],
      # 18  unison: pow'rs and po-si-tions. Your
      [
        n: {"C#4", 1, "pow'rs"},
        rest: 0.5,
        n: {"C#4", 0.25, "and"},
        n: {"C#4", 0.25, "po-"},
        n: {"C#4", 0.75, "si-"},
        n: {"B3", 0.25, "tions."},
        rest: 0.5,
        n: {"D4", 0.5, "Your"}
      ],
      # 19  unison: name stands a-bove them
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"D4", 0.25, "them"}
      ],
      # 20  unison/sop: all. And the an-gels cry,
      [
        n: {"D4", 1, "all."},
        rest: 0.5,
        n: {"D4", 0.25, "And"},
        n: {"E4", 0.25, "the"},
        n: {"F#4", 0.75, "an-"},
        n: {"D4", 0.25, "gels"},
        n: {"D4", 0.5, "~gels"},
        n: {"D4", 0.5, "cry,"}
      ],
      # 21  sop: (cry,) Ho-   ok: top of divisi B4/G4 then G4/E4 at 400dpi
      [n: {"D4", 1, "~cry,"}, rest: 1, n: {"B4", 1, "Ho-"}, n: {"G4", 1, "~Ho-"}],
      # 22  sop: ly. All cre-a-tion cries,   ? 16ths read E4 F#4 (top of small divisi); ok: rest per
      #   score at 400dpi, recording heard in other octaves
      [
        n: {"E4", 1, "ly."},
        rest: 0.5,
        n: {"E4", 0.25, "All"},
        n: {"F#4", 0.25, "cre-"},
        n: {"A4", 0.75, "a-"},
        n: {"E4", 0.25, "tion"},
        n: {"E4", 0.5, "~tion"},
        n: {"D4", 0.5, "cries,"}
      ],
      # 23  sop: (cries,) Ho-   ok: top of divisi A4 then E4/C#4
      [n: {"D4", 1, "~cries,"}, rest: 1, n: {"A4", 1, "Ho-"}, n: {"E4", 1, "~Ho-"}],
      # 24  sop: ly. You are lift-ed high,   ok: top of divisi rechecked at 400dpi
      [
        n: {"F#4", 1, "ly."},
        rest: 0.5,
        n: {"G4", 0.25, "You"},
        n: {"G4", 0.25, "are"},
        n: {"A4", 0.75, "lift-"},
        n: {"F#4", 0.25, "ed"},
        n: {"F#4", 0.5, "~ed"},
        n: {"B4", 0.5, "high,"}
      ],
      # 25  sop: (high,) ho-   ok: B4 half with alto G4-F#4
      [n: {"B4", 1, "~high,"}, rest: 1, n: {"B4", 2, "ho-"}],
      # 26  sop: ly! Ho-ly for-ev-   ok: top of divisi A4 G4 A4 B4 B4 at 400dpi
      [
        n: {"A4", 1, "ly!"},
        rest: 1,
        n: {"G4", 0.5, "Ho-"},
        n: {"A4", 0.5, "ly"},
        n: {"B4", 0.5, "for-"},
        n: {"B4", 0.5, "ev-"}
      ],
      # 27  sop: (ev-) er!   ok: top B4/G4 then A4/F#4
      [n: {"B4", 0.5, "~ev-"}, n: {"A4", 3.5, "er!"}],
      # 28  unison: In the
      [rest: 3.5, n: {"D4", 0.25, "In"}, n: {"E4", 0.25, "the"}],
      # 29  unison: hum-ble town of Da-vid, a   ok: same as bar 5; recording flat
      [
        n: {"F#4", 0.5, "hum-"},
        n: {"F#4", 0.25, "ble"},
        n: {"F#4", 0.25, "town"},
        n: {"F#4", 0.5, "~town"},
        n: {"E4", 0.25, "of"},
        n: {"E4", 0.25, "Da-"},
        n: {"E4", 0.25, "~Da-"},
        n: {"D4", 0.75, "vid,"},
        rest: 0.75,
        n: {"D4", 0.25, "a"}
      ],
      # 30  unison: Sav-ior born to-day, the
      [
        n: {"B4", 0.5, "Sav-"},
        n: {"B4", 0.25, "ior"},
        n: {"B4", 0.25, "born"},
        n: {"B4", 0.5, "~born"},
        n: {"A4", 0.25, "to-"},
        n: {"F#4", 0.25, "day,"},
        n: {"F#4", 1, "~day,"},
        rest: 0.75,
        n: {"D4", 0.25, "the"}
      ],
      # 31  unison (women): One who would be called Em-man-u-el   ok: top treble line confirmed at 400
      #   dpi; recordings heard low voices
      [
        n: {"F#4", 0.5, "One"},
        n: {"F#4", 0.25, "who"},
        n: {"G4", 0.25, "would"},
        n: {"G4", 0.5, "~would"},
        n: {"F#4", 0.25, "be"},
        n: {"F#4", 0.25, "called"},
        n: {"F#4", 0.5, "~called"},
        n: {"E4", 0.25, "Em-"},
        n: {"E4", 0.25, "man-"},
        n: {"E4", 0.5, "~man-"},
        n: {"D4", 0.25, "u-"},
        n: {"D4", 0.25, "el"}
      ],
      # 32  unison: (el) Be-   ok: top treble line confirmed at 400 dpi; recordings heard low voices
      [n: {"D4", 2, "~el"}, rest: 1.75, n: {"D4", 0.25, "Be-"}],
      # 33  unison: hold the host of heav-en with
      [
        n: {"F#4", 0.5, "hold"},
        n: {"F#4", 0.25, "the"},
        n: {"F#4", 0.25, "host"},
        n: {"F#4", 0.5, "~host"},
        n: {"E4", 0.25, "of"},
        n: {"E4", 0.25, "heav-"},
        n: {"E4", 0.25, "~heav-"},
        n: {"D4", 0.75, "en"},
        rest: 0.75,
        n: {"D4", 0.25, "with"}
      ],
      # 34  unison: ho-ly roar pro-claim the
      [
        n: {"B4", 0.5, "ho-"},
        n: {"B4", 0.25, "ly"},
        n: {"B4", 0.25, "roar"},
        n: {"B4", 0.5, "~roar"},
        n: {"A4", 0.25, "pro-"},
        n: {"F#4", 0.25, "claim"},
        n: {"F#4", 1, "~claim"},
        rest: 0.75,
        n: {"D4", 0.25, "the"}
      ],
      # 35  unison: One who would be called Em-man-u-el   ok: top treble line confirmed at 400 dpi;
      #   recordings heard low voices
      [
        n: {"F#4", 0.5, "One"},
        n: {"F#4", 0.25, "who"},
        n: {"G4", 0.25, "would"},
        n: {"G4", 0.5, "~would"},
        n: {"F#4", 0.25, "be"},
        n: {"F#4", 0.25, "called"},
        n: {"F#4", 0.5, "~called"},
        n: {"E4", 0.25, "Em-"},
        n: {"E4", 0.25, "man-"},
        n: {"E4", 0.5, "~man-"},
        n: {"D4", 0.25, "u-"},
        n: {"D4", 0.25, "el"}
      ],
      # 36  unison: (el) The Mes-
      [n: {"D4", 2, "~el"}, rest: 1.5, n: {"D4", 0.25, "The"}, n: {"D4", 0.25, "Mes-"}],
      # 37  sop (marked mel.): si-ah, our God, is with us now
      [
        n: {"F#4", 0.75, "si-"},
        n: {"F#4", 0.25, "ah"},
        n: {"F#4", 0.5, "~ah"},
        rest: 0.25,
        n: {"F#4", 0.25, "our"},
        n: {"B4", 0.75, "God"},
        n: {"A4", 0.25, "is"},
        n: {"A4", 0.25, "with"},
        n: {"G4", 0.5, "us"},
        n: {"G4", 0.25, "now"}
      ],
      # 38  sop: (now) And the an-gels cry
      [
        n: {"G4", 1, "~now"},
        rest: 0.5,
        n: {"D4", 0.25, "And"},
        n: {"E4", 0.25, "the"},
        n: {"F#4", 0.75, "an-"},
        n: {"D4", 0.25, "gels"},
        n: {"D4", 0.5, "~gels"},
        n: {"B3", 0.5, "cry"}
      ],
      # 39  sop: (cry) Ho-   ok: top treble line confirmed at 400 dpi; recordings heard low voices
      [n: {"B3", 1, "~cry"}, rest: 1, n: {"B4", 1, "Ho-"}, n: {"F#4", 1, "~Ho-"}],
      # 40  sop: ly. All cre-a-tion cries   ok: top treble line confirmed at 400 dpi; recordings heard
      #   low voices
      [
        n: {"E4", 1, "ly"},
        rest: 0.5,
        n: {"E4", 0.25, "All"},
        n: {"F#4", 0.25, "cre-"},
        n: {"A4", 0.75, "a-"},
        n: {"E4", 0.25, "tion"},
        n: {"E4", 0.5, "~tion"},
        n: {"D4", 0.5, "cries"}
      ],
      # 41  sop: (cries) Ho-   ok: top treble line confirmed at 400 dpi; recordings heard low voices
      [n: {"D4", 1, "~cries"}, rest: 1, n: {"A4", 1, "Ho-"}, n: {"E4", 1, "~Ho-"}],
      # 42  sop: ly. You are lift-ed high   ok: top treble line confirmed at 400 dpi; recordings heard
      #   low voices
      [
        n: {"F#4", 1, "ly"},
        rest: 0.5,
        n: {"F#4", 0.25, "You"},
        n: {"G4", 0.25, "are"},
        n: {"A4", 0.75, "lift-"},
        n: {"F#4", 0.25, "ed"},
        n: {"F#4", 0.5, "~ed"},
        n: {"B4", 0.5, "high"}
      ],
      # 43  sop: (high) ho-
      [n: {"B4", 1, "~high"}, rest: 1, n: {"B4", 2, "ho-"}],
      # 44  sop: ly! Ho-ly for-ev-   ok: top treble line confirmed at 400 dpi; recordings heard low voices
      [
        n: {"A4", 1, "ly"},
        rest: 1,
        n: {"G4", 0.5, "Ho-"},
        n: {"A4", 0.5, "ly"},
        n: {"B4", 0.5, "for-"},
        n: {"B4", 0.5, "ev-"}
      ],
      # 45  sop: (ev)-er   ok: top treble line confirmed at 400 dpi; recordings heard low voices
      [n: {"B4", 0.5, "~ev-"}, n: {"A4", 0.5, "er"}, n: {"A4", 3, "~er"}],
      # 46  sop: Hear Your peo-ple sing   ? "ple" G4 and "sing" E4 read from chord height (pattern
      #   differs from bar 42)   ok: top treble line confirmed at 400 dpi; recordings heard low voices
      [
        rest: 1.5,
        n: {"F#4", 0.25, "Hear"},
        n: {"G4", 0.25, "Your"},
        n: {"A4", 0.75, "peo-"},
        n: {"G4", 0.25, "ple"},
        n: {"G4", 0.5, "~ple"},
        n: {"E4", 0.5, "sing"}
      ],
      # 47  sop: (sing) Ho-   ok: top treble line confirmed at 400 dpi; recordings heard low voices
      [n: {"E4", 1, "~sing"}, rest: 1, n: {"B4", 1, "Ho-"}, n: {"F#4", 1, "~Ho-"}],
      # 48  sop: ly to the King of kings   ok: top treble line confirmed at 400 dpi; recordings heard low
      #   voices
      [
        n: {"E4", 1, "ly"},
        rest: 0.5,
        n: {"E4", 0.25, "to"},
        n: {"F#4", 0.25, "the"},
        n: {"A4", 0.75, "King"},
        n: {"E4", 0.25, "of"},
        n: {"E4", 0.5, "~of"},
        n: {"D4", 0.5, "kings"}
      ],
      # 49  sop: (kings) Ho-   ok: top treble line confirmed at 400 dpi; recordings heard low voices
      [n: {"D4", 1, "~kings"}, rest: 1, n: {"A4", 1, "Ho-"}, n: {"E4", 1, "~Ho-"}],
      # 50  sop: ly. You will al-ways be   ok: top treble line confirmed at 400 dpi; recordings heard low
      #   voices
      [
        n: {"F#4", 1, "ly"},
        rest: 0.5,
        n: {"F#4", 0.25, "You"},
        n: {"G4", 0.25, "will"},
        n: {"A4", 0.75, "al-"},
        n: {"F#4", 0.25, "ways"},
        n: {"F#4", 0.5, "~ways"},
        n: {"B4", 0.5, "be"}
      ],
      # 51  sop: (be) ho-   ok: top treble line confirmed at 400 dpi; recordings heard low voices
      [n: {"B4", 1, "~be"}, rest: 1, n: {"B4", 2, "ho-"}],
      # 52  sop: ly! Ho-ly for-ev-   ok: top treble line confirmed at 400 dpi; recordings heard low voices
      [
        n: {"A4", 1, "ly"},
        rest: 1,
        n: {"G4", 0.5, "Ho-"},
        n: {"A4", 0.5, "ly"},
        n: {"B4", 0.5, "for-"},
        n: {"B4", 0.5, "ev-"}
      ],
      # 53  sop: (ev-)er!  ok: score shows B4->A4 (sop over G4/F#4)
      [n: {"B4", 0.5, "~er!"}, n: {"A4", 0.5, "~er!"}, n: {"A4", 3, "~er!"}],
      # 54  unison (women + tenors): Your
      [rest: 3.5, n: {"B3", 0.5, "Your"}],
      # 55  unison (women + tenors): name is the high-est, Your
      [
        n: {"B3", 1, "name"},
        rest: 0.5,
        n: {"B3", 0.25, "is"},
        n: {"B3", 0.25, "the"},
        n: {"B3", 0.75, "high-"},
        n: {"A3", 0.25, "est,"},
        rest: 0.5,
        n: {"C#4", 0.5, "Your"}
      ],
      # 56  unison: name is the great-est. Your
      [
        n: {"C#4", 1, "name"},
        rest: 0.5,
        n: {"C#4", 0.25, "is"},
        n: {"C#4", 0.25, "the"},
        n: {"C#4", 0.75, "great-"},
        n: {"B3", 0.25, "est."},
        rest: 0.5,
        n: {"D4", 0.5, "Your"}
      ],
      # 57  unison: name stands a-bove them
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"B3", 0.25, "them"}
      ],
      # 58  unison: all. All  (pickup: alto B3 = tenors; sop D4 above)
      [n: {"B3", 2, "all."}, rest: 1.5, n: {"B3", 0.5, "All"}],
      # 59  alto = tenors (tune): thrones and do-min-ions, all  ? sop harmonizes a 3rd above; tune kept
      #   in alto/tenor line
      [
        n: {"B3", 1, "thrones"},
        rest: 0.5,
        n: {"B3", 0.25, "and"},
        n: {"B3", 0.25, "do-"},
        n: {"B3", 0.75, "min-"},
        n: {"A3", 0.25, "ions,"},
        rest: 0.5,
        n: {"C#4", 0.5, "all"}
      ],
      # 60  alto = tenors: pow'rs and po-si-tions. Your
      [
        n: {"C#4", 1, "pow'rs"},
        rest: 0.5,
        n: {"C#4", 0.25, "and"},
        n: {"C#4", 0.25, "po-"},
        n: {"C#4", 0.75, "si-"},
        n: {"B3", 0.25, "tions."},
        rest: 0.5,
        n: {"D4", 0.5, "Your"}
      ],
      # 61  alto = tenors: name stands a-bove them
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"B3", 0.25, "them"}
      ],
      # 62  tenors (tune, women harmonize above): all. Your
      [n: {"B3", 2, "all."}, rest: 1.5, n: {"B3", 0.5, "Your"}],
      # 63  sop (tune in parallel above tenors; recordings follow sop): name is the high-est, Your
      [
        n: {"G4", 1, "name"},
        rest: 0.5,
        n: {"G4", 0.25, "is"},
        n: {"G4", 0.25, "the"},
        n: {"G4", 0.75, "high-"},
        n: {"F#4", 0.25, "est,"},
        rest: 0.5,
        n: {"A4", 0.5, "Your"}
      ],
      # 64  sop: name is the great-est. Your
      [
        n: {"A4", 1, "name"},
        rest: 0.5,
        n: {"A4", 0.25, "is"},
        n: {"A4", 0.25, "the"},
        n: {"A4", 0.75, "great-"},
        n: {"F#4", 0.25, "est."},
        rest: 0.5,
        n: {"B4", 0.5, "Your"}
      ],
      # 65  sop: name stands a-bove them
      [
        n: {"B4", 1, "name"},
        rest: 1,
        n: {"B4", 0.75, "stands"},
        n: {"A4", 0.25, "a-"},
        n: {"A4", 0.75, "bove"},
        n: {"G4", 0.25, "them"}
      ],
      # 66  sop: all. All
      [n: {"G4", 2, "all."}, rest: 1.5, n: {"G4", 0.5, "All"}],
      # 67  sop: thrones and do-min-ions, all
      [
        n: {"G4", 1, "thrones"},
        rest: 0.5,
        n: {"G4", 0.25, "and"},
        n: {"G4", 0.25, "do-"},
        n: {"G4", 0.75, "min-"},
        n: {"F#4", 0.25, "ions,"},
        rest: 0.5,
        n: {"A4", 0.5, "all"}
      ],
      # 68  sop: pow'rs and po-si-tions. Your
      [
        n: {"A4", 1, "pow'rs"},
        rest: 0.5,
        n: {"A4", 0.25, "and"},
        n: {"A4", 0.25, "po-"},
        n: {"A4", 0.75, "si-"},
        n: {"F#4", 0.25, "tions."},
        rest: 0.5,
        n: {"B4", 0.5, "Your"}
      ],
      # 69  sop: name stands a-bove them
      [
        n: {"B4", 1, "name"},
        rest: 1,
        n: {"B4", 0.75, "stands"},
        n: {"A4", 0.25, "a-"},
        n: {"A4", 0.75, "bove"},
        n: {"G4", 0.25, "them"}
      ],
      # 70  sop: all. And the an-gels cry,
      [
        n: {"G4", 1, "all."},
        rest: 0.5,
        n: {"D4", 0.25, "And"},
        n: {"E4", 0.25, "the"},
        n: {"F#4", 0.75, "an-"},
        n: {"A4", 0.25, "gels"},
        n: {"A4", 0.5, "~gels"},
        n: {"B4", 0.5, "cry,"}
      ],
      # 71  sop: (cry,) then lower women line marked "mel.": Ho-  ? followed the "mel." marking (lower
      #   line) rather than the top
      [n: {"B4", 1, "~cry,"}, rest: 1, n: {"F#4", 1, "Ho-"}, n: {"D4", 1, "~Ho-"}],
      # 72  sop (top line; recordings follow it, not the lower "mel." line): ly. All cre-a-tion cries,
      [
        n: {"E4", 1, "ly."},
        rest: 0.5,
        n: {"E4", 0.25, "All"},
        n: {"F#4", 0.25, "cre-"},
        n: {"A4", 0.75, "a-"},
        n: {"E4", 0.25, "tion"},
        n: {"E4", 0.5, "~tion"},
        n: {"D4", 0.5, "cries,"}
      ],
      # 73  sop: (cries,) Ho-
      [n: {"D4", 1, "~cries,"}, rest: 1, n: {"A4", 1, "Ho-"}, n: {"E4", 1, "~Ho-"}],
      # 74  sop: ly. You are lift-ed high,
      [
        n: {"F#4", 1, "ly.\""},
        rest: 0.5,
        n: {"F#4", 0.25, "You"},
        n: {"G4", 0.25, "are"},
        n: {"A4", 0.75, "lift-"},
        n: {"F#4", 0.25, "ed"},
        n: {"F#4", 0.5, "~ed"},
        n: {"B4", 0.5, "high,"}
      ],
      # 75  sop: (high) ho-
      [n: {"B4", 1, "~high,"}, rest: 1, n: {"B4", 2, "ho-"}],
      # 76  sop: ly! Ho-ly for-ev-   ok: re-read at 400dpi, sop top note G-A-B-B as written
      [
        n: {"A4", 1, "ly!"},
        rest: 1,
        n: {"G4", 0.5, "Ho-"},
        n: {"A4", 0.5, "ly"},
        n: {"B4", 0.5, "for-"},
        n: {"B4", 0.5, "ev-"}
      ],
      # 77  sop: er!   ok: score shows B4 to A4 on top
      [n: {"B4", 0.5, "~ev-"}, n: {"A4", 3.5, "er!"}],
      # 78  sop: Hear Your peo-ple sing,
      [
        rest: 1.5,
        n: {"F#4", 0.25, "Hear"},
        n: {"G4", 0.25, "Your"},
        n: {"A4", 0.75, "peo-"},
        n: {"F#4", 0.25, "ple"},
        n: {"F#4", 0.5, "~ple"},
        n: {"D4", 0.5, "sing,"}
      ],
      # 79  sop: (sing) Ho-   ok: score shows B4 slurred to F#4 on top
      [n: {"D4", 1, "~sing,"}, rest: 1, n: {"B4", 1, "\"Ho-"}, n: {"F#4", 1, "~Ho-"}],
      # 80  sop: ly to the King of kings,   ok: score shows E4 top on beat 1
      [
        n: {"E4", 1, "ly\""},
        rest: 0.5,
        n: {"E4", 0.25, "to"},
        n: {"F#4", 0.25, "the"},
        n: {"A4", 0.75, "King"},
        n: {"E4", 0.25, "of"},
        n: {"E4", 0.5, "~of"},
        n: {"D4", 0.5, "kings,"}
      ],
      # 81  sop: (kings) Ho-
      [n: {"D4", 1, "~kings,"}, rest: 1, n: {"A4", 1, "\"Ho-"}, n: {"E4", 1, "~Ho-"}],
      # 82  sop: ly. You will al-ways be
      [
        n: {"F#4", 1, "ly.\""},
        rest: 0.5,
        n: {"F#4", 0.25, "You"},
        n: {"G4", 0.25, "will"},
        n: {"A4", 0.75, "al-"},
        n: {"F#4", 0.25, "ways"},
        n: {"F#4", 0.5, "~ways"},
        n: {"B4", 0.5, "be"}
      ],
      # 83  sop: (be) ho-
      [n: {"B4", 1, "~be"}, rest: 1, n: {"B4", 2, "ho-"}],
      # 84  sop: ly! Ho-ly for-ev-   ok: same notes as bar 76, re-read
      [
        n: {"A4", 1, "ly!"},
        rest: 1,
        n: {"G4", 0.5, "Ho-"},
        n: {"A4", 0.5, "ly"},
        n: {"B4", 0.5, "for-"},
        n: {"B4", 0.5, "ev-"}
      ],
      # 85  sop: er!   ok: same as bar 77, re-read
      [n: {"B4", 0.5, "~ev-"}, n: {"A4", 3.5, "er!"}],
      # 86  sop: You will al-ways be,   ok: same figure as bars 74/82, re-read
      [
        rest: 1.5,
        n: {"F#4", 0.25, "You"},
        n: {"G4", 0.25, "will"},
        n: {"A4", 0.75, "al-"},
        n: {"F#4", 0.25, "ways"},
        n: {"F#4", 0.5, "~ways"},
        n: {"B4", 0.5, "be,"}
      ],
      # 87  sop: (be) Ho-
      [n: {"B4", 1, "~be,"}, rest: 1, n: {"B4", 2, "Ho-"}],
      # 88  unison: ly! Ho-ly for-ev-
      [
        n: {"A4", 1, "ly!"},
        rest: 1,
        n: {"E4", 0.5, "Ho-"},
        n: {"F#4", 0.5, "ly"},
        n: {"G4", 0.5, "for-"},
        n: {"G4", 0.5, "ev-"}
      ],
      # 89  unison: er, and ev-
      [
        n: {"G4", 0.5, "~ev-"},
        n: {"F#4", 2.5, "er,"},
        n: {"E4", 0.5, "and"},
        n: {"E4", 0.5, "ev-"}
      ],
      # 90  unison, then women: er. You will al-ways be,
      [
        n: {"E4", 0.5, "~ev-"},
        n: {"D4", 0.5, "er."},
        rest: 0.5,
        n: {"D4", 0.25, "You"},
        n: {"E4", 0.25, "will"},
        n: {"F#4", 0.75, "al-"},
        n: {"D4", 0.25, "ways"},
        n: {"D4", 0.5, "~ways"},
        n: {"G4", 0.5, "be,"}
      ],
      # 91  women (be), then men (8va) echo: Ho-
      [n: {"G4", 2, "~be,"}, n: {"G4", 1, "Ho-"}, n: {"F#4", 1, "~Ho-"}],
      # 92  men (8va): ly!, then women: You will al-ways be,   ? men's half note cut to 1.5 where women
      #   enter; ok: women's F#4 confirmed at 400dpi (tied into F#4 of bar 93)
      [
        n: {"E4", 1.5, "ly!"},
        n: {"C#4", 0.25, "You"},
        n: {"D4", 0.25, "will"},
        n: {"E4", 0.75, "al-"},
        n: {"F#4", 0.25, "ways"},
        n: {"F#4", 0.5, "~ways"},
        n: {"F#4", 0.5, "be,"}
      ],
      # 93  women (be), then men (8va) echo: Ho-ly, Ho-
      [n: {"F#4", 2, "~be,"}, n: {"E4", 1, "Ho-"}, n: {"F#4", 0.5, "ly,"}, n: {"E4", 0.5, "Ho-"}],
      # 94  men (8va): ly!, then women: You will al-ways be,   ? men's "ly" cut to 1 where women enter
      [
        n: {"E4", 0.5, "~Ho-"},
        n: {"D4", 1, "ly!"},
        n: {"D4", 0.25, "You"},
        n: {"E4", 0.25, "will"},
        n: {"F#4", 0.75, "al-"},
        n: {"D4", 0.25, "ways"},
        n: {"D4", 0.5, "~ways"},
        n: {"G4", 0.5, "be,"}
      ],
      # 95  women (be), then unison (all): Ho-
      [n: {"G4", 1, "~be,"}, rest: 1, n: {"G4", 1, "Ho-"}, n: {"F#4", 1, "~Ho-"}],
      # 96  unison: ly! Ho-ly for-ev-
      [
        n: {"E4", 1, "ly!"},
        rest: 1,
        n: {"C#4", 0.5, "Ho-"},
        n: {"D4", 0.5, "ly"},
        n: {"E4", 0.5, "for-"},
        n: {"E4", 0.5, "ev-"}
      ],
      # 97  unison: er! (rit.)
      [n: {"E4", 0.5, "~ev-"}, n: {"D4", 3.5, "er!"}],
      # 98  (fermata rest, final bar)
      [rest: 4]
    ]
  end
end
