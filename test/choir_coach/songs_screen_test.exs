defmodule ChoirCoach.SongsScreenTest do
  use Mob.ScreenCase, async: true

  alias ChoirCoach.{PracticeScreen, Song, Songs, SongsScreen}
  alias ChoirCoach.Songs.ThisIsJesus

  test "every song builds and its tracks name the files the app ships" do
    for module <- Songs.all() do
      song = module.bass()
      assert Song.duration_ms(song) > Song.start_ms(song)
      assert %{rehearsal: %{file: file}} = module.tracks()
      assert String.ends_with?(file, ".mp3")
    end
  end

  test "lists the songs, and tapping one opens it to practise" do
    view = mount_screen(SongsScreen, %{})
    assert Enum.map(assigns(view).songs, & &1.module) == Songs.all()
    assert_renderable(view)

    opened = render_info(view, {:tap, {:open, ThisIsJesus}})
    assert navigated_to(opened) == PracticeScreen
  end

  test "the card says the key, tempo and length" do
    assert SongsScreen.facts(ThisIsJesus.bass()) =~ ~r/^B♭ major · ♩ = 77 · 81 bars · \d:\d\d$/
  end
end
