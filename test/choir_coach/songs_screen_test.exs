defmodule ChoirCoach.SongsScreenTest do
  use Mob.ScreenCase, async: false

  alias ChoirCoach.{PracticeScreen, Settings, Songs, SongsScreen}
  alias ChoirCoach.Songs.ThisIsJesus

  setup do
    Mob.State.delete(:my_part)
    :ok
  end

  test "every voice part builds on the song's one bar timeline, with its piano and recordings" do
    for module <- Songs.all(), mine <- Settings.voice_parts() do
      bars = Enum.map(module.bass().bars, &{&1.number, &1.start_ms, &1.dur_ms})
      parts = Songs.parts(module, mine)
      assert Keyword.keys(parts) == [mine, :melody]

      for {part, %{song: song, tracks: tracks}} <- parts do
        assert Enum.map(song.bars, &{&1.number, &1.start_ms, &1.dur_ms}) == bars
        assert song.part == part

        # Each part's rehearsal track, the shared choir and demo; a piano for every voice part.
        assert Enum.all?(Map.values(tracks), &String.ends_with?(&1.file, ".mp3"))
        assert Map.has_key?(tracks, :rehearsal) and Map.has_key?(tracks, :split)
        assert Map.has_key?(tracks, :piano) == (part != :melody)
      end
    end
  end

  test "the singer's part is remembered and a song opens on it, with the melody beside it" do
    view = mount_screen(SongsScreen, %{})
    assert Enum.map(assigns(view).songs, & &1.module) == Songs.all()
    assert assigns(view).my_part == :bass
    assert_renderable(view)

    alto = render_info(view, {:tap, {:my_part, :alto}})
    assert Settings.my_part() == :alto
    assert assigns(mount_screen(SongsScreen, %{})).my_part == :alto

    opened = render_info(alto, {:tap, {:open, ThisIsJesus}})
    assert navigated_to(opened) == PracticeScreen
  end

  test "the card says the key, tempo and length" do
    assert SongsScreen.facts(ThisIsJesus.bass()) =~ ~r/^B♭ major · ♩ = 77 · 81 bars · \d:\d\d$/
  end

  test "on a tablet the list is at most 640 wide, and narrower than a narrower window" do
    width = fn w ->
      view =
        mount_screen(SongsScreen, %{screen: {w, 1000.0}}, %{}, size_class: {:regular, :regular})

      Enum.find_value(find_all(view, :column), & &1.props[:width])
    end

    assert width.(834.0) == 640
    assert width.(600.0) == 560.0
  end
end
