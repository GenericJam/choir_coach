defmodule ChoirCoach.Songs do
  @moduledoc """
  The songs in the app, in concert order. Each is a module with one function
  per part (`soprano/0`, `alto/0`, `tenor/0`, `bass/0`, `melody/0`, each a
  `ChoirCoach.Song` on the same bar timeline), `parts/0` (their names) and
  `tracks/1` (each part's recordings). The practice screen offers the
  singer's own part and the melody (`parts/2`).
  """

  alias ChoirCoach.Songs.{GloriousNight, GraceOfGod, HolyForever, ThisIsJesus}

  @modules [GloriousNight, HolyForever, GraceOfGod, ThisIsJesus]

  @doc "Every song's module, in list order."
  @spec all() :: [module()]
  def all, do: @modules

  @doc """
  The parts a singer practises in a song: their own `part` and the melody,
  each with its song and tracks (the song's first part if it lacks `part`).
  The part has each phrase marked as following the melody or not
  (`ChoirCoach.Roles`).
  """
  @spec parts(module(), atom()) :: keyword(%{song: ChoirCoach.Song.t(), tracks: map()})
  def parts(module, part) do
    available = module.parts()
    mine = if part in available, do: part, else: hd(available)
    melody = if :melody in available, do: module.melody()

    for p <- Enum.uniq([mine | if(melody, do: [:melody], else: [])]) do
      song = apply(module, p, [])
      song = if melody && p != :melody, do: ChoirCoach.Roles.mark(song, melody), else: song
      {p, %{song: song, tracks: module.tracks(p)}}
    end
  end
end
