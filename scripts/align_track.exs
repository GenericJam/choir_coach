# Lines a transcribed part up with a recording, and checks the transcription
# against what is sung on it.
#
#   cc -O2 -o /tmp/pitch_host c_src/test/pitch_host.c -lm
#   [PART=melody] MIX_ENV=test mix run --no-start scripts/align_track.exs HolyForever [rehearsal] [left|right]
#
# Runs the app's YIN detector over one channel of the track (default: the
# track's voice channel), then:
#
#   1. fits where bar 1 starts and the tempo, by how many confident readings
#      land on the written pitch (octave slips folded) of the note sounding;
#   2. per bar with notes, the local shift that fits best: steady near zero
#      means the tempo holds; a drift marks a ritardando or a fermata, which
#      the song gives as `bar_ms` (or a `tempo` change);
#   3. per note, the median pitch heard against the written one: a note off
#      by a semitone or more is a transcription to recheck (or another voice
#      on the channel; the rehearsal channels carry them all, louder or softer).
#
# Uses the song's current timing for steps 2 and 3 when `ALIGN_FIT=0`, so the
# fitted `bar_ms` can be checked after it's written in.

alias ChoirCoach.{Pitch, Song}

[mod | rest] = System.argv()
module = Module.concat(ChoirCoach.Songs, mod)
part = String.to_atom(System.get_env("PART", "bass"))
track_key = rest |> Enum.at(0, "rehearsal") |> String.to_atom()
song = apply(module, part, [])
track = Map.fetch!(module.tracks(part), track_key)
channel = Enum.at(rest, 1) || Atom.to_string(track.voice)
path = ChoirCoach.Audio.track_path(track.file) |> Path.expand()
path = if File.exists?(path), do: path, else: Path.join("priv/audio", track.file)

pan = %{"left" => "c0=c0", "right" => "c0=c1", "mixed" => "c0=0.5*c0+0.5*c1"}[channel]
cache = "/tmp/align-#{Path.basename(Path.dirname(path))}-#{Path.basename(path, ".mp3")}-#{channel}.csv"

unless File.exists?(cache) do
  {_, 0} =
    System.cmd("sh", [
      "-c",
      "ffmpeg -v error -i '#{path}' -af 'pan=mono|#{pan}' -ar 48000 -f f32le - | /tmp/pitch_host 48000 > '#{cache}'"
    ])
end

readings =
  cache
  |> File.stream!()
  |> Stream.drop(1)
  |> Stream.map(fn line ->
    [t, hz, conf, db] = line |> String.trim() |> String.split(",") |> Enum.map(&String.to_float/1)
    {t, hz, conf, db}
  end)
  |> Enum.filter(fn {_t, hz, conf, db} -> hz > 0 and conf >= 0.5 and db >= -45 end)
  |> Enum.map(fn {t, hz, _c, _db} -> {t, Pitch.midi(hz)} end)

# Notes in score beats from bar 1, whatever the song's own timing.
{beat_of_bar, _} =
  Enum.map_reduce(song.bars, 0.0, fn bar, acc -> {{bar.number, acc}, acc + bar.beats} end)

beat_of_bar = Map.new(beat_of_bar)
bar_by_number = Map.new(song.bars, &{&1.number, &1})

notes =
  for n <- song.notes do
    bar = bar_by_number[n.bar]
    b0 = beat_of_bar[n.bar] + (n.start_ms - bar.start_ms) / bar.dur_ms * bar.beats
    {b0, b0 + n.beats, n}
  end

starts = notes |> Enum.map(&elem(&1, 0)) |> List.to_tuple()
note_tuple = List.to_tuple(notes)

find = fn beat ->
  # Last note starting at or before `beat`, if it is still sounding.
  {lo, hi} = {0, tuple_size(starts) - 1}

  idx =
    Stream.unfold({lo, hi, -1}, fn
      {lo, hi, best} when lo > hi -> {best, :done}
      :done -> nil
      {lo, hi, best} ->
        mid = div(lo + hi, 2)
        if elem(starts, mid) <= beat, do: {nil, {mid + 1, hi, mid}}, else: {nil, {lo, mid - 1, best}}
    end)
    |> Enum.reject(&is_nil/1)
    |> List.first()

  with i when i >= 0 <- idx, {_b0, b1, n} when beat < b1 <- elem(note_tuple, i), do: n, else: (_ -> nil)
end

folded = fn midi, written -> d = midi - written; d - 12 * round(d / 12) end

hits = fn sample, start, bpm ->
  Enum.count(sample, fn {t, midi} ->
    case find.((t - start) * bpm / 60_000) do
      nil -> false
      n -> abs(folded.(midi, n.midi)) < 0.5
    end
  end)
end

{start, bpm} =
  if System.get_env("ALIGN_FIT") == "0" do
    {Song.start_ms(song), song.tempo_bpm}
  else
    coarse = Enum.take_every(readings, 4)
    marked = song.tempo_bpm

    {_, s0, b0} =
      for bpm <- Enum.map(-6..6, &(marked + &1 * 0.5)), s <- Enum.map(-40..1200, &(&1 * 25.0)),
          reduce: {-1, 0, 0} do
        {best, _, _} = acc ->
          h = hits.(coarse, s, bpm)
          if h > best, do: {h, s, bpm}, else: acc
      end

    fine = Enum.take_every(readings, 2)

    {_, s1, b1} =
      for bpm <- Enum.map(-25..25, &(b0 + &1 * 0.02)), s <- Enum.map(-30..30, &(s0 + &1 * 5.0)),
          reduce: {-1, 0, 0} do
        {best, _, _} = acc ->
          h = hits.(fine, s, bpm)
          if h > best, do: {h, s, bpm}, else: acc
      end

    {s1, b1}
  end

