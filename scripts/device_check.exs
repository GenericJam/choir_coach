# Plays a stretch of the song on a connected device and reports what the
# practice screen showed.
#
#   mix mob.connect --no-iex --android-only --device <serial>
#   NODE=choir_coach_android_<serial>@127.0.0.1 SOURCE=playback FROM_BAR=20 SECS=10 \
#     mix run --no-start scripts/device_check.exs
#
# SOURCE=playback analyses the track itself (checks decoding, playback, the
# clock and detection without a singer); SOURCE=mic listens to the
# microphone (with the phone's speaker playing, it hears the track through
# the air, which checks the input path and the latency mapping).

alias ChoirCoach.{Pitch, Song}

node = String.to_atom(System.fetch_env!("NODE"))
{:ok, _} = Node.start(:"check_#{System.unique_integer([:positive])}@127.0.0.1")
Node.set_cookie(MobDev.DistCookie.for_project!())
true = Node.connect(node)

source = String.to_atom(System.get_env("SOURCE", "playback"))
from_bar = String.to_integer(System.get_env("FROM_BAR", "20"))
seconds = String.to_integer(System.get_env("SECS", "10"))

IO.inspect(:rpc.call(node, ChoirCoach.Audio.Nif, :info, []), label: "engine")

a = Mob.Test.assigns(node)
IO.puts("audio=#{inspect(a.audio_status)} mic=#{inspect(a.mic)} listening=#{inspect(a.listening)} track=#{a.track_mode}")

if a.playing, do: Mob.Test.tap(node, :play_pause)
Mob.Test.send_message(node, {:listen, source})
song = a.song
Mob.Test.send_message(node, {:seek, Song.bar_start(song, from_bar) - 1_000})
Process.sleep(300)
Mob.Test.tap(node, :play_pause)

# Sample the screen every 200 ms; the trace only spans the visible past, so
# merge each sample's trace to get every reading of the run.
{samples, all} =
  Enum.map_reduce(1..(seconds * 5), %{}, fn _, acc ->
    Process.sleep(200)
    s = Mob.Test.assigns(node)
    acc = Enum.reduce(s.trace, acc, fn {ts, _m, _c} = r, acc -> Map.put(acc, ts, r) end)
    {{s.t_ms, s.feedback.status, s.feedback.cents, length(s.trace)}, acc}
  end)

readings = all |> Map.values() |> Enum.sort()
Mob.Test.tap(node, :play_pause)

IO.puts("\nt_ms     status               cents  trace")

for {t, status, cents, n} <- samples do
  note = Song.note_at(song, t)
  label = if note, do: "#{note.lyric} #{Pitch.name(note.midi)}", else: "—"

  IO.puts(
    "#{String.pad_leading("#{round(t)}", 7)}  #{String.pad_trailing(inspect(status), 20)} #{String.pad_leading(if(cents, do: "#{round(cents)}", else: "·"), 5)}  #{String.pad_leading("#{n}", 4)}  #{label}"
  )
end

# How well the trace matches the written notes (octave-tolerant), and the
# lag that fits it best: readings stamped too early or late show up here.
match = fn shift ->
  voiced =
    for {ts, midi, _c} <- readings, is_number(midi), note = Song.note_at(song, ts + shift), note != nil do
      d = Pitch.cents(midi, note.midi)
      abs(d - 1200 * round(d / 1200)) <= 50
    end

  if voiced == [], do: 0.0, else: Enum.count(voiced, & &1) / length(voiced)
end

{best_shift, best} = Enum.max_by(for(s <- -300..300//10, do: {s, match.(s)}), &elem(&1, 1))
IO.puts("\nreadings: #{length(readings)}; match at 0 ms: #{round(match.(0) * 100)}%, best #{round(best * 100)}% at #{best_shift} ms")
IO.inspect(:rpc.call(node, ChoirCoach.Audio.Nif, :info, []), label: "engine after")
