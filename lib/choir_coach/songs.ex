defmodule ChoirCoach.Songs do
  @moduledoc """
  The songs in the app, in concert order. Each is a module with one function
  per part (`bass/0`, `melody/0`, each a `ChoirCoach.Song` on the same bar
  timeline), `parts/0` (their names, in the order the practice screen offers
  them) and `tracks/1` (each part's recordings).
  """

  alias ChoirCoach.Songs.{GloriousNight, GraceOfGod, HolyForever, ThisIsJesus}

  @modules [GloriousNight, HolyForever, GraceOfGod, ThisIsJesus]

  @doc "Every song's module, in list order."
  @spec all() :: [module()]
  def all, do: @modules

  @doc """
  A song's parts, in order: each part's name with its song and tracks. Parts
  other than the melody have each phrase marked as following the melody or
  not (`ChoirCoach.Roles`).
  """
  @spec parts(module()) :: keyword(%{song: ChoirCoach.Song.t(), tracks: map()})
  def parts(module) do
    melody = if :melody in module.parts(), do: module.melody()

    for part <- module.parts() do
      song = apply(module, part, [])
      song = if melody && part != :melody, do: ChoirCoach.Roles.mark(song, melody), else: song
      {part, %{song: song, tracks: module.tracks(part)}}
    end
  end
end