IO.puts("#{song.title} · #{track_key} (#{channel}) · bar 1 at #{Float.round(start * 1.0, 1)} ms · ♩ = #{Float.round(bpm * 1.0, 2)}")
IO.puts("  #{hits.(readings, start, bpm)} of #{length(readings)} confident readings on the written pitch")

# Timing as bar lengths: the song's own (ALIGN_FIT=0) or the fitted tempo,
# then ALIGN_BARS (e.g. "53,69,74,75": the rit. and fermata bars) fitted one
# by one, each to the length that puts it and the six bars after it back on
# the singing (the last bar: the shortest that still covers the sung end).
own_timing = System.get_env("ALIGN_FIT") == "0"
start0 = if own_timing, do: Song.start_ms(song), else: start

durs =
  Map.new(song.bars, fn b ->
    {b.number, if(own_timing, do: b.dur_ms, else: b.beats * 60_000 / bpm)}
  end)

rows_of = fn durs ->
  {rows, _} =
    Enum.map_reduce(song.bars, start0, fn b, t ->
      {{b.number, t, durs[b.number], beat_of_bar[b.number], b.beats}, t + durs[b.number]}
    end)

  rows
end

time_in = fn rows, beat ->
  {_n, t, d, b0, beats} =
    Enum.find(rows, List.last(rows), fn {_n, _t, _d, b0, beats} -> beat < b0 + beats end)

  t + (beat - b0) / beats * d
end

last_bar = List.last(song.bars).number

score_bars = fn durs, numbers ->
  rows = rows_of.(durs)

  for {b0, b1, n} <- notes, n.bar in numbers, reduce: 0 do
    acc ->
      t0 = time_in.(rows, b0)
      t1 = time_in.(rows, b1)
      acc + Enum.count(readings, fn {t, midi} -> t >= t0 and t < t1 and abs(folded.(midi, n.midi)) < 0.5 end)
  end
end

fit_bars =
  case System.get_env("ALIGN_BARS") do
    nil -> []
    list -> list |> String.split(",", trim: true) |> Enum.map(&String.to_integer/1)
  end

durs =
  Enum.reduce(fit_bars, durs, fn number, durs ->
    nominal = durs[number]
    window = Enum.to_list(number..min(number + 6, last_bar))

    scored =
      for d <- Enum.map(0..200, &(nominal * 0.8 + &1 * 20.0)), d <= nominal * 4 do
        {d, score_bars.(Map.put(durs, number, d), window)}
      end

    {_, best} = Enum.max_by(scored, &elem(&1, 1))

    {d, _} =
      if number == last_bar,
        do: Enum.find(scored, fn {_, s} -> s >= 0.98 * best end),
        else: Enum.max_by(scored, &elem(&1, 1))

    Map.put(durs, number, Float.round(d, 0))
  end)

if fit_bars != [] do
  IO.puts("  fitted bar_ms: %{#{Enum.map_join(fit_bars, ", ", &"#{&1} => #{durs[&1]}")}}")
end

rows = rows_of.(durs)
time_of = fn beat -> time_in.(rows, beat) end

IO.puts("\nPer bar (bars with notes): best local shift (ms), hit rate at shift 0 → at best shift")

for bar <- song.bars, bar_notes = Enum.filter(notes, fn {_, _, n} -> n.bar == bar.number end), bar_notes != [] do
  window = fn shift ->
    for {b0, b1, n} <- bar_notes,
        t0 = time_of.(b0) + shift,
        t1 = time_of.(b1) + shift,
        {t, midi} <- readings,
        t >= t0 and t < t1,
        do: abs(folded.(midi, n.midi)) < 0.5
  end

  rate = fn shift ->
    w = window.(shift)
    if w == [], do: 0.0, else: Enum.count(w, & &1) / length(w)
  end

  {best_shift, best} = Enum.map(-30..30, &{&1 * 20, rate.(&1 * 20)}) |> Enum.max_by(&elem(&1, 1))
  r0 = rate.(0)
  mark = if abs(best_shift) >= 80 and best - r0 > 0.15, do: "  ◀ drift", else: ""

  IO.puts(
    "  bar #{String.pad_leading("#{bar.number}", 3)}  shift #{String.pad_leading("#{best_shift}", 5)}  #{round(r0 * 100)}% → #{round(best * 100)}%#{mark}"
  )
end

IO.puts("\nNotes heard off the written pitch (median of readings in the note's middle 60%):")

for {b0, b1, n} <- notes do
  t0 = time_of.(b0)
  t1 = time_of.(b1)
  {a, b} = {t0 + 0.2 * (t1 - t0), t1 - 0.2 * (t1 - t0)}
  heard = for {t, midi} <- readings, t >= a and t <= b, do: folded.(midi, n.midi)

  if length(heard) >= 4 do
    median = heard |> Enum.sort() |> Enum.at(div(length(heard), 2))
    on = Enum.count(heard, &(abs(&1) < 0.5)) / length(heard)

    if abs(median) >= 0.5 do
      IO.puts(
        "  bar #{n.bar} #{String.pad_trailing(inspect(n.lyric), 12)} written #{n.name}, heard #{Pitch.name(round(n.midi + median))} (#{Float.round(median, 1)} st, #{round(on * 100)}% on)"
      )
    end
  end
end
