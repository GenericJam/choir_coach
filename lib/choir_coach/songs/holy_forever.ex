defmodule ChoirCoach.Songs.HolyForever do
  @moduledoc """
  "Holy Forever (Christmas)" (Phil Wickham, Jason Ingram, Chris Tomlin, Chris Davenport, Jenn Johnson
  and Brian Johnson, arr. Russell Mauldin), bass part, melody, and the soprano,
  alto and tenor parts, bars 1–98.

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

  Soprano and alto are the upper and lower notes of the treble staff (both
  sing the women's unison and the solo), the tenor the upper notes of the bass
  staff (the tenors' unison with the women, the men's unison with the bass).
  Each was checked against its own rehearsal track with the detector; the
  notes heard off the written pitch were re-read at 400 dpi: most are the
  other voices on the channel (the men's notes under the women's divisi, the
  sopranos over the altos), or the recording singing flat. The tenors' "ho-"
  (bars 25, 43, …) and bar 86 were misreads, fixed; the notes left unconfirmed
  are marked `?` on their bar.
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

  # Soprano, alto and tenor: the part's rehearsal track, and its piano
  # rendering (`scripts/render_piano.exs`), on the bass track's timeline.
  defp part_tracks(part) when part in [:soprano, :alto, :tenor] do
    name = part |> Atom.to_string() |> String.capitalize()

    %{
      piano: %{
        file: "holy_forever/piano_#{part}.mp3",
        bar1_ms: 750.0,
        voice: :left,
        label: "Piano"
      },
      rehearsal: %{
        file: "holy_forever/#{part}.mp3",
        bar1_ms: 750.0,
        voice: :left,
        label: "#{name} rehearsal"
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

  @spec soprano() :: Song.t()
  def soprano, do: Song.build(timing() ++ [part: :soprano, clef: :treble, bars: soprano_bars()])

  @spec alto() :: Song.t()
  def alto, do: Song.build(timing() ++ [part: :alto, clef: :treble, bars: alto_bars()])

  @spec tenor() :: Song.t()
  def tenor, do: Song.build(timing() ++ [part: :tenor, clef: :bass, bars: tenor_bars()])

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

  defp soprano_bars do
    [
      # 1  (rest)
      [rest: 4],
      # 2  (rest)
      [rest: 4],
      # 3  (rest)
      [rest: 4],
      # 4  (rest)
      [rest: 4],
      # 5  Held with-in a man-ger, the  (F#4 F#4 F#4 F#4 E4 E4 E4 D4 D4)  solo (women opt.
      #   solo); ok: recording sings flat here
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
      # 6  Son of God ar-rived, the  (B4 B4 B4 B4 A4 F#4 F#4 D4)  solo; ok: recording sings
      #   flat here
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
      # 7  One who would be called Em-man-u-el.  (F#4 F#4 G4 G4 F#4 F#4 F#4 E4 E4 E4 D4 D4)
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
      # 8  The  (D4 D4)
      [n: {"D4", 2, "~el."}, rest: 1, rest: 0.75, n: {"D4", 0.25, "The"}],
      # 9  Prom-ise was de-liv-ered un-  (F#4 F#4 F#4 F#4 E4 E4 E4 D4 D4)  solo; ok: recording
      #   sings flat here
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
      # 10  to a vir-gin bride, the  (B4 B4 B4 B4 A4 F#4 F#4 D4)  solo; ok: recording sings
      #   flat here
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
      # 11  One who would be called Em-man-u-el.  (F#4 F#4 G4 G4 F#4 F#4 F#4 E4 E4 E4 D4 D4)
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
      # 12  Your  (D4 B3)
      [n: {"D4", 2, "~el."}, rest: 1, rest: 0.5, n: {"B3", 0.5, "Your"}],
      # 13  name is the high-est, Your  (B3 B3 B3 B3 A3 C#4)  women unison (tenors double)
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
      # 14  name is the great-est. Your  (C#4 C#4 C#4 C#4 B3 D4)  ok: recording sings flat
      #   here
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
      # 15  name stands a-bove them  (D4 D4 C#4 C#4 B3)
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"B3", 0.25, "them"}
      ],
      # 16  all. All  (B3 B3)
      [n: {"B3", 2, "all."}, rest: 1, rest: 0.5, n: {"B3", 0.5, "All"}],
      # 17  thrones and do-min-ions, all  (B3 B3 B3 B3 A3 C#4)
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
      # 18  pow'rs and po-si-tions. Your  (C#4 C#4 C#4 C#4 B3 D4)
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
      # 19  name stands a-bove them  (D4 D4 C#4 C#4 D4)
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"D4", 0.25, "them"}
      ],
      # 20  all. And the an-gels cry,  (D4 D4 E4 F#4 D4 D4 D4)  unison, cry top of divisi
      #   D4/B3
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
      # 21  Ho-  (D4 B4 F#4)  top of divisi B4/F#4 then F#4/D4 (400 dpi; F#4, not G4); ok:
      #   off-pitch readings are the men (tenor/bass) on the channel
      [n: {"D4", 1, "~cry,"}, rest: 1, n: {"B4", 1, "Ho-"}, n: {"F#4", 1, "~Ho-"}],
      # 22  ly. All cre-a-tion cries,  (E4 E4 F#4 A4 E4 E4 D4)  top of divisi; ok: off-pitch
      #   readings are the men (tenor/bass) on the channel; ? ly. heard F#4 (37% on), score
      #   E4/C#4 at 400 dpi
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
      # 23  Ho-  (D4 A4 E4)  top of divisi; ok: off-pitch readings are the men (tenor/bass) on
      #   the channel
      [n: {"D4", 1, "~cries,"}, rest: 1, n: {"A4", 1, "Ho-"}, n: {"E4", 1, "~Ho-"}],
      # 24  ly. You are lift-ed high,  (F#4 F#4 G4 A4 F#4 F#4 B4)  top of divisi; You F#4/D4
      #   as bar 42 (400 dpi); ok: off-pitch readings are the men (tenor/bass) on the channel
      [
        n: {"F#4", 1, "ly."},
        rest: 0.5,
        n: {"F#4", 0.25, "You"},
        n: {"G4", 0.25, "are"},
        n: {"A4", 0.75, "lift-"},
        n: {"F#4", 0.25, "ed"},
        n: {"F#4", 0.5, "~ed"},
        n: {"B4", 0.5, "high,"}
      ],
      # 25  ho-  (B4 B4)  B4 half over alto G4-F#4
      [n: {"B4", 1, "~high,"}, rest: 1, n: {"B4", 2, "ho-"}],
      # 26  ly! Ho-ly for-ev-  (A4 G4 A4 B4 B4)  top of divisi; ok: off-pitch readings are the
      #   men (tenor/bass) on the channel
      [
        n: {"A4", 1, "ly!"},
        rest: 1,
        n: {"G4", 0.5, "Ho-"},
        n: {"A4", 0.5, "ly"},
        n: {"B4", 0.5, "for-"},
        n: {"B4", 0.5, "ev-"}
      ],
      # 27  er!  (B4 A4)  top B4/G4 then A4/F#4; ok: off-pitch readings are the men
      #   (tenor/bass) on the channel
      [n: {"B4", 0.5, "~ev-"}, n: {"A4", 3.5, "er!"}],
      # 28  In the  (D4 E4)
      [rest: 3.5, n: {"D4", 0.25, "In"}, n: {"E4", 0.25, "the"}],
      # 29  hum-ble town of Da-vid, a  (F#4 F#4 F#4 F#4 E4 E4 E4 D4 D4)  unison as melody; ok:
      #   off-pitch readings are the men (tenor/bass) on the channel
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
      # 30  Sav-ior born to-day, the  (B4 B4 B4 B4 A4 F#4 F#4 D4)
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
      # 31  One who would be called Em-man-u-el  (F#4 F#4 G4 G4 F#4 F#4 F#4 E4 E4 E4 D4 D4)
      #   ok: off-pitch readings are the men (tenor/bass) on the channel
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
      # 32  Be-  (D4 D4)  ok: off-pitch readings are the men (tenor/bass) on the channel
      [n: {"D4", 2, "~el"}, rest: 1.75, n: {"D4", 0.25, "Be-"}],
      # 33  hold the host of heav-en with  (F#4 F#4 F#4 F#4 E4 E4 E4 D4 D4)
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
      # 34  ho-ly roar pro-claim the  (B4 B4 B4 B4 A4 F#4 F#4 D4)
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
      # 35  One who would be called Em-man-u-el  (F#4 F#4 G4 G4 F#4 F#4 F#4 E4 E4 E4 D4 D4)
      #   ok: off-pitch readings are the men (tenor/bass) on the channel
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
      # 36  The Mes-  (D4 D4 D4)
      [n: {"D4", 2, "~el"}, rest: 1.5, n: {"D4", 0.25, "The"}, n: {"D4", 0.25, "Mes-"}],
      # 37  si-ah our God is with us now  (F#4 F#4 F#4 F#4 B4 A4 A4 G4 G4)  top of divisi
      #   (mel.)
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
      # 38  And the an-gels cry  (G4 D4 E4 F#4 D4 D4 B3)
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
      # 39  Ho-  (B3 B4 F#4)  top of divisi; ok: off-pitch readings are the men (tenor/bass)
      #   on the channel
      [n: {"B3", 1, "~cry"}, rest: 1, n: {"B4", 1, "Ho-"}, n: {"F#4", 1, "~Ho-"}],
      # 40  ly All cre-a-tion cries  (E4 E4 F#4 A4 E4 E4 D4)  ok: off-pitch readings are the
      #   men (tenor/bass) on the channel
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
      # 41  Ho-  (D4 A4 E4)  ok: off-pitch readings are the men (tenor/bass) on the channel
      [n: {"D4", 1, "~cries"}, rest: 1, n: {"A4", 1, "Ho-"}, n: {"E4", 1, "~Ho-"}],
      # 42  ly You are lift-ed high  (F#4 F#4 G4 A4 F#4 F#4 B4)  top of divisi; ok: off-pitch
      #   readings are the men (tenor/bass) on the channel; You heard a touch sharp (0.5 st)
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
      # 43  ho-  (B4 B4)
      [n: {"B4", 1, "~high"}, rest: 1, n: {"B4", 2, "ho-"}],
      # 44  ly Ho-ly for-ev-  (A4 G4 A4 B4 B4)  ok: off-pitch readings are the men
      #   (tenor/bass) on the channel
      [
        n: {"A4", 1, "ly"},
        rest: 1,
        n: {"G4", 0.5, "Ho-"},
        n: {"A4", 0.5, "ly"},
        n: {"B4", 0.5, "for-"},
        n: {"B4", 0.5, "ev-"}
      ],
      # 45  er  (B4 A4 A4)  ok: off-pitch readings are the men (tenor/bass) on the channel
      [n: {"B4", 0.5, "~ev-"}, n: {"A4", 0.5, "er"}, n: {"A4", 3, "~er"}],
      # 46  Hear Your peo-ple sing  (F#4 G4 A4 F#4 F#4 D4)  top of divisi; ple F#4/D4, sing
      #   D4/B3 at 400 dpi; ok: off-pitch readings are the men (tenor/bass) on the channel
      [
        rest: 1.5,
        n: {"F#4", 0.25, "Hear"},
        n: {"G4", 0.25, "Your"},
        n: {"A4", 0.75, "peo-"},
        n: {"F#4", 0.25, "ple"},
        n: {"F#4", 0.5, "~ple"},
        n: {"D4", 0.5, "sing"}
      ],
      # 47  Ho-  (D4 B4 F#4)  top of divisi; ok: off-pitch readings are the men (tenor/bass)
      #   on the channel; ? ~sing heard F#4 (36% on), score D4/B3
      [n: {"D4", 1, "~sing"}, rest: 1, n: {"B4", 1, "Ho-"}, n: {"F#4", 1, "~Ho-"}],
      # 48  ly to the King of kings  (E4 E4 F#4 A4 E4 E4 D4)  ok: off-pitch readings are the
      #   men (tenor/bass) on the channel
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
      # 49  Ho-  (D4 A4 E4)  ok: off-pitch readings are the men (tenor/bass) on the channel
      [n: {"D4", 1, "~kings"}, rest: 1, n: {"A4", 1, "Ho-"}, n: {"E4", 1, "~Ho-"}],
      # 50  ly You will al-ways be  (F#4 F#4 G4 A4 F#4 F#4 B4)  ok: off-pitch readings are the
      #   men (tenor/bass) on the channel; ok: recording sings flat here
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
      # 51  ho-  (B4 B4)  ok: off-pitch readings are the men (tenor/bass) on the channel
      [n: {"B4", 1, "~be"}, rest: 1, n: {"B4", 2, "ho-"}],
      # 52  ly Ho-ly for-ev-  (A4 G4 A4 B4 B4)  ok: off-pitch readings are the men
      #   (tenor/bass) on the channel
      [
        n: {"A4", 1, "ly"},
        rest: 1,
        n: {"G4", 0.5, "Ho-"},
        n: {"A4", 0.5, "ly"},
        n: {"B4", 0.5, "for-"},
        n: {"B4", 0.5, "ev-"}
      ],
      # 53  (rest)  ok: off-pitch readings are the men (tenor/bass) on the channel
      [n: {"B4", 0.5, "~er!"}, n: {"A4", 0.5, "~er!"}, n: {"A4", 3, "~er!"}],
      # 54  Your  (B3)  women unison
      [rest: 3.5, n: {"B3", 0.5, "Your"}],
      # 55  name is the high-est, Your  (B3 B3 B3 B3 A3 C#4)
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
      # 56  name is the great-est. Your  (C#4 C#4 C#4 C#4 B3 D4)  ok: recording sings flat
      #   here
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
      # 57  name stands a-bove them  (D4 D4 C#4 C#4 B3)
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"B3", 0.25, "them"}
      ],
      # 58  all. All  (B3 D4)  All: top of divisi D4/B3
      [n: {"B3", 2, "all."}, rest: 1.5, n: {"D4", 0.5, "All"}],
      # 59  thrones and do-min-ions, all  (D4 D4 D4 D4 C#4 E4)  top of divisi (tenors have the
      #   tune)
      [
        n: {"D4", 1, "thrones"},
        rest: 0.5,
        n: {"D4", 0.25, "and"},
        n: {"D4", 0.25, "do-"},
        n: {"D4", 0.75, "min-"},
        n: {"C#4", 0.25, "ions,"},
        rest: 0.5,
        n: {"E4", 0.5, "all"}
      ],
      # 60  pow'rs and po-si-tions. Your  (E4 E4 E4 E4 D4 F#4)  top of divisi; ok: recording
      #   sings flat here
      [
        n: {"E4", 1, "pow'rs"},
        rest: 0.5,
        n: {"E4", 0.25, "and"},
        n: {"E4", 0.25, "po-"},
        n: {"E4", 0.75, "si-"},
        n: {"D4", 0.25, "tions."},
        rest: 0.5,
        n: {"F#4", 0.5, "Your"}
      ],
      # 61  name stands a-bove them  (F#4 F#4 E4 E4 D4)  top of divisi
      [
        n: {"F#4", 1, "name"},
        rest: 1,
        n: {"F#4", 0.75, "stands"},
        n: {"E4", 0.25, "a-"},
        n: {"E4", 0.75, "bove"},
        n: {"D4", 0.25, "them"}
      ],
      # 62  all. Your  (D4 F#4)  Your: top of divisi F#4/D4 at 400 dpi; ok: off-pitch readings
      #   are the men (tenor/bass) on the channel
      [n: {"D4", 2, "all."}, rest: 1.5, n: {"F#4", 0.5, "Your"}],
      # 63  name is the high-est, Your  (G4 G4 G4 G4 F#4 A4)  top of divisi; ok: off-pitch
      #   readings are the men (tenor/bass) on the channel
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
      # 64  name is the great-est. Your  (A4 A4 A4 A4 F#4 B4)  ok: off-pitch readings are the
      #   men (tenor/bass) on the channel
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
      # 65  name stands a-bove them  (B4 B4 A4 A4 G4)  ok: off-pitch readings are the men
      #   (tenor/bass) on the channel; ? them heard C5 (33% on)
      [
        n: {"B4", 1, "name"},
        rest: 1,
        n: {"B4", 0.75, "stands"},
        n: {"A4", 0.25, "a-"},
        n: {"A4", 0.75, "bove"},
        n: {"G4", 0.25, "them"}
      ],
      # 66  all. All  (G4 G4)  top of divisi
      [n: {"G4", 2, "all."}, rest: 1.5, n: {"G4", 0.5, "All"}],
      # 67  thrones and do-min-ions, all  (G4 G4 G4 G4 F#4 A4)  ok: off-pitch readings are the
      #   men (tenor/bass) on the channel
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
      # 68  pow'rs and po-si-tions. Your  (A4 A4 A4 A4 F#4 B4)  ok: off-pitch readings are the
      #   men (tenor/bass) on the channel
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
      # 69  name stands a-bove them  (B4 B4 A4 A4 G4)  top of divisi
      [
        n: {"B4", 1, "name"},
        rest: 1,
        n: {"B4", 0.75, "stands"},
        n: {"A4", 0.25, "a-"},
        n: {"A4", 0.75, "bove"},
        n: {"G4", 0.25, "them"}
      ],
      # 70  all. And the an-gels cry,  (G4 D4 E4 F#4 A4 A4 B4)  unison, cry top B4/G4; ok:
      #   recording sings flat here
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
      # 71  Ho-  (B4 B4 F#4)  top of divisi B4/F#4 then F#4/D4 (melody follows the lower
      #   'mel.' line); ok: off-pitch readings are the men (tenor/bass) on the channel
      [n: {"B4", 1, "~cry,"}, rest: 1, n: {"B4", 1, "Ho-"}, n: {"F#4", 1, "~Ho-"}],
      # 72  ly. All cre-a-tion cries,  (E4 E4 F#4 A4 E4 E4 D4)  ok: off-pitch readings are the
      #   men (tenor/bass) on the channel
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
      # 73  Ho-  (D4 A4 E4)
      [n: {"D4", 1, "~cries,"}, rest: 1, n: {"A4", 1, "Ho-"}, n: {"E4", 1, "~Ho-"}],
      # 74  ly." You are lift-ed high,  (F#4 F#4 G4 A4 F#4 F#4 B4)  ok: recording sings flat
      #   here
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
      # 75  ho-  (B4 B4)
      [n: {"B4", 1, "~high,"}, rest: 1, n: {"B4", 2, "ho-"}],
      # 76  ly! Ho-ly for-ev-  (A4 G4 A4 B4 B4)  ok: off-pitch readings are the men
      #   (tenor/bass) on the channel
      [
        n: {"A4", 1, "ly!"},
        rest: 1,
        n: {"G4", 0.5, "Ho-"},
        n: {"A4", 0.5, "ly"},
        n: {"B4", 0.5, "for-"},
        n: {"B4", 0.5, "ev-"}
      ],
      # 77  er!  (B4 A4)  ok: off-pitch readings are the men (tenor/bass) on the channel
      [n: {"B4", 0.5, "~ev-"}, n: {"A4", 3.5, "er!"}],
      # 78  Hear Your peo-ple sing,  (F#4 G4 A4 F#4 F#4 D4)  top of divisi, as bar 46; ple ok:
      #   recording sings flat here; sing heard F#4 (45% on)
      [
        rest: 1.5,
        n: {"F#4", 0.25, "Hear"},
        n: {"G4", 0.25, "Your"},
        n: {"A4", 0.75, "peo-"},
        n: {"F#4", 0.25, "ple"},
        n: {"F#4", 0.5, "~ple"},
        n: {"D4", 0.5, "sing,"}
      ],
      # 79  "Ho-  (D4 B4 F#4)  top of divisi; ok: off-pitch readings are the men (tenor/bass)
      #   on the channel; ? ~sing heard F#4, as bar 47
      [n: {"D4", 1, "~sing,"}, rest: 1, n: {"B4", 1, "\"Ho-"}, n: {"F#4", 1, "~Ho-"}],
      # 80  ly" to the King of kings,  (E4 E4 F#4 A4 E4 E4 D4)  ok: off-pitch readings are the
      #   men (tenor/bass) on the channel; ly heard G#4 (A3 tenor, 4.4 st)
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
      # 81  "Ho-  (D4 A4 E4)  ok: off-pitch readings are the men (tenor/bass) on the channel
      [n: {"D4", 1, "~kings,"}, rest: 1, n: {"A4", 1, "\"Ho-"}, n: {"E4", 1, "~Ho-"}],
      # 82  ly." You will al-ways be  (F#4 F#4 G4 A4 F#4 F#4 B4)  ok: off-pitch readings are
      #   the men (tenor/bass) on the channel
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
      # 83  ho-  (B4 B4)  ? ho- heard D5 (38% on), score B4
      [n: {"B4", 1, "~be"}, rest: 1, n: {"B4", 2, "ho-"}],
      # 84  ly! Ho-ly for-ev-  (A4 G4 A4 B4 B4)  ok: off-pitch readings are the men
      #   (tenor/bass) on the channel
      [
        n: {"A4", 1, "ly!"},
        rest: 1,
        n: {"G4", 0.5, "Ho-"},
        n: {"A4", 0.5, "ly"},
        n: {"B4", 0.5, "for-"},
        n: {"B4", 0.5, "ev-"}
      ],
      # 85  er!  (B4 A4)  ok: off-pitch readings are the men (tenor/bass) on the channel
      [n: {"B4", 0.5, "~ev-"}, n: {"A4", 3.5, "er!"}],
      # 86  You will al-ways be,  (F#4 G4 A4 F#4 F#4 B4)  top of divisi; ok: recording sings
      #   flat here; ? will heard C5 (0% on), score G4/E4
      [
        rest: 1.5,
        n: {"F#4", 0.25, "You"},
        n: {"G4", 0.25, "will"},
        n: {"A4", 0.75, "al-"},
        n: {"F#4", 0.25, "ways"},
        n: {"F#4", 0.5, "~ways"},
        n: {"B4", 0.5, "be,"}
      ],
      # 87  Ho-  (B4 B4)  B4 half over alto G4-F#4
      [n: {"B4", 1, "~be,"}, rest: 1, n: {"B4", 2, "Ho-"}],
      # 88  ly! Ho-ly for-ev-  (A4 E4 F#4 G4 G4)  women unison from Ho-ly
      [
        n: {"A4", 1, "ly!"},
        rest: 1,
        n: {"E4", 0.5, "Ho-"},
        n: {"F#4", 0.5, "ly"},
        n: {"G4", 0.5, "for-"},
        n: {"G4", 0.5, "ev-"}
      ],
      # 89  er, and ev-  (G4 F#4 E4 E4)
      [
        n: {"G4", 0.5, "~ev-"},
        n: {"F#4", 2.5, "er,"},
        n: {"E4", 0.5, "and"},
        n: {"E4", 0.5, "ev-"}
      ],
      # 90  er. You will al-ways be,  (E4 D4 D4 E4 F#4 D4 D4 G4)  women unison; ok: recording
      #   sings flat here
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
      # 91  (rest)  women (be); men echo
      [n: {"G4", 2, "~be,"}, rest: 2],
      # 92  You will al-ways be,  (C#4 D4 E4 F#4 F#4 F#4)  women; ok: recording sings flat
      #   here
      [
        rest: 1.5,
        n: {"C#4", 0.25, "You"},
        n: {"D4", 0.25, "will"},
        n: {"E4", 0.75, "al-"},
        n: {"F#4", 0.25, "ways"},
        n: {"F#4", 0.5, "~ways"},
        n: {"F#4", 0.5, "be,"}
      ],
      # 93  (rest)  women (be); men echo
      [n: {"F#4", 2, "~be,"}, rest: 2],
      # 94  You will al-ways be,  (D4 E4 F#4 D4 D4 G4)  women; ok: recording sings flat here
      [
        rest: 1.5,
        n: {"D4", 0.25, "You"},
        n: {"E4", 0.25, "will"},
        n: {"F#4", 0.75, "al-"},
        n: {"D4", 0.25, "ways"},
        n: {"D4", 0.5, "~ways"},
        n: {"G4", 0.5, "be,"}
      ],
      # 95  Ho-  (G4 G4 F#4)  women, then all unison
      [n: {"G4", 1, "~be,"}, rest: 1, n: {"G4", 1, "Ho-"}, n: {"F#4", 1, "~Ho-"}],
      # 96  ly! Ho-ly for-ev-  (E4 C#4 D4 E4 E4)  ok: recording sings flat here
      [
        n: {"E4", 1, "ly!"},
        rest: 1,
        n: {"C#4", 0.5, "Ho-"},
        n: {"D4", 0.5, "ly"},
        n: {"E4", 0.5, "for-"},
        n: {"E4", 0.5, "ev-"}
      ],
      # 97  er!  (E4 D4)
      [n: {"E4", 0.5, "~ev-"}, n: {"D4", 3.5, "er!"}],
      # 98  (rest)
      [rest: 4]
    ]
  end

  defp alto_bars do
    [
      # 1  (rest)
      [rest: 4],
      # 2  (rest)
      [rest: 4],
      # 3  (rest)
      [rest: 4],
      # 4  (rest)
      [rest: 4],
      # 5  Held with-in a man-ger, the  (F#4 F#4 F#4 F#4 E4 E4 E4 D4 D4)  solo (women opt.
      #   solo); ok: recording sings flat here
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
      # 6  Son of God ar-rived, the  (B4 B4 B4 B4 A4 F#4 F#4 D4)  solo; ok: recording sings
      #   flat here
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
      # 7  One who would be called Em-man-u-el.  (F#4 F#4 G4 G4 F#4 F#4 F#4 E4 E4 E4 D4 D4)
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
      # 8  The  (D4 D4)
      [n: {"D4", 2, "~el."}, rest: 1, rest: 0.75, n: {"D4", 0.25, "The"}],
      # 9  Prom-ise was de-liv-ered un-  (F#4 F#4 F#4 F#4 E4 E4 E4 D4 D4)
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
      # 10  to a vir-gin bride, the  (B4 B4 B4 B4 A4 F#4 F#4 D4)
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
      # 11  One who would be called Em-man-u-el.  (F#4 F#4 G4 G4 F#4 F#4 F#4 E4 E4 E4 D4 D4)
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
      # 12  Your  (D4 B3)  ok: recording sings flat here
      [n: {"D4", 2, "~el."}, rest: 1, rest: 0.5, n: {"B3", 0.5, "Your"}],
      # 13  name is the high-est, Your  (B3 B3 B3 B3 A3 C#4)
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
      # 14  name is the great-est. Your  (C#4 C#4 C#4 C#4 B3 D4)  ok: recording sings flat
      #   here
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
      # 15  name stands a-bove them  (D4 D4 C#4 C#4 B3)
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"B3", 0.25, "them"}
      ],
      # 16  all. All  (B3 B3)
      [n: {"B3", 2, "all."}, rest: 1, rest: 0.5, n: {"B3", 0.5, "All"}],
      # 17  thrones and do-min-ions, all  (B3 B3 B3 B3 A3 C#4)
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
      # 18  pow'rs and po-si-tions. Your  (C#4 C#4 C#4 C#4 B3 D4)
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
      # 19  name stands a-bove them  (D4 D4 C#4 C#4 D4)
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"D4", 0.25, "them"}
      ],
      # 20  all. And the an-gels cry,  (D4 D4 E4 F#4 D4 D4 B3)  unison, cry lower of divisi
      #   D4/B3
      [
        n: {"D4", 1, "all."},
        rest: 0.5,
        n: {"D4", 0.25, "And"},
        n: {"E4", 0.25, "the"},
        n: {"F#4", 0.75, "an-"},
        n: {"D4", 0.25, "gels"},
        n: {"D4", 0.5, "~gels"},
        n: {"B3", 0.5, "cry,"}
      ],
      # 21  Ho-  (B3 F#4 D4)  lower of divisi B4/F#4 then F#4/D4; ok: recording sings flat
      #   here
      [n: {"B3", 1, "~cry,"}, rest: 1, n: {"F#4", 1, "Ho-"}, n: {"D4", 1, "~Ho-"}],
      # 22  ly. All cre-a-tion cries,  (C#4 C#4 D4 E4 C#4 C#4 A3)  lower of divisi; a- soprano
      #   bleed; ? tion heard B3 (0% on), score E4/C#4 at 400 dpi
      [
        n: {"C#4", 1, "ly."},
        rest: 0.5,
        n: {"C#4", 0.25, "All"},
        n: {"D4", 0.25, "cre-"},
        n: {"E4", 0.75, "a-"},
        n: {"C#4", 0.25, "tion"},
        n: {"C#4", 0.5, "~tion"},
        n: {"A3", 0.5, "cries,"}
      ],
      # 23  Ho-  (A3 E4 C#4)  lower of divisi; ok: off-pitch readings are the men (tenor/bass)
      #   on the channel
      [n: {"A3", 1, "~cries,"}, rest: 1, n: {"E4", 1, "Ho-"}, n: {"C#4", 1, "~Ho-"}],
      # 24  ly. You are lift-ed high,  (D4 D4 E4 F#4 D4 D4 G4)  lower of divisi; ok: recording
      #   sings flat here
      [
        n: {"D4", 1, "ly."},
        rest: 0.5,
        n: {"D4", 0.25, "You"},
        n: {"E4", 0.25, "are"},
        n: {"F#4", 0.75, "lift-"},
        n: {"D4", 0.25, "ed"},
        n: {"D4", 0.5, "~ed"},
        n: {"G4", 0.5, "high,"}
      ],
      # 25  ho-  (G4 G4 F#4)  alto G4 then F#4 under sop B4 half
      [n: {"G4", 1, "~high,"}, rest: 1, n: {"G4", 1, "ho-"}, n: {"F#4", 1, "~ho-"}],
      # 26  ly! Ho-ly for-ev-  (E4 E4 F#4 G4 G4)  lower of divisi; ly! heard G#4 and Ho- D#4
      #   (men's A3 / flat), ly heard the tenors' D4
      [
        n: {"E4", 1, "ly!"},
        rest: 1,
        n: {"E4", 0.5, "Ho-"},
        n: {"F#4", 0.5, "ly"},
        n: {"G4", 0.5, "for-"},
        n: {"G4", 0.5, "ev-"}
      ],
      # 27  er!  (G4 F#4)  lower of divisi B4/G4 then A4/F#4
      [n: {"G4", 0.5, "~ev-"}, n: {"F#4", 3.5, "er!"}],
      # 28  In the  (D4 E4)
      [rest: 3.5, n: {"D4", 0.25, "In"}, n: {"E4", 0.25, "the"}],
      # 29  hum-ble town of Da-vid, a  (F#4 F#4 F#4 F#4 E4 E4 E4 D4 D4)  unison as melody; ok:
      #   off-pitch readings are the men (tenor/bass) on the channel; ok: recording sings flat
      #   here
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
      # 30  Sav-ior born to-day, the  (B4 B4 B4 B4 A4 F#4 F#4 D4)
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
      # 31  One who would be called Em-man-u-el  (F#4 F#4 G4 G4 F#4 F#4 F#4 E4 E4 E4 D4 D4)
      #   ok: off-pitch readings are the men (tenor/bass) on the channel
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
      # 32  Be-  (D4 D4)  ok: recording sings flat here
      [n: {"D4", 2, "~el"}, rest: 1.75, n: {"D4", 0.25, "Be-"}],
      # 33  hold the host of heav-en with  (F#4 F#4 F#4 F#4 E4 E4 E4 D4 D4)  ok: recording
      #   sings flat here
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
      # 34  ho-ly roar pro-claim the  (B4 B4 B4 B4 A4 F#4 F#4 D4)
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
      # 35  One who would be called Em-man-u-el  (F#4 F#4 G4 G4 F#4 F#4 F#4 E4 E4 E4 D4 D4)
      #   ok: off-pitch readings are the men (tenor/bass) on the channel
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
      # 36  The Mes-  (D4 D4 D4)
      [n: {"D4", 2, "~el"}, rest: 1.5, n: {"D4", 0.25, "The"}, n: {"D4", 0.25, "Mes-"}],
      # 37  si-ah our God is with us now  (D4 D4 D4 D4 F#4 E4 E4 D4 D4)  lower of divisi (mel.
      #   on top); our/is/with/us readings are the other voices
      [
        n: {"D4", 0.75, "si-"},
        n: {"D4", 0.25, "ah"},
        n: {"D4", 0.5, "~ah"},
        rest: 0.25,
        n: {"D4", 0.25, "our"},
        n: {"F#4", 0.75, "God"},
        n: {"E4", 0.25, "is"},
        n: {"E4", 0.25, "with"},
        n: {"D4", 0.5, "us"},
        n: {"D4", 0.25, "now"}
      ],
      # 38  And the an-gels cry  (D4 D4 E4 F#4 D4 D4 B3)  now: lower of divisi G4/D4
      [
        n: {"D4", 1, "~now"},
        rest: 0.5,
        n: {"D4", 0.25, "And"},
        n: {"E4", 0.25, "the"},
        n: {"F#4", 0.75, "an-"},
        n: {"D4", 0.25, "gels"},
        n: {"D4", 0.5, "~gels"},
        n: {"B3", 0.5, "cry"}
      ],
      # 39  Ho-  (B3 F#4 D4)  lower of divisi
      [n: {"B3", 1, "~cry"}, rest: 1, n: {"F#4", 1, "Ho-"}, n: {"D4", 1, "~Ho-"}],
      # 40  ly All cre-a-tion cries  (C#4 C#4 D4 E4 C#4 C#4 A3)  lower of divisi; a- soprano
      #   bleed; ? tion heard C4 (0% on), score C#4 at 400 dpi
      [
        n: {"C#4", 1, "ly"},
        rest: 0.5,
        n: {"C#4", 0.25, "All"},
        n: {"D4", 0.25, "cre-"},
        n: {"E4", 0.75, "a-"},
        n: {"C#4", 0.25, "tion"},
        n: {"C#4", 0.5, "~tion"},
        n: {"A3", 0.5, "cries"}
      ],
      # 41  Ho-  (A3 E4 C#4)  lower of divisi; Ho- soprano bleed; ? ~cries heard G3 (29% on),
      #   score A3
      [n: {"A3", 1, "~cries"}, rest: 1, n: {"E4", 1, "Ho-"}, n: {"C#4", 1, "~Ho-"}],
      # 42  ly You are lift-ed high  (D4 D4 E4 F#4 D4 D4 G4)  lower of divisi; ok: recording
      #   sings flat here
      [
        n: {"D4", 1, "ly"},
        rest: 0.5,
        n: {"D4", 0.25, "You"},
        n: {"E4", 0.25, "are"},
        n: {"F#4", 0.75, "lift-"},
        n: {"D4", 0.25, "ed"},
        n: {"D4", 0.5, "~ed"},
        n: {"G4", 0.5, "high"}
      ],
      # 43  ho-  (G4 G4 F#4)  alto G4 then F#4 under sop B4 half
      [n: {"G4", 1, "~high"}, rest: 1, n: {"G4", 1, "ho-"}, n: {"F#4", 1, "~ho-"}],
      # 44  ly Ho-ly for-ev-  (E4 E4 F#4 G4 G4)  lower of divisi; ly/Ho- readings are sop/bass
      #   A
      [
        n: {"E4", 1, "ly"},
        rest: 1,
        n: {"E4", 0.5, "Ho-"},
        n: {"F#4", 0.5, "ly"},
        n: {"G4", 0.5, "for-"},
        n: {"G4", 0.5, "ev-"}
      ],
      # 45  er  (G4 F#4 F#4)  lower of divisi B4/G4 then A4/F#4
      [n: {"G4", 0.5, "~ev-"}, n: {"F#4", 0.5, "er"}, n: {"F#4", 3, "~er"}],
      # 46  Hear Your peo-ple sing  (D4 E4 F#4 D4 D4 B3)  lower of divisi; ple F#4/D4, sing
      #   D4/B3 at 400 dpi
      [
        rest: 1.5,
        n: {"D4", 0.25, "Hear"},
        n: {"E4", 0.25, "Your"},
        n: {"F#4", 0.75, "peo-"},
        n: {"D4", 0.25, "ple"},
        n: {"D4", 0.5, "~ple"},
        n: {"B3", 0.5, "sing"}
      ],
      # 47  Ho-  (B3 F#4 D4)  lower of divisi; ~sing heard G#3 (the tenors' G3)
      [n: {"B3", 1, "~sing"}, rest: 1, n: {"F#4", 1, "Ho-"}, n: {"D4", 1, "~Ho-"}],
      # 48  ly to the King of kings  (C#4 C#4 D4 E4 C#4 C#4 A3)  lower of divisi; King/kings
      #   soprano bleed; ? of heard F#4 (25% on)
      [
        n: {"C#4", 1, "ly"},
        rest: 0.5,
        n: {"C#4", 0.25, "to"},
        n: {"D4", 0.25, "the"},
        n: {"E4", 0.75, "King"},
        n: {"C#4", 0.25, "of"},
        n: {"C#4", 0.5, "~of"},
        n: {"A3", 0.5, "kings"}
      ],
      # 49  Ho-  (A3 E4 C#4)  lower of divisi; readings are sop A4 and bass F#3
      [n: {"A3", 1, "~kings"}, rest: 1, n: {"E4", 1, "Ho-"}, n: {"C#4", 1, "~Ho-"}],
      # 50  ly You will al-ways be  (D4 D4 E4 F#4 D4 D4 G4)  lower of divisi
      [
        n: {"D4", 1, "ly"},
        rest: 0.5,
        n: {"D4", 0.25, "You"},
        n: {"E4", 0.25, "will"},
        n: {"F#4", 0.75, "al-"},
        n: {"D4", 0.25, "ways"},
        n: {"D4", 0.5, "~ways"},
        n: {"G4", 0.5, "be"}
      ],
      # 51  ho-  (G4 G4 F#4)  alto G4 then F#4 under sop B4 half
      [n: {"G4", 1, "~be"}, rest: 1, n: {"G4", 1, "ho-"}, n: {"F#4", 1, "~ho-"}],
      # 52  ly Ho-ly for-ev-  (E4 E4 F#4 G4 G4)  lower of divisi; readings are sop/bass A
      [
        n: {"E4", 1, "ly"},
        rest: 1,
        n: {"E4", 0.5, "Ho-"},
        n: {"F#4", 0.5, "ly"},
        n: {"G4", 0.5, "for-"},
        n: {"G4", 0.5, "ev-"}
      ],
      # 53  (rest)  lower of divisi; ? er! heard C5 (21% on), score G4 then F#4
      [n: {"G4", 0.5, "~er!"}, n: {"F#4", 0.5, "~er!"}, n: {"F#4", 3, "~er!"}],
      # 54  Your  (B3)  women unison; ok: recording sings flat here
      [rest: 3.5, n: {"B3", 0.5, "Your"}],
      # 55  name is the high-est, Your  (B3 B3 B3 B3 A3 C#4)
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
      # 56  name is the great-est. Your  (C#4 C#4 C#4 C#4 B3 D4)
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
      # 57  name stands a-bove them  (D4 D4 C#4 C#4 B3)
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"B3", 0.25, "them"}
      ],
      # 58  all. All  (B3 B3)  All: lower of divisi D4/B3
      [n: {"B3", 2, "all."}, rest: 1.5, n: {"B3", 0.5, "All"}],
      # 59  thrones and do-min-ions, all  (B3 B3 B3 B3 A3 C#4)  lower of divisi (with the
      #   tenors' tune); ok: recording sings flat here
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
      # 60  pow'rs and po-si-tions. Your  (C#4 C#4 C#4 C#4 B3 D4)  lower of divisi
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
      # 61  name stands a-bove them  (D4 D4 C#4 C#4 B3)  lower of divisi
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"B3", 0.25, "them"}
      ],
      # 62  all. Your  (B3 D4)  Your: lower of divisi F#4/D4
      [n: {"B3", 2, "all."}, rest: 1.5, n: {"D4", 0.5, "Your"}],
      # 63  name is the high-est, Your  (D4 D4 D4 D4 D4 E4)  lower of divisi
      [
        n: {"D4", 1, "name"},
        rest: 0.5,
        n: {"D4", 0.25, "is"},
        n: {"D4", 0.25, "the"},
        n: {"D4", 0.75, "high-"},
        n: {"D4", 0.25, "est,"},
        rest: 0.5,
        n: {"E4", 0.5, "Your"}
      ],
      # 64  name is the great-est. Your  (E4 E4 E4 E4 D4 F#4)  lower of divisi; readings are
      #   sop A4
      [
        n: {"E4", 1, "name"},
        rest: 0.5,
        n: {"E4", 0.25, "is"},
        n: {"E4", 0.25, "the"},
        n: {"E4", 0.75, "great-"},
        n: {"D4", 0.25, "est."},
        rest: 0.5,
        n: {"F#4", 0.5, "Your"}
      ],
      # 65  name stands a-bove them  (F#4 F#4 E4 E4 D4)  lower of divisi; readings are
      #   sop/bass
      [
        n: {"F#4", 1, "name"},
        rest: 1,
        n: {"F#4", 0.75, "stands"},
        n: {"E4", 0.25, "a-"},
        n: {"E4", 0.75, "bove"},
        n: {"D4", 0.25, "them"}
      ],
      # 66  all. All  (D4 D4)  lower of divisi; all heard sop G4
      [n: {"D4", 2, "all."}, rest: 1.5, n: {"D4", 0.5, "All"}],
      # 67  thrones and do-min-ions, all  (D4 D4 D4 D4 D4 E4)  lower of divisi; ok: recording
      #   sings flat here
      [
        n: {"D4", 1, "thrones"},
        rest: 0.5,
        n: {"D4", 0.25, "and"},
        n: {"D4", 0.25, "do-"},
        n: {"D4", 0.75, "min-"},
        n: {"D4", 0.25, "ions,"},
        rest: 0.5,
        n: {"E4", 0.5, "all"}
      ],
      # 68  pow'rs and po-si-tions. Your  (E4 E4 E4 E4 D4 F#4)  lower of divisi; ok: recording
      #   sings flat here
      [
        n: {"E4", 1, "pow'rs"},
        rest: 0.5,
        n: {"E4", 0.25, "and"},
        n: {"E4", 0.25, "po-"},
        n: {"E4", 0.75, "si-"},
        n: {"D4", 0.25, "tions."},
        rest: 0.5,
        n: {"F#4", 0.5, "Your"}
      ],
      # 69  name stands a-bove them  (F#4 F#4 E4 E4 D4)  lower of divisi; readings are
      #   sop/bass
      [
        n: {"F#4", 1, "name"},
        rest: 1,
        n: {"F#4", 0.75, "stands"},
        n: {"E4", 0.25, "a-"},
        n: {"E4", 0.75, "bove"},
        n: {"D4", 0.25, "them"}
      ],
      # 70  all. And the an-gels cry,  (D4 D4 E4 F#4 A4 A4 G4)  unison; cry lower B4/G4; ?
      #   gels heard G4 (0% on), score A4 single
      [
        n: {"D4", 1, "all."},
        rest: 0.5,
        n: {"D4", 0.25, "And"},
        n: {"E4", 0.25, "the"},
        n: {"F#4", 0.75, "an-"},
        n: {"A4", 0.25, "gels"},
        n: {"A4", 0.5, "~gels"},
        n: {"G4", 0.5, "cry,"}
      ],
      # 71  Ho-  (G4 F#4 D4)  lower of divisi G4, then F#4/D4 (marked mel.)
      [n: {"G4", 1, "~cry,"}, rest: 1, n: {"F#4", 1, "Ho-"}, n: {"D4", 1, "~Ho-"}],
      # 72  ly. All cre-a-tion cries,  (C#4 C#4 D4 E4 C#4 C#4 A3)  lower of divisi; ok:
      #   recording sings flat here; ? tion heard B3 (0% on), as bar 22
      [
        n: {"C#4", 1, "ly."},
        rest: 0.5,
        n: {"C#4", 0.25, "All"},
        n: {"D4", 0.25, "cre-"},
        n: {"E4", 0.75, "a-"},
        n: {"C#4", 0.25, "tion"},
        n: {"C#4", 0.5, "~tion"},
        n: {"A3", 0.5, "cries,"}
      ],
      # 73  Ho-  (A3 E4 C#4)  lower of divisi; ? ~cries heard G3, as bar 41; Ho- readings are
      #   sop A4 / bass F#3
      [n: {"A3", 1, "~cries,"}, rest: 1, n: {"E4", 1, "Ho-"}, n: {"C#4", 1, "~Ho-"}],
      # 74  ly." You are lift-ed high,  (D4 D4 E4 F#4 D4 D4 G4)  lower of divisi; ok:
      #   recording sings flat here
      [
        n: {"D4", 1, "ly.\""},
        rest: 0.5,
        n: {"D4", 0.25, "You"},
        n: {"E4", 0.25, "are"},
        n: {"F#4", 0.75, "lift-"},
        n: {"D4", 0.25, "ed"},
        n: {"D4", 0.5, "~ed"},
        n: {"G4", 0.5, "high,"}
      ],
      # 75  ho-  (G4 G4 F#4)  alto G4 then F#4 under sop B4 half
      [n: {"G4", 1, "~high,"}, rest: 1, n: {"G4", 1, "ho-"}, n: {"F#4", 1, "~ho-"}],
      # 76  ly! Ho-ly for-ev-  (E4 E4 F#4 G4 G4)  lower of divisi; ly heard the tenors' D4; ?
      #   ev- heard C5 (28% on)
      [
        n: {"E4", 1, "ly!"},
        rest: 1,
        n: {"E4", 0.5, "Ho-"},
        n: {"F#4", 0.5, "ly"},
        n: {"G4", 0.5, "for-"},
        n: {"G4", 0.5, "ev-"}
      ],
      # 77  er!  (G4 F#4)  lower of divisi
      [n: {"G4", 0.5, "~ev-"}, n: {"F#4", 3.5, "er!"}],
      # 78  Hear Your peo-ple sing,  (D4 E4 F#4 D4 D4 B3)  lower of divisi; ~sing heard the
      #   tenors' G3
      [
        rest: 1.5,
        n: {"D4", 0.25, "Hear"},
        n: {"E4", 0.25, "Your"},
        n: {"F#4", 0.75, "peo-"},
        n: {"D4", 0.25, "ple"},
        n: {"D4", 0.5, "~ple"},
        n: {"B3", 0.5, "sing,"}
      ],
      # 79  "Ho-  (B3 F#4 D4)  lower of divisi; ~sing heard the tenors' G3
      [n: {"B3", 1, "~sing,"}, rest: 1, n: {"F#4", 1, "\"Ho-"}, n: {"D4", 1, "~Ho-"}],
      # 80  ly" to the King of kings,  (C#4 C#4 D4 E4 C#4 C#4 A3)  lower of divisi; readings
      #   are the other voices
      [
        n: {"C#4", 1, "ly\""},
        rest: 0.5,
        n: {"C#4", 0.25, "to"},
        n: {"D4", 0.25, "the"},
        n: {"E4", 0.75, "King"},
        n: {"C#4", 0.25, "of"},
        n: {"C#4", 0.5, "~of"},
        n: {"A3", 0.5, "kings,"}
      ],
      # 81  "Ho-  (A3 E4 C#4)  lower of divisi; readings are sop D4 / bass F#3
      [n: {"A3", 1, "~kings,"}, rest: 1, n: {"E4", 1, "\"Ho-"}, n: {"C#4", 1, "~Ho-"}],
      # 82  ly." You will al-ways be  (D4 D4 E4 F#4 D4 D4 G4)  lower of divisi
      [
        n: {"D4", 1, "ly.\""},
        rest: 0.5,
        n: {"D4", 0.25, "You"},
        n: {"E4", 0.25, "will"},
        n: {"F#4", 0.75, "al-"},
        n: {"D4", 0.25, "ways"},
        n: {"D4", 0.5, "~ways"},
        n: {"G4", 0.5, "be"}
      ],
      # 83  ho-  (G4 G4 F#4)  alto G4 then F#4 under sop B4 half
      [n: {"G4", 1, "~be"}, rest: 1, n: {"G4", 1, "ho-"}, n: {"F#4", 1, "~ho-"}],
      # 84  ly! Ho-ly for-ev-  (E4 E4 F#4 G4 G4)  lower of divisi; readings are sop/bass
      [
        n: {"E4", 1, "ly!"},
        rest: 1,
        n: {"E4", 0.5, "Ho-"},
        n: {"F#4", 0.5, "ly"},
        n: {"G4", 0.5, "for-"},
        n: {"G4", 0.5, "ev-"}
      ],
      # 85  er!  (G4 F#4)  lower of divisi; er! heard the men's D
      [n: {"G4", 0.5, "~ev-"}, n: {"F#4", 3.5, "er!"}],
      # 86  You will al-ways be,  (D4 E4 F#4 D4 D4 G4)  lower of divisi
      [
        rest: 1.5,
        n: {"D4", 0.25, "You"},
        n: {"E4", 0.25, "will"},
        n: {"F#4", 0.75, "al-"},
        n: {"D4", 0.25, "ways"},
        n: {"D4", 0.5, "~ways"},
        n: {"G4", 0.5, "be,"}
      ],
      # 87  Ho-  (G4 G4 F#4)  alto G4 then F#4 under sop B4 half; Ho- heard sop/tenor B
      [n: {"G4", 1, "~be,"}, rest: 1, n: {"G4", 1, "Ho-"}, n: {"F#4", 1, "~Ho-"}],
      # 88  ly! Ho-ly for-ev-  (A4 E4 F#4 G4 G4)
      [
        n: {"A4", 1, "ly!"},
        rest: 1,
        n: {"E4", 0.5, "Ho-"},
        n: {"F#4", 0.5, "ly"},
        n: {"G4", 0.5, "for-"},
        n: {"G4", 0.5, "ev-"}
      ],
      # 89  er, and ev-  (G4 F#4 E4 E4)
      [
        n: {"G4", 0.5, "~ev-"},
        n: {"F#4", 2.5, "er,"},
        n: {"E4", 0.5, "and"},
        n: {"E4", 0.5, "ev-"}
      ],
      # 90  er. You will al-ways be,  (E4 D4 D4 E4 F#4 D4 D4 G4)  women unison; ok: recording
      #   sings flat here
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
      # 91  (rest)
      [n: {"G4", 2, "~be,"}, rest: 2],
      # 92  You will al-ways be,  (C#4 D4 E4 F#4 F#4 F#4)  women; ok: recording sings flat
      #   here
      [
        rest: 1.5,
        n: {"C#4", 0.25, "You"},
        n: {"D4", 0.25, "will"},
        n: {"E4", 0.75, "al-"},
        n: {"F#4", 0.25, "ways"},
        n: {"F#4", 0.5, "~ways"},
        n: {"F#4", 0.5, "be,"}
      ],
      # 93  (rest)
      [n: {"F#4", 2, "~be,"}, rest: 2],
      # 94  You will al-ways be,  (D4 E4 F#4 D4 D4 G4)
      [
        rest: 1.5,
        n: {"D4", 0.25, "You"},
        n: {"E4", 0.25, "will"},
        n: {"F#4", 0.75, "al-"},
        n: {"D4", 0.25, "ways"},
        n: {"D4", 0.5, "~ways"},
        n: {"G4", 0.5, "be,"}
      ],
      # 95  Ho-  (G4 G4 F#4)
      [n: {"G4", 1, "~be,"}, rest: 1, n: {"G4", 1, "Ho-"}, n: {"F#4", 1, "~Ho-"}],
      # 96  ly! Ho-ly for-ev-  (E4 C#4 D4 E4 E4)
      [
        n: {"E4", 1, "ly!"},
        rest: 1,
        n: {"C#4", 0.5, "Ho-"},
        n: {"D4", 0.5, "ly"},
        n: {"E4", 0.5, "for-"},
        n: {"E4", 0.5, "ev-"}
      ],
      # 97  er!  (E4 D4)
      [n: {"E4", 0.5, "~ev-"}, n: {"D4", 3.5, "er!"}],
      # 98  (rest)
      [rest: 4]
    ]
  end

  defp tenor_bars do
    [
      # 1  (rest)
      [rest: 4],
      # 2  (rest)
      [rest: 4],
      # 3  (rest)
      [rest: 4],
      # 4  (rest)
      [rest: 4],
      # 5  (rest)
      [rest: 4],
      # 6  (rest)
      [rest: 4],
      # 7  (rest)
      [rest: 4],
      # 8  (rest)
      [rest: 4],
      # 9  (rest)
      [rest: 4],
      # 10  (rest)
      [rest: 4],
      # 11  (rest)
      [rest: 4],
      # 12  Your  (B3)  TENORS only (with the women)
      [rest: 3.5, n: {"B3", 0.5, "Your"}],
      # 13  name is the high-est, Your  (B3 B3 B3 B3 A3 C#4)  tenors with the women, unison;
      #   ok: recording sings flat here
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
      # 14  name is the great-est. Your  (C#4 C#4 C#4 C#4 B3 D4)  ok: recording sings flat
      #   here
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
      # 15  name stands a-bove them  (D4 D4 C#4 C#4 B3)
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"B3", 0.25, "them"}
      ],
      # 16  all. All  (B3 B3)
      [n: {"B3", 2, "all."}, rest: 1, rest: 0.5, n: {"B3", 0.5, "All"}],
      # 17  thrones and do-min-ions, all  (B3 B3 B3 B3 A3 C#4)  ok: recording sings flat here
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
      # 18  pow'rs and po-si-tions. Your  (C#4 C#4 C#4 C#4 B3 D4)
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
      # 19  name stands a-bove them  (D4 D4 C#4 C#4 D4)
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"D4", 0.25, "them"}
      ],
      # 20  all. And the an-gels cry,  (D4 D3 E3 F#3 A3 G3)  all. (D4 from bar 19), then add
      #   BASSES: unison with the bass
      [
        n: {"D4", 1, "all."},
        rest: 0.5,
        n: {"D3", 0.25, "And"},
        n: {"E3", 0.25, "the"},
        n: {"F#3", 0.75, "an-"},
        n: {"A3", 0.75, "gels"},
        n: {"G3", 0.5, "cry,"}
      ],
      # 21  Ho-  (G3 D4 B3)  upper of D4/G3, then B3 (bass G3 -> B3); Ho- heard the basses' G3
      [n: {"G3", 1, "~cry,"}, rest: 1, n: {"D4", 1, "Ho-"}, n: {"B3", 1, "~Ho-"}],
      # 22  ly. All cre-a-tion cries,  (A3 A3 B3 C#4 A3 F#3)  a-: upper of C#4/A3
      [
        n: {"A3", 1, "ly."},
        rest: 0.5,
        n: {"A3", 0.25, "All"},
        n: {"B3", 0.25, "cre-"},
        n: {"C#4", 0.75, "a-"},
        n: {"A3", 0.75, "tion"},
        n: {"F#3", 0.5, "cries,"}
      ],
      # 23  Ho-  (F#3 C#4 A3)  C#4 then A3 over bass F#3; Ho- heard the basses' F#3
      [n: {"F#3", 1, "~cries,"}, rest: 1, n: {"C#4", 1, "Ho-"}, n: {"A3", 1, "~Ho-"}],
      # 24  ly. You are lift-ed high,  (B3 B3 B3 D4 B3 B3)  upper of the bass staff (bass B2);
      #   ok: recording sings flat here
      [
        n: {"B3", 1, "ly."},
        rest: 0.5,
        n: {"B3", 0.25, "You"},
        n: {"B3", 0.25, "are"},
        n: {"D4", 0.75, "lift-"},
        n: {"B3", 0.75, "ed"},
        n: {"B3", 0.5, "high,"}
      ],
      # 25  ho-  (B3 E4 D4)  ok: E4 then D4 at 400 dpi (two ledger lines; confirmed by the
      #   recording)
      [n: {"B3", 1, "~high,"}, rest: 1, n: {"E4", 1, "ho-"}, n: {"D4", 1, "~ho-"}],
      # 26  ly! Ho-ly for-ev-  (C#4 C#4 D4 E4 E4)  upper of divisi over bass A3/D3; ok:
      #   recording sings flat here
      [
        n: {"C#4", 1, "ly!"},
        rest: 1,
        n: {"C#4", 0.5, "Ho-"},
        n: {"D4", 0.5, "ly"},
        n: {"E4", 0.5, "for-"},
        n: {"E4", 0.5, "ev-"}
      ],
      # 27  er!  (E4 D4)  E4 then D4 over bass D3
      [n: {"E4", 0.5, "~ev-"}, n: {"D4", 3.5, "er!"}],
      # 28  In the  (F#3 G3)  men unison
      [rest: 3.5, n: {"F#3", 0.25, "In"}, n: {"G3", 0.25, "the"}],
      # 29  hum-ble town of Da-vid, a  (A3 A3 A3 G3 G3 F#3 F#3)  men unison; ok: recording
      #   sings flat here
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
      # 30  Sav-ior born to-day, the  (G3 G3 G3 F#3 A3 A3)  men unison; ok: recording sings
      #   flat here
      [
        n: {"G3", 0.5, "Sav-"},
        n: {"G3", 0.25, "ior"},
        n: {"G3", 0.75, "born"},
        n: {"F#3", 0.25, "to-"},
        n: {"A3", 1.25, "day,"},
        rest: 0.75,
        n: {"A3", 0.25, "the"}
      ],
      # 31  One who would be called Em-man-u-el.  (B3 B3 B3 B3 A3 A3 A3 G3 G3)  men unison;
      #   ok: recording sings flat here
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
      # 32  Be-  (G3 G3)  men unison; Be- upper of G3/E3
      [n: {"G3", 2, "~el."}, rest: 1, rest: 0.75, n: {"G3", 0.25, "Be-"}],
      # 33  hold the host of heav-en with  (A3 A3 A3 G3 G3 F#3 F#3)  with: upper of F#3/D3
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
      # 34  ho-ly roar pro-claim the  (G3 G3 G3 F#3 A3 A3)  the: upper of A3/F#3; ok:
      #   recording sings flat here
      [
        n: {"G3", 0.5, "ho-"},
        n: {"G3", 0.25, "ly"},
        n: {"G3", 0.75, "roar"},
        n: {"F#3", 0.25, "pro-"},
        n: {"A3", 1.25, "claim"},
        rest: 0.75,
        n: {"A3", 0.25, "the"}
      ],
      # 35  One who would be called Em-man-u-el.  (B3 B3 B3 B3 A3 A3 A3 G3 G3)  men unison
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
      # 36  The Mes-  (G3 G3 G3)  men unison; ok: recording sings flat here
      [n: {"G3", 2, "~el."}, rest: 1, rest: 0.5, n: {"G3", 0.25, "The"}, n: {"G3", 0.25, "Mes-"}],
      # 37  si-ah, our God, is with us now!  (B3 B3 B3 D4 C#4 C#4 B3 B3)  upper of divisi; ok:
      #   recording sings flat here
      [
        n: {"B3", 0.75, "si-"},
        n: {"B3", 0.75, "ah,"},
        rest: 0.25,
        n: {"B3", 0.25, "our"},
        n: {"D4", 0.75, "God,"},
        n: {"C#4", 0.25, "is"},
        n: {"C#4", 0.25, "with"},
        n: {"B3", 0.5, "us"},
        n: {"B3", 0.25, "now!"}
      ],
      # 38  And the an-gels cry,  (B3 D3 E3 F#3 A3 G3)  now: upper B3/G3, then unison
      [
        n: {"B3", 1, "~now!"},
        rest: 0.5,
        n: {"D3", 0.25, "And"},
        n: {"E3", 0.25, "the"},
        n: {"F#3", 0.75, "an-"},
        n: {"A3", 0.75, "gels"},
        n: {"G3", 0.5, "cry,"}
      ],
      # 39  "Ho-  (G3 D4 B3)  upper of D4/G3, then B3; Ho- heard the basses' G3
      [n: {"G3", 1, "~cry,"}, rest: 1, n: {"D4", 1, "\"Ho-"}, n: {"B3", 1, "~Ho-"}],
      # 40  ly." All cre-a-tion cries,  (A3 A3 B3 C#4 A3 F#3)  a-: upper of C#4/A3
      [
        n: {"A3", 1, "ly.\""},
        rest: 0.5,
        n: {"A3", 0.25, "All"},
        n: {"B3", 0.25, "cre-"},
        n: {"C#4", 0.75, "a-"},
        n: {"A3", 0.75, "tion"},
        n: {"F#3", 0.5, "cries,"}
      ],
      # 41  "Ho-  (F#3 C#4 A3)  C#4 then A3 over bass F#3
      [n: {"F#3", 1, "~cries,"}, rest: 1, n: {"C#4", 1, "\"Ho-"}, n: {"A3", 1, "~Ho-"}],
      # 42  ly." You are lift-ed high,  (B3 B3 B3 D4 B3 B3)  upper of divisi
      [
        n: {"B3", 1, "ly.\""},
        rest: 0.5,
        n: {"B3", 0.25, "You"},
        n: {"B3", 0.25, "are"},
        n: {"D4", 0.75, "lift-"},
        n: {"B3", 0.75, "ed"},
        n: {"B3", 0.5, "high,"}
      ],
      # 43  ho-  (B3 E4 D4)  ok: E4 then D4, as bar 25
      [n: {"B3", 1, "~high,"}, rest: 1, n: {"E4", 1, "ho-"}, n: {"D4", 1, "~ho-"}],
      # 44  ly! Ho-ly for-ev-  (C#4 C#4 D4 E4 E4)  upper of divisi
      [
        n: {"C#4", 1, "ly!"},
        rest: 1,
        n: {"C#4", 0.5, "Ho-"},
        n: {"D4", 0.5, "ly"},
        n: {"E4", 0.5, "for-"},
        n: {"E4", 0.5, "ev-"}
      ],
      # 45  er!  (E4 D4)  E4 then D4 over bass D3
      [n: {"E4", 0.5, "~ev-"}, n: {"D4", 3.5, "er!"}],
      # 46  Hear Your peo-ple sing,  (A3 B3 C#4 A3 G3)  upper of divisi; Hear heard the altos'
      #   D4; ? peo- heard D4 (+0.8 st, 14% on), score C#4
      [
        rest: 1,
        rest: 0.5,
        n: {"A3", 0.25, "Hear"},
        n: {"B3", 0.25, "Your"},
        n: {"C#4", 0.75, "peo-"},
        n: {"A3", 0.75, "ple"},
        n: {"G3", 0.5, "sing,"}
      ],
      # 47  "Ho-  (G3 D4 B3)  upper of D4/G3, then B3; Ho- heard the basses' G3
      [n: {"G3", 1, "~sing,"}, rest: 1, n: {"D4", 1, "\"Ho-"}, n: {"B3", 1, "~Ho-"}],
      # 48  ly" to the King of kings,  (A3 A3 B3 C#4 A3 F#3)  ? King heard D4 (+0.8 st), score
      #   C#4/A3
      [
        n: {"A3", 1, "ly\""},
        rest: 0.5,
        n: {"A3", 0.25, "to"},
        n: {"B3", 0.25, "the"},
        n: {"C#4", 0.75, "King"},
        n: {"A3", 0.75, "of"},
        n: {"F#3", 0.5, "kings,"}
      ],
      # 49  "Ho-  (F#3 C#4 A3)  C#4 then A3; Ho- heard sop/bass A
      [n: {"F#3", 1, "~kings,"}, rest: 1, n: {"C#4", 1, "\"Ho-"}, n: {"A3", 1, "~Ho-"}],
      # 50  ly." You will al-ways be  (B3 B3 B3 D4 B3 B3)  upper of divisi; ok: recording
      #   sings flat here
      [
        n: {"B3", 1, "ly.\""},
        rest: 0.5,
        n: {"B3", 0.25, "You"},
        n: {"B3", 0.25, "will"},
        n: {"D4", 0.75, "al-"},
        n: {"B3", 0.75, "ways"},
        n: {"B3", 0.5, "be"}
      ],
      # 51  ho-  (B3 E4 D4)  ok: E4 then D4, as bar 25
      [n: {"B3", 1, "~be"}, rest: 1, n: {"E4", 1, "ho-"}, n: {"D4", 1, "~ho-"}],
      # 52  ly! Ho-ly for-ev-  (C#4 C#4 D4 E4 E4)  upper of divisi; ly! heard the A's; ly
      #   heard B3 (44% on)
      [
        n: {"C#4", 1, "ly!"},
        rest: 1,
        n: {"C#4", 0.5, "Ho-"},
        n: {"D4", 0.5, "ly"},
        n: {"E4", 0.5, "for-"},
        n: {"E4", 0.5, "ev-"}
      ],
      # 53  er!  (E4 D4)  E4 then D4 over bass D3
      [n: {"E4", 0.5, "~ev-"}, n: {"D4", 3.5, "er!"}],
      # 54  Your  (B3)  TENORS only (with the women)
      [rest: 3.5, n: {"B3", 0.5, "Your"}],
      # 55  name is the high-est, Your  (B3 B3 B3 B3 A3 C#4)
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
      # 56  name is the great-est. Your  (C#4 C#4 C#4 C#4 B3 D4)
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
      # 57  name stands a-bove them  (D4 D4 C#4 C#4 B3)  tenors with the women; ? a- heard A#3
      #   (45% on)
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"B3", 0.25, "them"}
      ],
      # 58  all. All  (B3 B3)
      [n: {"B3", 2, "all."}, rest: 1.5, n: {"B3", 0.5, "All"}],
      # 59  thrones and do-min-ions, all  (B3 B3 B3 B3 A3 C#4)
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
      # 60  pow'rs and po-si-tions. Your  (C#4 C#4 C#4 C#4 B3 D4)
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
      # 61  name stands a-bove them  (D4 D4 C#4 C#4 B3)
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"B3", 0.25, "them"}
      ],
      # 62  all. Your  (B3 B3)  add BASSES on Your
      [n: {"B3", 2, "all."}, rest: 1.5, n: {"B3", 0.5, "Your"}],
      # 63  name is the high-est, Your  (B3 B3 B3 B3 A3 C#4)  upper of divisi; ok: recording
      #   sings flat here
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
      # 64  name is the great-est. Your  (C#4 C#4 C#4 C#4 B3 D4)  upper of divisi; est. B3
      #   over bass A3; ? the heard F#4 (14% on)
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
      # 65  name stands a-bove them  (D4 D4 C#4 C#4 B3)  upper of divisi; ok: recording sings
      #   flat here; ? stands heard G4 (20% on)
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"B3", 0.25, "them"}
      ],
      # 66  all. All  (B3 B3)  upper of divisi
      [n: {"B3", 2, "all."}, rest: 1.5, n: {"B3", 0.5, "All"}],
      # 67  thrones and do-min-ions, all  (B3 B3 B3 B3 A3 C#4)  upper of divisi; ions heard
      #   the altos' D4
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
      # 68  pow'rs and po-si-tions. Your  (C#4 C#4 C#4 C#4 B3 D4)  upper of divisi
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
      # 69  name stands a-bove them  (D4 D4 C#4 C#4 B3)  upper of divisi
      [
        n: {"D4", 1, "name"},
        rest: 1,
        n: {"D4", 0.75, "stands"},
        n: {"C#4", 0.25, "a-"},
        n: {"C#4", 0.75, "bove"},
        n: {"B3", 0.25, "them"}
      ],
      # 70  all. And the an-gels cry,  (B3 D3 E3 F#3 A3 B3)  upper of divisi; ok: recording
      #   sings flat here
      [
        n: {"B3", 1, "all."},
        rest: 0.5,
        n: {"D3", 0.25, "And"},
        n: {"E3", 0.25, "the"},
        n: {"F#3", 0.75, "an-"},
        n: {"A3", 0.75, "gels"},
        n: {"B3", 0.5, "cry,"}
      ],
      # 71  "Ho-  (B3 D4 B3)  upper of D4/G3, then B3
      [n: {"B3", 1, "~cry,"}, rest: 1, n: {"D4", 1, "\"Ho-"}, n: {"B3", 1, "~\"Ho-"}],
      # 72  ly." All cre-a-tion cries,  (A3 A3 B3 C#4 A3 F#3)  a-: upper of C#4/A3; reading is
      #   the A's
      [
        n: {"A3", 1, "ly.\""},
        rest: 0.5,
        n: {"A3", 0.25, "All"},
        n: {"B3", 0.25, "cre-"},
        n: {"C#4", 0.75, "a-"},
        n: {"A3", 0.75, "tion"},
        n: {"F#3", 0.5, "cries,"}
      ],
      # 73  "Ho-  (F#3 C#4 A3)  C#4 then A3; Ho- heard a touch sharp
      [n: {"F#3", 1, "~cries,"}, rest: 1, n: {"C#4", 1, "\"Ho-"}, n: {"A3", 1, "~Ho-"}],
      # 74  ly." You are lift-ed high,  (B3 B3 B3 D4 B3 B3)  upper of divisi
      [
        n: {"B3", 1, "ly.\""},
        rest: 0.5,
        n: {"B3", 0.25, "You"},
        n: {"B3", 0.25, "are"},
        n: {"D4", 0.75, "lift-"},
        n: {"B3", 0.75, "ed"},
        n: {"B3", 0.5, "high,"}
      ],
      # 75  ho-  (B3 E4 D4)  ok: E4 then D4, as bar 25
      [n: {"B3", 1, "~high,"}, rest: 1, n: {"E4", 1, "ho-"}, n: {"D4", 1, "~ho-"}],
      # 76  ly! Ho-ly for-ev-  (C#4 C#4 D4 E4 E4)  upper of divisi
      [
        n: {"C#4", 1, "ly!"},
        rest: 1,
        n: {"C#4", 0.5, "Ho-"},
        n: {"D4", 0.5, "ly"},
        n: {"E4", 0.5, "for-"},
        n: {"E4", 0.5, "ev-"}
      ],
      # 77  er!  (E4 D4)  E4 then D4
      [n: {"E4", 0.5, "~ev-"}, n: {"D4", 3.5, "er!"}],
      # 78  Hear Your peo-ple sing,  (A3 B3 C#4 A3 G3)  upper of divisi; Hear heard the altos'
      #   D4; ? ple heard B3 (16% on), score A3/F#3
      [
        rest: 1.5,
        n: {"A3", 0.25, "Hear"},
        n: {"B3", 0.25, "Your"},
        n: {"C#4", 0.75, "peo-"},
        n: {"A3", 0.75, "ple"},
        n: {"G3", 0.5, "sing,"}
      ],
      # 79  "Ho-  (G3 D4 B3)  upper of D4/G3, then B3; Ho- heard the basses' G3
      [n: {"G3", 1, "~sing,"}, rest: 1, n: {"D4", 1, "\"Ho-"}, n: {"B3", 1, "~Ho-"}],
      # 80  ly" to the King of kings,  (A3 A3 B3 C#4 A3 F#3)  a-: upper of C#4/A3
      [
        n: {"A3", 1, "ly\""},
        rest: 0.5,
        n: {"A3", 0.25, "to"},
        n: {"B3", 0.25, "the"},
        n: {"C#4", 0.75, "King"},
        n: {"A3", 0.75, "of"},
        n: {"F#3", 0.5, "kings,"}
      ],
      # 81  "Ho-  (F#3 C#4 A3)  C#4 then A3; ~kings a touch sharp
      [n: {"F#3", 1, "~kings,"}, rest: 1, n: {"C#4", 1, "\"Ho-"}, n: {"A3", 1, "~Ho-"}],
      # 82  ly." You will al-ways be  (B3 B3 B3 D4 B3 B3)  upper of divisi
      [
        n: {"B3", 1, "ly.\""},
        rest: 0.5,
        n: {"B3", 0.25, "You"},
        n: {"B3", 0.25, "will"},
        n: {"D4", 0.75, "al-"},
        n: {"B3", 0.75, "ways"},
        n: {"B3", 0.5, "be"}
      ],
      # 83  ho-  (B3 E4 D4)  ok: E4 then D4, as bar 25
      [n: {"B3", 1, "~be"}, rest: 1, n: {"E4", 1, "ho-"}, n: {"D4", 1, "~ho-"}],
      # 84  ly! Ho-ly for-ev-  (C#4 C#4 D4 E4 E4)  upper of divisi; ? ly! heard B3 (11% on)
      [
        n: {"C#4", 1, "ly!"},
        rest: 1,
        n: {"C#4", 0.5, "Ho-"},
        n: {"D4", 0.5, "ly"},
        n: {"E4", 0.5, "for-"},
        n: {"E4", 0.5, "ev-"}
      ],
      # 85  er!  (E4 D4)
      [n: {"E4", 0.5, "~ev-"}, n: {"D4", 3.5, "er!"}],
      # 86  You will al-ways be,  (A3 B3 D4 A3 B3)  ok: A3 B3 D4 A3 B3 at 400 dpi (over bass
      #   D3/E3); You/ways heard the altos' D4
      [
        rest: 1.5,
        n: {"A3", 0.25, "You"},
        n: {"B3", 0.25, "will"},
        n: {"D4", 0.75, "al-"},
        n: {"A3", 0.75, "ways"},
        n: {"B3", 0.5, "be,"}
      ],
      # 87  Ho-  (B3 E4 D4)  ok: E4 then D4, as bar 25
      [n: {"B3", 1, "~be,"}, rest: 1, n: {"E4", 1, "Ho-"}, n: {"D4", 1, "~Ho-"}],
      # 88  ly! Ho-ly for-ev-  (C#4 E3 F#3 G3 G3)  upper C#4/A3, then men unison
      [
        n: {"C#4", 1, "ly!"},
        rest: 1,
        n: {"E3", 0.5, "Ho-"},
        n: {"F#3", 0.5, "ly"},
        n: {"G3", 0.5, "for-"},
        n: {"G3", 0.5, "ev-"}
      ],
      # 89  er, and ev-  (G3 F#3 E3 E3)  men unison
      [
        n: {"G3", 0.5, "~ev-"},
        n: {"F#3", 2.5, "er,"},
        n: {"E3", 0.5, "and"},
        n: {"E3", 0.5, "ev-"}
      ],
      # 90  er.  (E3 D3)  men unison, then tacet
      [n: {"E3", 0.5, "~ev-"}, n: {"D3", 0.5, "er."}, rest: 3],
      # 91  Ho-  (G3 F#3)  MEN echo
      [rest: 2, n: {"G3", 1, "Ho-"}, n: {"F#3", 1, "~Ho-"}],
      # 92  ly!  (E3)
      [n: {"E3", 2, "ly!"}, rest: 2],
      # 93  Ho-ly, Ho-  (E3 F#3 E3)  MEN echo
      [rest: 2, n: {"E3", 1, "Ho-"}, n: {"F#3", 0.5, "ly,"}, n: {"E3", 0.5, "Ho-"}],
      # 94  ly!  (E3 D3)
      [n: {"E3", 0.5, "~Ho-"}, n: {"D3", 1.5, "ly!"}, rest: 2],
      # 95  Ho-  (G3 F#3)  ALL, men unison
      [rest: 2, n: {"G3", 1, "Ho-"}, n: {"F#3", 1, "~Ho-"}],
      # 96  ly! Ho-ly for-ev-  (E3 C#3 D3 E3 E3)  men unison; ok: recording sings flat here
      [
        n: {"E3", 1, "ly!"},
        rest: 1,
        n: {"C#3", 0.5, "Ho-"},
        n: {"D3", 0.5, "ly"},
        n: {"E3", 0.5, "for-"},
        n: {"E3", 0.5, "ev-"}
      ],
      # 97  er!  (E3 D3)  men unison (rit.)
      [n: {"E3", 0.5, "~ev-"}, n: {"D3", 3.5, "er!"}],
      # 98  (rest)
      [rest: 4]
    ]
  end
end
