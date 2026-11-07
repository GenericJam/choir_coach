# Writes the songs as JSON for the web app (choir_web), one file per song:
#
#   elixir scripts/export_web.exs ../choir_web/priv/songs
#
# Plain `elixir`, no Mix project: it loads only the pure song modules
# (Pitch, Song, Roles, the songs and Songs), so it needs neither mob nor a
# build. Each file has the song's facts (as the song list shows them, from
# the bass part) and every part as the practice screen gets it from
# `Songs.parts/2`: the voice parts with their phrases marked against the
# melody (`Roles`), the melody unmarked, each with its tracks. Audio is not
# exported (the web app reads the recordings from priv/audio itself).

root = Path.expand("..", __DIR__)

for file <-
      ~w(pitch song roles)
      |> Enum.map(&Path.join(root, "lib/choir_coach/#{&1}.ex"))
      |> Kernel.++(Path.wildcard(Path.join(root, "lib/choir_coach/songs/*.ex")))
      |> Kernel.++([Path.join(root, "lib/choir_coach/songs.ex")]) do
  Code.require_file(file)
end

alias ChoirCoach.{Song, Songs}

out =
  case System.argv() do
    [dir] -> dir
    _ -> raise "usage: elixir scripts/export_web.exs <output dir>"
  end

File.mkdir_p!(out)

song_json = fn song ->
  song
  |> Map.from_struct()
  |> Map.update!(:notes, fn notes -> Enum.map(notes, &Map.from_struct/1) end)
end

slug = fn module ->
  module.tracks(:bass).rehearsal.file |> Path.dirname()
end

for module <- Songs.all() do
  bass = module.bass()
  voice_parts = Enum.reject(module.parts(), &(&1 == :melody))

  parts =
    Map.new(module.parts(), fn part ->
      {^part, %{song: song, tracks: tracks}} = Songs.parts(module, part) |> hd()
      {part, %{song: song_json.(song), tracks: tracks}}
    end)

  doc = %{
    slug: slug.(module),
    title: bass.title,
    key_name: Song.key_name(bass),
    tempo_bpm: bass.tempo_bpm,
    bar_count: length(bass.bars),
    first_bar: hd(bass.bars).number,
    last_bar: List.last(bass.bars).number,
    start_ms: Song.start_ms(bass),
    duration_ms: Song.duration_ms(bass),
    voice_parts: voice_parts,
    parts: parts
  }

  path = Path.join(out, "#{doc.slug}.json")
  File.write!(path, JSON.encode!(doc))
  IO.puts("#{path}: #{Enum.join(module.parts(), ", ")}")
end

index = for module <- Songs.all(), do: slug.(module)
File.write!(Path.join(out, "index.json"), JSON.encode!(index))
