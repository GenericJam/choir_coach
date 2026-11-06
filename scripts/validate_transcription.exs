# Validates a voice-part transcription file before it goes into a song module.
#
#   MIX_ENV=test mix run --no-start scripts/validate_transcription.exs <file.exs> [beats_per_bar]
#
# The file must evaluate to {first_bar, bars} or {first_bar, bars, overrides},
# where bars are lists in ChoirCoach.Song.build/1 notation and overrides maps
# a bar number to its beat count when it differs from beats_per_bar (default
# 4): a pickup, a time-signature change. Checks every bar's beats add up and
# every note name parses; prints the bar range, note count and pitch range.

[path | rest] = System.argv()
default_beats = case rest do [b | _] -> String.to_integer(b); _ -> 4 end

{first, bars, overrides} =
  case Code.eval_file(path) |> elem(0) do
    {first, bars} -> {first, bars, %{}}
    {first, bars, overrides} -> {first, bars, overrides}
  end

errors =
  bars
  |> Enum.with_index(first)
  |> Enum.flat_map(fn {events, number} ->
    expected = Map.get(overrides, number, default_beats)

    total =
      Enum.reduce(events, 0, fn
        {:rest, b}, acc -> acc + b
        {:n, {_name, b, _lyric}}, acc -> acc + b
      end)

    names =
      for {:n, {name, _b, _l}} <- events,
          not Regex.match?(~r/^[A-G](#|b)?[0-6]$/, name),
          do: "bar #{number}: bad note name #{inspect(name)}"

    sums = if abs(total - expected) > 1.0e-6, do: ["bar #{number}: #{total} beats, expected #{expected}"], else: []
    sums ++ names
  end)

notes = for bar <- bars, {:n, {name, _, _}} <- bar, do: ChoirCoach.Pitch.parse(name)
range = if notes == [], do: "no notes", else: "#{ChoirCoach.Pitch.name(Enum.min(notes))}–#{ChoirCoach.Pitch.name(Enum.max(notes))}"

IO.puts("bars #{first}–#{first + length(bars) - 1}: #{length(bars)} bars, #{length(notes)} notes, range #{range}")

case errors do
  [] -> IO.puts("OK")
  errors -> Enum.each(errors, &IO.puts/1) && System.halt(1)
end
