# Shared by the rendering scripts (render_piano.exs, render_score.exs):
# a song's notes as MIDI, rendered to WAV with fluidsynth.

defmodule ScriptMidi do
  @moduledoc false

  @doc """
  A song's notes as `{midi, start_ms, stop_ms}`. A slurred note at the same
  pitch, starting where the last one ends, is a tie: held on rather than
  struck again.
  """
  def held_notes(song) do
    song.notes
    |> Enum.reduce([], fn note, acc ->
      case acc do
        [{midi, start, stop} | rest]
        when note.slur and note.midi == midi and abs(note.start_ms - stop) < 1 ->
          [{midi, start, note.start_ms + note.dur_ms} | rest]

        _ ->
          [{note.midi, note.start_ms, note.start_ms + note.dur_ms} | acc]
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Renders `notes` (`{midi, start_ms, stop_ms}`, shifted by `shift_ms`) on
  General MIDI `program` (0 Acoustic Grand Piano, 52 Choir Aahs) to a
  44.1 kHz stereo WAV at `wav_path`.
  """
  def render(notes, program, shift_ms, soundfont, wav_path) do
    # Standard MIDI file, format 0: 500 ticks a quarter at 500 000 µs a
    # quarter, so one tick is one millisecond. At the same tick a note ends
    # before the next one starts.
    events =
      notes
      |> Enum.flat_map(fn {midi, start, stop} ->
        [
          {round(start + shift_ms), 1, <<0x90, midi, 88>>},
          {round(stop + shift_ms), 0, <<0x80, midi, 0>>}
        ]
      end)
      |> Enum.sort()

    {body, _} = Enum.map_reduce(events, 0, fn {t, _, msg}, last -> {[vlq(t - last), msg], t} end)

    track =
      IO.iodata_to_binary([
        <<0, 0xFF, 0x51, 3, 500_000::24>>,
        <<0, 0xC0, program>>,
        body,
        <<0, 0xFF, 0x2F, 0>>
      ])

    midi_path = Path.rootname(wav_path) <> ".mid"

    File.write!(midi_path, [
      <<"MThd", 6::32, 0::16, 1::16, 500::16>>,
      <<"MTrk", byte_size(track)::32>>,
      track
    ])

    {_, 0} =
      System.cmd(
        "fluidsynth",
        ["-ni", "-q", "-g", "0.6", "-r", "44100", "-F", wav_path, soundfont, midi_path],
        stderr_to_stdout: true
      )

    File.rm(midi_path)
    wav_path
  end

  @doc "A file's mean volume in dB, through an ffmpeg `pan` to mono (e.g. `c0=c1`)."
  def mean_db(input, pan) do
    {log, 0} =
      System.cmd(
        "ffmpeg",
        ["-v", "info", "-i", input, "-af", "pan=mono|#{pan},volumedetect", "-f", "null", "-"],
        stderr_to_stdout: true
      )

    [_, db] = Regex.run(~r/mean_volume: (-?[\d.]+) dB/, log)
    String.to_float(db)
  end

  defp vlq(n) do
    bytes =
      Stream.unfold(n, fn
        0 -> nil
        v -> {Bitwise.band(v, 0x7F), Bitwise.bsr(v, 7)}
      end)
      |> Enum.to_list()

    [low | high] = if bytes == [], do: [0], else: bytes

    high
    |> Enum.reverse()
    |> Enum.map(&Bitwise.bor(&1, 0x80))
    |> Kernel.++([low])
    |> :binary.list_to_bin()
  end
end
