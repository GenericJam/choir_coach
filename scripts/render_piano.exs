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

Code.require_file("midi.exs", __DIR__)

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

notes = ScriptMidi.held_notes(song)
wav_path = Path.join(System.tmp_dir!(), "#{mod}-piano.wav")
ScriptMidi.render(notes, 0, shift, soundfont, wav_path)

# Match the piano's level to where the part rehearsal tracks put the voices
# it stands in for: 3 dB under the band (the rehearsal track's other
# channel). A split track's choir can sit far lower (The Joy's, 12 dB under),
# so the band is the reference. A limiter (no auto make-up gain) keeps the
# boosted attacks from clipping.
band_pan = if module.tracks(part).rehearsal.voice == :right, do: "c0=c0", else: "c0=c1"

gain_db =
  ScriptMidi.mean_db(rehearsal_path, band_pan) - 3 -
    ScriptMidi.mean_db(wav_path, "c0=0.5*c0+0.5*c1")

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

File.rm(wav_path)

IO.puts(
  "#{song.title}: #{length(notes)} piano notes (#{length(song.notes) - length(notes)} tied) " <>
    "-> #{out}, piano #{Float.round(gain_db, 1)} dB"
)
