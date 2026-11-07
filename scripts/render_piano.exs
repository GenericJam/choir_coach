# Renders a song's part as piano notes, the way a rehearsal pianist plays a
# part: every note struck, tied notes held as one.
#
#   brew install fluid-synth
#   SOUNDFONT=~/.local/share/soundfonts/GeneralUser-GS.sf2 \
#     MIX_ENV=test mix run --no-start scripts/render_piano.exs HolyForever [bass|melody]
#
# Writes priv/audio/<song>/piano_<part>.mp3 on the part's rehearsal track's
# timeline and length: the piano alone, mono (the engine takes it as one
# lane, which the mixer's gains send to either ear), 64 kbps. The
# accompaniment comes from the rehearsal track itself. Gitignored like the
# recordings.

alias ChoirCoach.Song

[mod | rest] = System.argv()
part = rest |> Enum.at(0, "bass") |> String.to_atom()
module = Module.concat(ChoirCoach.Songs, mod)
song = apply(module, part, [])
%{file: rehearsal, bar1_ms: bar1} = module.tracks(part).rehearsal
soundfont = System.get_env("SOUNDFONT") || raise "set SOUNDFONT to a .sf2 file"
rehearsal_path = Path.join("priv/audio", rehearsal)
out = Path.join(Path.dirname(rehearsal_path), "piano_#{part}.mp3")
# Song times are the rehearsal track's once bar 1 lines up.
shift = bar1 - Song.start_ms(song)

# A slurred note at the same pitch, starting where the last one ends, is a
# tie: hold the note on rather than strike it again.
notes =
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

# Standard MIDI file, format 0: 500 ticks a quarter at 500 000 µs a quarter,
# so one tick is one millisecond.
vlq = fn n ->
  bytes = Stream.unfold(n, fn 0 -> nil; v -> {Bitwise.band(v, 0x7F), Bitwise.bsr(v, 7)} end) |> Enum.to_list()
  [low | high] = if bytes == [], do: [0], else: bytes
  high |> Enum.reverse() |> Enum.map(&Bitwise.bor(&1, 0x80)) |> Kernel.++([low]) |> :binary.list_to_bin()
end

# At the same tick a note ends before the next one starts.
events =
  notes
  |> Enum.flat_map(fn {midi, start, stop} ->
    [{round(start + shift), 1, <<0x90, midi, 88>>}, {round(stop + shift), 0, <<0x80, midi, 0>>}]
  end)
  |> Enum.sort()

{body, _} =
  Enum.map_reduce(events, 0, fn {t, _, msg}, last -> {[vlq.(t - last), msg], t} end)

track =
  IO.iodata_to_binary([
    <<0, 0xFF, 0x51, 3, 500_000::24>>,
    # Acoustic Grand Piano
    <<0, 0xC0, 0>>,
    body,
    <<0, 0xFF, 0x2F, 0>>
  ])

midi_path = Path.join(System.tmp_dir!(), "#{mod}-piano.mid")
wav_path = Path.join(System.tmp_dir!(), "#{mod}-piano.wav")
File.write!(midi_path, [<<"MThd", 6::32, 0::16, 1::16, 500::16>>, <<"MTrk", byte_size(track)::32>>, track])

{_, 0} =
  System.cmd("fluidsynth", ["-ni", "-q", "-g", "0.6", "-r", "44100", "-F", wav_path, soundfont, midi_path],
    stderr_to_stdout: true
  )

# Match the piano's level to the voices it stands in for (the rehearsal
# track's voice channel), so the levels sit where the other tracks put them;
# a limiter (no auto make-up gain) keeps the boosted attacks from clipping.
mean_db = fn input, pan ->
  {log, 0} =
    System.cmd("ffmpeg", ["-v", "info", "-i", input, "-af", "pan=mono|#{pan},volumedetect", "-f", "null", "-"],
      stderr_to_stdout: true
    )

  [_, db] = Regex.run(~r/mean_volume: (-?[\d.]+) dB/, log)
  String.to_float(db)
end

gain_db = mean_db.(rehearsal_path, "c0=c0") - mean_db.(wav_path, "c0=0.5*c0+0.5*c1")

duration_s =
  case System.cmd("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", rehearsal_path]) do
    {s, 0} -> s |> String.trim() |> String.to_float()
  end

{_, 0} =
  System.cmd(
    "ffmpeg",
    [
      "-v", "error", "-y", "-i", wav_path,
      "-af",
      "pan=mono|c0=0.5*c0+0.5*c1,volume=#{gain_db}dB," <>
        "alimiter=limit=0.89:attack=5:release=50:level=0,apad=whole_dur=#{duration_s}",
      "-t", "#{duration_s}", "-ar", "44100", "-ac", "1", "-c:a", "libmp3lame", "-b:a", "64k", out
    ],
    stderr_to_stdout: true
  )

File.rm(midi_path)
File.rm(wav_path)

IO.puts(
  "#{song.title}: #{length(notes)} piano notes (#{length(song.notes) - length(notes)} tied) " <>
    "-> #{out}, piano #{Float.round(gain_db, 1)} dB"
)
