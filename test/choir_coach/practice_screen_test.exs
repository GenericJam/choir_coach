defmodule ChoirCoach.PracticeScreenTest do
  use Mob.ScreenCase, async: true

  alias ChoirCoach.{PracticeScreen, Song}

  @params %{screen: {411.0, 914.0}}

  test "mounts paused at the start and renders a drawable tree" do
    view = mount_screen(PracticeScreen, @params)
    assert assigns(view).playing == false
    assert assigns(view).t_ms == 0.0
    assert_renderable(view)
  end

  test "restart while playing keeps a single frame loop" do
    playing = PracticeScreen |> mount_screen(@params) |> render_info({:tap, :play_pause})
    timer = assigns(playing).tick_timer
    assert is_reference(timer)

    restarted = render_info(playing, {:tap, :restart})
    assert assigns(restarted).tick_timer == timer

    paused = render_info(restarted, {:tap, :play_pause})
    assert assigns(paused).tick_timer == nil
  end

  test "play / pause toggles the clock" do
    view = PracticeScreen |> mount_screen(@params) |> render_info({:tap, :play_pause})
    assert assigns(view).playing
    view = render_info(view, {:tap, :play_pause})
    refute assigns(view).playing
  end

  test "a frame mid-song samples the voice and shows feedback" do
    view = PracticeScreen |> mount_screen(@params) |> render_info({:tap, :play_pause})
    socket = socket_at(view, 1_200)
    assert socket.assigns.t_ms == 1_200.0
    assert Enum.count_until(socket.assigns.trace, 51) > 50
    assert socket.assigns.feedback.status != :breathe
  end

  test "at the end it loops back to the start, or stops when loop is off" do
    view = PracticeScreen |> mount_screen(@params) |> render_info({:tap, :play_pause})
    duration = Song.duration_ms(assigns(view).song)

    looped = socket_at(view, duration + 50)
    assert looped.assigns.playing and looped.assigns.t_ms == 0.0 and looped.assigns.trace == []

    view = render_info(view, {:tap, :loop})
    stopped = socket_at(view, duration + 50)
    refute stopped.assigns.playing
    assert stopped.assigns.t_ms == duration
  end

  test "−1 bar jumps to the bar start, or the previous bar within its first beat" do
    view = mount_screen(PracticeScreen, @params)
    song = assigns(view).song
    bar = Song.bar_start(song, 22)
    beat = Song.beat_ms(song)

    mid = view |> put_time(bar + 2 * beat) |> render_info({:tap, :back_bar})
    assert assigns(mid).t_ms == bar

    early = view |> put_time(bar + 0.3 * beat) |> render_info({:tap, :back_bar})
    assert assigns(early).t_ms == Song.bar_start(song, 21)
  end

  test "accompaniment level cycles" do
    view = mount_screen(PracticeScreen, @params)

    levels =
      Enum.scan(1..4, view, fn _, v -> render_info(v, {:tap, :volume}) end)
      |> Enum.map(&assigns(&1).volume)

    assert levels == [40, 0, 100, 70]
  end

  # Run one frame as if `t` ms of song time had passed since play.
  defp socket_at(view, t) do
    socket = view.socket
    PracticeScreen.advance(socket, socket.assigns.started_at + round(t - socket.assigns.base_ms))
  end

  defp put_time(view, t) do
    %{view | socket: Mob.Socket.assign(view.socket, t_ms: t, base_ms: t)}
  end
end
