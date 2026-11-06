defmodule ChoirCoach.AudioScreenTest do
  # Mob.State is one shared store; these tests write to it.
  use Mob.ScreenCase, async: false

  alias ChoirCoach.Audio.Fake
  alias ChoirCoach.{AudioScreen, Calibration, Settings}

  # Audio.Fake's canned devices.
  @speaker 2
  @bluetooth 31
  @bluetooth_key "bluetooth:WH-1000XM4"
  @speaker_key "speaker:Pixel 8"

  setup do
    clear_delays()
    on_exit(&clear_delays/0)
  end

  defp clear_delays do
    {{:mic_delay_ms, :_}, :_}
    |> Mob.State.match()
    |> Enum.each(fn {key, _} -> Mob.State.delete(key) end)

    Enum.each([:mic_delay_ms, :output_pref, :input_pref], &Mob.State.delete/1)
  end

  # The output row that shows the check.
  defp checked_output(view) do
    view
    |> find_all(:row)
    |> Enum.find(fn row ->
      match?("output:" <> _, row.props[:id]) and find(row, :canvas, id: "check")
    end)
    |> then(&(&1 && &1.props.id))
  end

  test "picking an output routes there, tells the practice screen and moves the check" do
    view = mount_screen(AudioScreen, %{practice: self()})
    assert checked_output(view) == "output:#{@speaker}"
    assert text(view) =~ "Wired headphones Not plugged in"

    view = render_info(view, {:tap, {:output, @bluetooth}})

    assert_received {:audio_output, @bluetooth}
    assert checked_output(view) == "output:#{@bluetooth}"
    assert Fake.output_device(assigns(view).audio) == @bluetooth
    assert_renderable(view)
  end

  test "−/+ step the delay for the device in use, save it and tell the practice screen" do
    view = mount_screen(AudioScreen, %{practice: self()})
    speaker_default = Settings.mic_delay_ms(@speaker_key)

    view = render_info(view, {:tap, :plus})
    assert_received {:mic_delay, ms}
    assert ms == speaker_default + 10
    assert Settings.mic_delay_ms(@speaker_key) == ms

    view = render_info(view, {:tap, {:output, @bluetooth}})
    assert text(view) =~ "#{Settings.mic_delay_ms(@bluetooth_key)} ms"

    view = render_info(view, {:tap, :minus})
    assert_received {:mic_delay, bt}
    assert bt == 190
    assert Settings.mic_delay_ms(@bluetooth_key) == 190
    assert Settings.mic_delay_ms(@speaker_key) == speaker_default + 10
    assert text(view) =~ "Saved for these headphones"
  end

  test "the Bluetooth headset mic asks first" do
    view = mount_screen(AudioScreen, %{practice: self()})
    view = render_info(view, {:tap, {:input, 32}})
    refute_received {:audio_input, _}

    view = render_info(view, {:tap, :confirm_input})
    assert_received {:audio_input, 32}
    refute text(view) =~ "Use it anyway"
  end

  test "singing along to the clicks offers the measured delay, and using it saves it" do
    view =
      AudioScreen
      |> mount_screen(%{practice: self()})
      |> render_info({:tap, {:output, @bluetooth}})
      |> render_info({:tap, :calibrate})

    assert_received {:choir_audio, :ready, _info, _load} = ready
    view = render_info(view, ready)

    view = put_readings(view, sung_readings(180.0)) |> render_info(:tick)
    assert text(view) =~ "Use 180 ms"

    view = render_info(view, {:tap, :use_calibration})
    assert_received {:mic_delay, 180}
    assert Settings.mic_delay_ms(@bluetooth_key) == 180
    assert text(view) =~ "180 ms"
    assert text(view) =~ "Set by singing along"
  end

  test "a singer heard on too few clicks is asked to try again" do
    view =
      AudioScreen
      |> mount_screen(%{practice: self()})
      |> render_info({:tap, :calibrate})

    assert_received {:choir_audio, :ready, _info, _load} = ready

    view =
      view
      |> render_info(ready)
      |> put_readings(sung_readings(150.0) |> Enum.filter(&(elem(&1, 0) < 2500)))
      |> render_info(:tick)
      |> put_readings([{6500.0, nil, 0.0, -60.0}])
      |> render_info(:tick)

    assert text(view) =~ "Try again"
    refute text(view) =~ "Use "
  end

  test "picking another output while the clicks load cancels the run and the meter carries on" do
    view =
      AudioScreen
      |> mount_screen(%{practice: self()})
      |> render_info({:tap, :calibrate})
      |> render_info({:tap, {:output, @bluetooth}})

    # The cancelled run's load finishes late: nothing starts.
    assert_received {:choir_audio, :ready, _info, _load} = ready
    view = render_info(view, ready)
    assert text(view) =~ "Set by singing along"
    refute Fake.position(assigns(view).audio) |> elem(0) == :playing

    # The screen kept the restarted listening, so its later failures count.
    assert assigns(view).audio.source == :mic
    view = view |> put_readings([{100.0, 45.0, 0.9, -20.0}]) |> render_info(:tick)
    assert text(view) =~ "Good"

    failed =
      render_info(view, {:choir_audio, :mic_error, :disconnected, assigns(view).audio.listen})

    assert assigns(failed).audio.source == nil
    refute assigns(failed).listening
  end

  test "changing the microphone mid-run cancels it, so the two routes' readings never mix" do
    view =
      AudioScreen
      |> mount_screen(%{practice: self()})
      |> render_info({:tap, :calibrate})

    assert_received {:choir_audio, :ready, _info, _load} = ready

    view =
      view
      |> render_info(ready)
      |> put_readings(sung_readings(150.0) |> Enum.filter(&(elem(&1, 0) < 3000)))
      |> render_info(:tick)
      |> render_info({:tap, {:input, 9}})

    assert_received {:audio_input, 9}
    assert text(view) =~ "Set by singing along"

    view =
      view
      |> put_readings(sung_readings(150.0) |> Enum.filter(&(elem(&1, 0) >= 3000)))
      |> render_info(:tick)

    refute text(view) =~ "Use "
    assert text(view) =~ "Set by singing along"
  end

  test "in the background the run is cancelled and the mic and meter stop; back in front they resume" do
    view =
      AudioScreen
      |> mount_screen(%{practice: self()})
      |> render_info({:tap, :calibrate})

    assert_received {:choir_audio, :ready, _, _} = ready
    view = render_info(view, ready)
    assert assigns(view).audio.source == :mic

    view = render_info(view, {:mob_device, :did_enter_background})
    assert assigns(view).audio.source == nil
    assert assigns(view).tick_timer == nil
    assert text(view) =~ "Set by singing along"

    # A tick queued before going to the background does nothing.
    view = view |> put_readings([{100.0, 45.0, 0.9, -20.0}]) |> render_info(:tick)
    assert assigns(view).tick_timer == nil
    refute text(view) =~ "Good"

    view = render_info(view, {:mob_device, :will_enter_foreground})
    assert assigns(view).audio.source == :mic
    view = render_info(view, :tick)
    assert text(view) =~ "Good"
  end

  # Silence every 10 ms, and a sung "ta" `lag` ms after each click.
  defp sung_readings(lag) do
    quiet = for t <- 0..6500//10, do: {t * 1.0, nil, 0.0, -60.0}

    sung =
      for click <- Calibration.click_times_ms(),
          k <- 0..9,
          do: {click + lag + k * 10, 45.0, 0.9, -18.0}

    Enum.sort_by(quiet ++ sung, &elem(&1, 0))
  end

  defp put_readings(view, readings) do
    audio = Fake.put_readings(assigns(view).audio, readings)
    %{view | socket: Mob.Socket.assign(view.socket, :audio, audio)}
  end
end
