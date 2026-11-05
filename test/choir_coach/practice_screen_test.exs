defmodule ChoirCoach.PracticeScreenTest do
  use Mob.ScreenCase, async: true

  alias ChoirCoach.Audio.Fake
  alias ChoirCoach.{PracticeScreen, Song}

  @params %{screen: {411.0, 914.0}}

  # Mount and deliver the engine's ready message (the fake sends it on load).
  defp ready_view do
    PracticeScreen
    |> mount_screen(@params)
    |> render_info({:choir_audio, :ready, %{}})
  end

  test "mounts loading, becomes ready, renders a drawable tree" do
    view = mount_screen(PracticeScreen, @params)
    assert assigns(view).audio_status == :loading
    assert PracticeScreen.subtitle(assigns(view)) =~ "Loading"

    view = render_info(view, {:choir_audio, :ready, %{}})
    assert assigns(view).audio_status == :ready
    assert assigns(view).listening == :mic
    refute assigns(view).playing
    assert_renderable(view)
  end

  test "play is ignored until the track is ready" do
    view = PracticeScreen |> mount_screen(@params) |> render_info({:tap, :play_pause})
    refute assigns(view).playing
  end

  test "restart while playing keeps a single frame loop" do
    playing = render_info(ready_view(), {:tap, :play_pause})
    timer = assigns(playing).tick_timer
    assert is_reference(timer)

    restarted = render_info(playing, {:tap, :restart})
    assert assigns(restarted).tick_timer == timer

    paused = render_info(restarted, {:tap, :play_pause})
    assert assigns(paused).tick_timer == nil
  end

  test "a frame mid-phrase takes the voice's readings and shows feedback" do
    song = assigns(ready_view()).song
    from = Song.bar_start(song, 20)
    view = ready_view() |> put_time(from) |> render_info({:tap, :play_pause})

    socket = frame_at(view, from + 1_200)
    assert_in_delta socket.assigns.t_ms, from + 1_200, 0.001
    assert Enum.count_until(socket.assigns.trace, 51) > 50
    assert socket.assigns.feedback.status != :breathe
  end

  test "at the end it loops back to the start, or stops when loop is off" do
    view = render_info(ready_view(), {:tap, :play_pause})
    duration = Song.duration_ms(assigns(view).song)

    looped = frame_at(view, duration + 50)
    assert looped.assigns.playing and looped.assigns.t_ms == 0.0 and looped.assigns.trace == []

    view = render_info(view, {:tap, :loop})
    stopped = frame_at(view, duration + 50)
    refute stopped.assigns.playing
    assert stopped.assigns.t_ms == duration
  end

  test "−1 bar jumps to the bar start, or the previous bar within its first beat" do
    view = ready_view()
    song = assigns(view).song
    bar = Song.bar_start(song, 22)
    beat = Song.beat_ms(song)

    mid = view |> put_time(bar + 2 * beat) |> render_info({:tap, :back_bar})
    assert assigns(mid).t_ms == bar

    early = view |> put_time(bar + 0.3 * beat) |> render_info({:tap, :back_bar})
    assert assigns(early).t_ms == Song.bar_start(song, 21)
  end

  test "the part pill cycles tracks and resumes at the same place once loaded" do
    view = ready_view() |> put_time(40_000.0) |> render_info({:tap, :play_pause})

    switched = render_info(view, {:tap, :track})
    assert assigns(switched).track_mode == :split
    assert assigns(switched).audio_status == :loading
    refute assigns(switched).playing

    resumed = render_info(switched, {:choir_audio, :ready, %{}})
    assert assigns(resumed).playing
    assert_in_delta assigns(resumed).t_ms, 40_000.0, 50

    modes =
      Enum.scan(1..2, resumed, fn _, v -> render_info(v, {:tap, :track}) end)
      |> Enum.map(&assigns(&1).track_mode)

    assert modes == [:demo, :rehearsal]
  end

  test "a track that fails to load says so" do
    view =
      PracticeScreen
      |> mount_screen(@params)
      |> render_info({:choir_audio, :load_error, :not_found})

    assert PracticeScreen.subtitle(assigns(view)) =~ "Can't play"
  end

  test "accompaniment level cycles" do
    levels =
      Enum.scan(1..4, ready_view(), fn _, v -> render_info(v, {:tap, :volume}) end)
      |> Enum.map(&assigns(&1).volume)

    assert levels == [40, 0, 100, 70]
  end

  # Run one frame with the fake engine's clock `t` ms into the song.
  defp frame_at(view, t) do
    socket = view.socket
    audio = socket.assigns.audio
    audio = Fake.at(audio, audio.started_at + round(t - audio.base_ms))
    PracticeScreen.advance(Mob.Socket.assign(socket, :audio, audio))
  end

  defp put_time(view, t), do: %{view | socket: Mob.Socket.assign(view.socket, :t_ms, t * 1.0)}
end
