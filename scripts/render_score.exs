# Renders the recordings of a song that has none, from its transcription:
# the score's piano accompaniment (`accompaniment/0`) on piano, and the
# voices: a singer's recording when there is one, else the four voice parts
# on General MIDI Choir Aahs.
#
#   brew install fluid-synth
#   SOUNDFONT=~/.local/share/soundfonts/GeneralUser-GS.sf2 \
#     MIX_ENV=test mix run --no-start scripts/render_score.exs OComeAllYeFaithful \
#     [audio_src/o_come_all_ye_faithful/vocal.wav 43790]
#
# A recording comes with where it starts on the song's timeline (ms: song
# time = recording time + offset), as fitted against the melody; it is
# high-passed at 70 Hz and placed there.
#
# Writes priv/audio/<song>/split.mp3 (the piano left, the voices right, as a
# split track has them) and demo.mp3 (both in both ears), 128 kbps stereo,
# on the song's own timeline (bar 1 at `start_ms`), until 3 s after the last
# note. Gitignored like the recordings. Then render each part's piano with
# render_piano.exs, which takes its timeline and level from split.mp3.

Code.require_file("midi.exs", __DIR__)

[mod | sung] = System.argv()
module = Module.concat(ChoirCoach.Songs, mod)
soundfont = System.get_env("SOUNDFONT") || raise "set SOUNDFONT to a .sf2 file"
out_dir = Path.join("priv/audio", Path.dirname(module.tracks(:bass).split.file))
File.mkdir_p!(out_dir)

piano = Enum.flat_map(module.accompaniment(), &ScriptMidi.held_notes/1)
voices = Enum.flat_map([:soprano, :alto, :tenor, :bass], &ScriptMidi.held_notes(apply(module, &1, [])))
end_s = (Enum.map(piano ++ voices, &elem(&1, 2)) |> Enum.max()) / 1000 + 3

tmp = fn name -> Path.join(System.tmp_dir!(), "#{mod}-#{name}.wav") end
piano_wav = ScriptMidi.render(piano, 0, 0, soundfont, tmp.("piano"))

voices_wav =
  case sung do
    [] ->
      ScriptMidi.render(voices, 52, 0, soundfont, tmp.("voices"))

    [path, offset_ms] ->
      {_, 0} =
        System.cmd(
          "ffmpeg",
          ["-v", "error", "-y", "-i", path, "-af", "highpass=f=70,adelay=#{offset_ms}:all=1",
           "-ar", "44100", tmp.("voices")],
          stderr_to_stdout: true
        )

      tmp.("voices")
  end

# Both stems to the same level while they sound (silence left out, so a
# recording that starts part way isn't boosted), so neither ear of the split
# drowns the other; the demo mixes them at that level.
target_db = -20.0
gain = fn wav -> target_db - ScriptMidi.mean_db(wav, "c0=0.5*c0+0.5*c1", "silenceremove=stop_periods=-1:stop_threshold=-45dB") end
{gp, gv} = {gain.(piano_wav), gain.(voices_wav)}

encode = fn filter, out ->
  {_, 0} =
    System.cmd(
      "ffmpeg",
      [
        "-v", "error", "-y", "-i", piano_wav, "-i", voices_wav,
        "-filter_complex",
        "[0:a]pan=mono|c0=0.5*c0+0.5*c1,volume=#{gp}dB,apad=whole_dur=#{end_s}[p];" <>
          "[1:a]pan=mono|c0=0.5*c0+0.5*c1,volume=#{gv}dB,apad=whole_dur=#{end_s}[v];" <>
          filter <> ",alimiter=limit=0.89:attack=5:release=50:level=0[out]",
        "-map", "[out]", "-t", "#{end_s}", "-ar", "44100", "-ac", "2",
        "-c:a", "libmp3lame", "-b:a", "128k", Path.join(out_dir, out)
      ],
      stderr_to_stdout: true
    )
end

encode.("[p][v]join=inputs=2:channel_layout=stereo:map=0.0-FL|1.0-FR", "split.mp3")
encode.("[p][v]amix=inputs=2:normalize=0,pan=stereo|c0=c0|c1=c0", "demo.mp3")

Enum.each([piano_wav, voices_wav], &File.rm/1)

voice_source = if sung == [], do: "#{length(voices)} synthesized voice notes", else: "the voices from #{hd(sung)}"

IO.puts(
  "#{module.bass().title}: #{length(piano)} piano notes, #{voice_source}, " <>
    "#{Float.round(end_s, 1)} s -> #{out_dir}/split.mp3, demo.mp3 " <>
    "(piano #{Float.round(gp, 1)} dB, voices #{Float.round(gv, 1)} dB)"
)
