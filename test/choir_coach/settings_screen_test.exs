defmodule ChoirCoach.SettingsScreenTest do
  # Mob.State is one shared store; these tests write to it.
  use Mob.ScreenCase, async: false

  alias ChoirCoach.{PracticeScreen, Settings, SettingsScreen}
  alias ChoirCoach.Songs.GloriousNight

  setup do
    Mob.State.delete(:mic_delay_ms)
    :ok
  end

  test "starts from the configured default until a delay is saved" do
    assert assigns(mount_screen(SettingsScreen)).delay == 60
    Settings.put_mic_delay_ms(180)
    assert assigns(mount_screen(SettingsScreen)).delay == 180
  end

  test "the slider snaps to 10 ms, stays in range, saves, and tells the practice screen" do
    view = mount_screen(SettingsScreen, %{practice: self()})

    view = render_info(view, {:change, :delay, 233.7})
    assert assigns(view).delay == 230
    assert Settings.mic_delay_ms() == 230
    assert_received {:mic_delay, 230}

    view = render_info(view, {:change, :delay, 900.0})
    assert assigns(view).delay == 400
    assert_received {:mic_delay, 400}
  end

  test "steps and presets" do
    view = mount_screen(SettingsScreen)
    assert assigns(render_info(view, {:tap, :plus})).delay == 70
    assert assigns(render_info(view, {:tap, :minus})).delay == 50
    assert assigns(render_info(view, {:tap, :preset_bluetooth})).delay == 200
    assert assigns(render_info(view, {:tap, :preset_wired})).delay == 60
    assert_renderable(view)
  end

  test "the practice screen's gear pauses and opens settings" do
    view =
      PracticeScreen
      |> mount_screen(%{
        screen: {411.0, 914.0},
        song: GloriousNight.bass(),
        tracks: GloriousNight.tracks()
      })
      |> render_info({:choir_audio, :ready, %{}})
      |> render_info({:tap, :play_pause})
      |> render_info({:tap, :settings})

    refute assigns(view).playing
    assert navigated_to(view) == SettingsScreen
  end
end
