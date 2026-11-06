defmodule ChoirCoach.SongsScreenTest do
  use Mob.ScreenCase, async: true

  alias ChoirCoach.{PracticeScreen, Songs, SongsScreen}
  alias ChoirCoach.Songs.ThisIsJesus

  test "every part builds on the song's one bar timeline and names files the app ships" do
    for module <- Songs.all() do
      bars = Enum.map(module.bass().bars, &{&1.number, &1.start_ms, &1.dur_ms})

      for {part, %{song: song, tracks: tracks}} <- Songs.parts(module) do
        assert Enum.map(song.bars, &{&1.number, &1.start_ms, &1.dur_ms}) == bars

        # Each part's rehearsal track, the shared choir and demo; a piano only for the bass.
        assert Enum.all?(Map.values(tracks), &String.ends_with?(&1.file, ".mp3"))
        assert Map.has_key?(tracks, :rehearsal) and Map.has_key?(tracks, :split)
        assert Map.has_key?(tracks, :piano) == (part == :bass)
      end
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
