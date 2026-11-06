defmodule ChoirCoach.Songs do
  @moduledoc """
  The songs in the app, in concert order. Each is a module with `bass/0`
  (the part as a `ChoirCoach.Song`) and `tracks/0` (its recordings).
  """

  alias ChoirCoach.Songs.{GloriousNight, GraceOfGod, HolyForever, ThisIsJesus}

  @modules [GloriousNight, HolyForever, GraceOfGod, ThisIsJesus]

  @doc "Every song's module, in list order."
  @spec all() :: [module()]
  def all, do: @modules
end
