defmodule ChoirCoach.PracticeScreenTest do
  # Mixes and headphone delays live in Mob.State, one shared store.
  use Mob.ScreenCase, async: false

  alias ChoirCoach.Audio.{Fake, Lease}
  alias ChoirCoach.{AudioScreen, Mix, PracticeScreen, Settings, Song, Songs}
  alias ChoirCoach.Songs.GloriousNight

  @params %{
    screen: {411.0, 914.0},
    parts: Songs.parts(GloriousNight, :bass)
  }

  setup do
    for part <- [:soprano, :alto, :tenor, :bass, :melody],
        do: Mob.State.delete({:mix, part}) && Mob.State.delete({:saved_mix, part})

    for key <- ["bluetooth:WH-1000XM4", "speaker:Pixel 8"],
        do: Mob.State.delete({:mic_delay_ms, key}) && Mob.State.delete({:delay_offered, key})

    Enum.each([:output_pref, :input_pref], &Mob.State.delete/1)
    :ok
  end

  # Mount and deliver the engine's ready message (the fake sends it on load).
  defp ready_view do
    PracticeScreen
    |> mount_screen(@params)
    |> ready()
  end

  # Deliver the engine's `event` for the view's current load.
  defp ready(view), do: render_info(view, event(view, :ready, %{}))

  defp event(view, kind, payload), do: {:choir_audio, kind, payload, assigns(view).audio.load}

  test "mounts loading, becomes ready, renders a drawable tree" do
    view = mount_screen(PracticeScreen, @params)
    assert assigns(view).audio_status == :loading
    assert PracticeScreen.subtitle(assigns(view)) =~ "Loading"

    view = ready(view)
    assert assigns(view).audio_status == :ready
    assert assigns(view).listening == :mic
    refute assigns(view).playing
    assert_renderable(view)
  end

  test "each voice part opens with its own piano and rehearsal track, and switches to the melody and back" do
    for part <- ChoirCoach.Settings.voice_parts() do
      view =
        PracticeScreen
        |> mount_screen(%{@params | parts: Songs.parts(GloriousNight, part)})
        |> ready()

      a = assigns(view)
      name = part |> Atom.to_string() |> String.capitalize()
      assert a.part == part

      # Its piano (left) and its rehearsal track (voices left, band right), as lanes.
      assert Enum.map(a.mix.rows, & &1.label) == ["#{name} on piano", "#{name} rehearsal", "Band"]

      assert Enum.map(a.audio.spec.sources, & &1.file) == [
               a.tracks.piano.file,
               a.tracks.rehearsal.file
             ]

      assert a.tracks.piano.file =~ "piano_#{part}.mp3"

      playing = view |> put_time(40_000.0) |> render_info({:tap, :play_pause})
      melody = playing |> render_info({:tap, {:part, :melody}}) |> ready()
      assert {assigns(melody).part, assigns(melody).playing} == {:melody, true}

      back = melody |> render_info({:tap, {:part, part}}) |> ready()
      assert {assigns(back).part, assigns(back).playing} == {part, true}
      assert_in_delta assigns(back).t_ms, 40_000.0, 100
    end
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
    beat = Song.beat_ms(song, bar)

    mid = view |> put_time(bar + 2 * beat) |> render_info({:tap, :back_bar})
    assert assigns(mid).t_ms == bar

    early = view |> put_time(bar + 0.3 * beat) |> render_info({:tap, :back_bar})
    assert assigns(early).t_ms == Song.bar_start(song, 21)
  end

  test "+1 bar jumps to the next bar's start; on the last bar it stays put" do
    view = ready_view()
    song = assigns(view).song
    bar = Song.bar_start(song, 22)

    ahead =
      view |> put_time(bar + 2 * Song.beat_ms(song, bar)) |> render_info({:tap, :forward_bar})

    assert assigns(ahead).t_ms == Song.bar_start(song, 23)

    last = List.last(song.bars)
    at_end = view |> put_time(last.start_ms + 10) |> render_info({:tap, :forward_bar})
    assert assigns(at_end).t_ms == last.start_ms + 10
  end

  test "dragging the progress track pauses, follows the finger, and plays on from where it's let go" do
    view = ready_view() |> put_time(10_000.0) |> render_info({:tap, :play_pause})
    assert assigns(view).playing
    duration = Song.duration_ms(assigns(view).song)
    width = assigns(view).screen_w - 2 * 24 - 2 * 46

    held = render_info(view, {:drag, :scrub, %{x: width / 4, phase: :began}})
    refute assigns(held).playing
    assert_in_delta assigns(held).t_ms, duration / 4, 1

    moved = render_info(held, {:drag, :scrub, %{x: width / 2, phase: :dragging}})
    refute assigns(moved).playing
    assert_in_delta assigns(moved).t_ms, duration / 2, 1

    # Past the end of the track it clamps to the end.
    past = render_info(moved, {:drag, :scrub, %{x: width * 1.3, phase: :dragging}})
    assert assigns(past).t_ms == duration

    # Letting go resumes playback where the finger left.
    let_go = render_info(past, {:drag, :scrub, %{x: width * 0.6, phase: :ended}})
    assert assigns(let_go).playing
    assert_in_delta assigns(let_go).t_ms, duration * 0.6, 1
    assert assigns(let_go).scrub == nil

    # Paused before the drag: it stays paused at the new place.
    paused = ready_view()

    dropped =
      paused
      |> render_info({:drag, :scrub, %{x: -20.0, phase: :began}})
      |> render_info({:drag, :scrub, %{x: -20.0, phase: :ended}})

    refute assigns(dropped).playing
    assert assigns(dropped).t_ms == 0.0
  end

  test "a drag cut short by opening Audio doesn't start playback after coming back" do
    playing = ready_view() |> put_time(10_000.0) |> render_info({:tap, :play_pause})
    width = assigns(playing).screen_w - 2 * 24 - 2 * 46

    # The drag's end never arrives: Audio takes the engine mid-drag.
    back =
      playing
      |> render_info({:drag, :scrub, %{x: width / 4, phase: :dragging}})
      |> through_audio({:mic_delay, 60})

    assert assigns(back).scrub == nil

    dropped =
      back
      |> render_info({:drag, :scrub, %{x: width / 2, phase: :began}})
      |> render_info({:drag, :scrub, %{x: width / 2, phase: :ended}})

    refute assigns(dropped).playing
  end

  # The tag of every tappable node, and whether it also takes the press that
  # keeps its tap alive across the playback re-renders (lost taps otherwise:
  # Mob's Android bridge drops a plain tap from an earlier render).
  defp taps(view) do
    for %{props: %{on_tap: {_pid, tag}} = props} <- flatten(view) do
      {tag, match?({_, :held}, props[:on_press_out])}
    end
  end

  test "while playing, every control on screen and in the mix sheet keeps its tap through re-renders" do
    playing = ready_view() |> put_time(10_000.0) |> render_info({:tap, :play_pause})
    sheet = render_info(playing, {:tap, :mix})

    for view <- [playing, sheet] do
      unguarded = for {tag, false} <- taps(view), do: tag
      assert unguarded == []
    end

    assert {:mix, true} in taps(sheet)
    assert {{:preset, :right_ear}, true} in taps(sheet)
    # The lift itself does nothing.
    assert assigns(render_info(sheet, {:press_out, :held})).playing
  end

  test "the mix sheet's Done closes it, as the Mix button does" do
    sheet = ready_view() |> render_info({:tap, :mix})
    assert assigns(sheet).mix_open

    done =
      Enum.find(find_all(sheet, :box), fn box ->
        match?({_, :mix}, box.props[:on_tap]) and text(box) == "Done"
      end)

    assert done
    {_pid, tag} = done.props.on_tap
    refute assigns(render_info(sheet, {:tap, tag})).mix_open
  end

  test "a preset applies at once: the same recordings re-set the gains; a whole recording reloads in place" do
    view = ready_view() |> put_time(40_000.0) |> render_info({:tap, :play_pause})

    right = render_info(view, {:tap, {:preset, :right_ear}})
    a = assigns(right)
    assert {a.audio_status, a.playing, a.mix.preset} == {:ready, true, :right_ear}
    assert a.audio.gains == Mix.lane_gains(a.mix, a.mono)

    choir = render_info(right, {:tap, {:preset, :full_choir}})
    assert {assigns(choir).audio_status, assigns(choir).playing} == {:loading, false}
    assert hd(assigns(choir).audio.spec.sources).file =~ "split"

    resumed = ready(choir)
    assert assigns(resumed).playing
    assert_in_delta assigns(resumed).t_ms, 40_000.0, 50
  end

  test "on headphones the balance reaches the ears; on the phone speaker both ears get the average" do
    view = ready_view() |> render_info({:tap, {:preset, :right_ear}})
    # The fake engine's default output is the phone speaker.
    assert assigns(view).mono
    [{l, r} | _] = assigns(view).audio.gains
    assert l == r

    phones = through_audio(view, {:audio_output, 31})
    a = assigns(phones)
    refute a.mono
    # Lane 0 is the bass on piano, in the right ear.
    [{l, r} | _] = a.audio.gains
    assert r > l
    assert a.mic_delay == Settings.mic_delay_ms(Settings.device_key(a.output))
  end

  test "moving a slider makes the mix Custom, and Save keeps it as My mix" do
    view =
      ready_view()
      |> render_info({:tap, :mix})
      |> render_info({:tap, {:open_row, :band}})
      |> render_info({:change, {:level, :band}, 33.4})

    a = assigns(view)
    assert {a.mix.preset, Mix.caption(a.mix)} == {:custom, "Custom"}
    assert Enum.find(a.mix.rows, &(&1.id == :band)).level == 33
    assert a.audio.gains == Mix.lane_gains(a.mix, a.mono)
    assert_renderable(view)

    saved = render_info(view, {:tap, :save_mix})
    assert Mix.caption(assigns(saved).mix) == "My mix"

    assert :my_mix in Enum.map(
             Mix.presets(assigns(saved).mix, Settings.saved_mix(:bass)),
             & &1.id
           )
  end

  test "switching a source off silences its lane" do
    view = ready_view() |> render_info({:tap, {:toggle_row, :band}})
    refute Enum.find(assigns(view).mix.rows, &(&1.id == :band)).on
    # The band is the last lane: the rehearsal track's right channel.
    {l, r} = List.last(assigns(view).audio.gains)
    assert l == 0 and r == 0
  end

  test "the part's mix is kept for the next time the song opens" do
    ready_view()
    |> render_info({:tap, :mix})
    |> render_info({:tap, {:preset, :right_ear}})
    |> render_info({:tap, :mix})

    assert assigns(mount_screen(PracticeScreen, @params)).mix.preset == :right_ear
  end

  test "switching to the melody keeps the place, with the melody's sources" do
    view = ready_view() |> put_time(40_000.0) |> render_info({:tap, :play_pause})
    bass_center = assigns(view).center_midi

    switched = render_info(view, {:tap, {:part, :melody}})
    a = assigns(switched)
    assert {a.part, a.song.part, a.song.clef} == {:melody, :melody, :treble}
    # No piano for the melody: the soprano-led voices and the band.
    assert Enum.map(a.mix.rows, & &1.id) == [:voices, :band]
    assert {a.audio_status, a.playing, a.trace} == {:loading, false, []}
    # The pitch roll recentres on the melody, an octave or so above the bass.
    assert a.center_midi > bass_center + 7

    resumed = ready(switched)
    assert assigns(resumed).playing
    assert_in_delta assigns(resumed).t_ms, 40_000.0, 50
    assert_renderable(resumed)

    assert assigns(render_info(resumed, {:tap, {:part, :bass}})).part == :bass
  end

  test "switching again while the sources load still resumes where playback was" do
    view = ready_view() |> put_time(40_000.0) |> render_info({:tap, :play_pause})

    resumed =
      view
      |> render_info({:tap, {:part, :melody}})
      |> render_info({:tap, {:preset, :full_choir}})
      |> ready()

    assert {assigns(resumed).part, assigns(resumed).mix.recording} == {:melody, :split}
    assert assigns(resumed).playing
    assert_in_delta assigns(resumed).t_ms, 40_000.0, 50
  end

  test "test mode keeps listening to the track across a part switch" do
    view = ready_view() |> render_info({:listen, :playback})
    assert assigns(view).listening == :playback

    switched = view |> render_info({:tap, {:part, :melody}}) |> ready()

    assert assigns(switched).listening == :playback
  end

  test "while a switch loads, pause cancels the resume and a seek moves it" do
    loading =
      ready_view()
      |> put_time(40_000.0)
      |> render_info({:tap, :play_pause})
      |> render_info({:tap, {:part, :melody}})

    # The button shows pause while the start is pending, and play once cancelled.
    assert PracticeScreen.shows_pause?(assigns(loading))
    cancelled = render_info(loading, {:tap, :play_pause})
    refute PracticeScreen.shows_pause?(assigns(cancelled))
    refute assigns(ready(cancelled)).playing

    moved = loading |> render_info({:seek, 60_000.0}) |> ready()
    assert assigns(moved).playing
    assert_in_delta assigns(moved).t_ms, 60_000.0, 50
  end

  test "play before the track is ready starts it once loaded; test mode too" do
    view =
      PracticeScreen
      |> mount_screen(@params)
      |> render_info({:tap, :play_pause})
      |> render_info({:listen, :playback})

    refute assigns(view).playing
    assert PracticeScreen.shows_pause?(assigns(view))
    ready = ready(view)
    assert assigns(ready).playing
    assert assigns(ready).listening == :playback
  end

  test "a track that fails to load says so" do
    view = mount_screen(PracticeScreen, @params)
    view = render_info(view, event(view, :load_error, :not_found))

    assert PracticeScreen.subtitle(assigns(view)) =~ "Can't play"
  end

  test "a track that breaks while playing stops: playback, the frame loop and the microphone" do
    playing = ready_view() |> put_time(40_000.0) |> render_info({:tap, :play_pause})
    assert {assigns(playing).playing, assigns(playing).listening} == {true, :mic}

    broken = render_info(playing, event(playing, :load_error, :decode_error))
    a = assigns(broken)

    assert {a.playing, a.listening, a.tick_timer, a.audio.playing, a.audio.source} ==
             {false, :off, nil, false, nil}

    assert PracticeScreen.subtitle(a) =~ "Can't play"
  end

  describe "while the Audio screen has the engine" do
    test "the practice screen leaves it alone: its old load's events and frame ticks do nothing" do
      playing = ready_view() |> put_time(40_000.0) |> render_info({:tap, :play_pause})
      old_ready = event(playing, :ready, %{})
      old_error = event(playing, :load_error, :not_found)

      away = render_info(playing, {:tap, :audio})
      a = assigns(away)

      assert {a.playing, a.listening, a.audio.playing, a.audio.source} ==
               {false, :off, false, nil}

      after_events =
        away
        |> render_info(old_ready)
        |> render_info(old_error)
        |> render_info(:tick)
        |> render_info({:listen, :playback})

      b = assigns(after_events)
      assert b.audio == a.audio
      assert {b.audio_status, b.listening, b.playing} == {:ready, :off, false}
    end

    test "a new output applies only once the engine is back, then the reload resumes in place" do
      away = ready_view() |> put_time(40_000.0) |> render_info({:tap, :audio})
      old_ready = event(away, :ready, %{})

      chosen = render_info(away, {:audio_output, 31})
      assert assigns(chosen).audio.output == nil

      back = render_info(chosen, {:audio_engine_reset})
      assert assigns(back).audio.output == 31
      assert assigns(back).audio_status == :loading

      # The song's load from before is not the reload.
      assert assigns(render_info(back, old_ready)).audio_status == :loading

      ready = ready(back)
      assert {assigns(ready).output.kind, assigns(ready).mono} == {:bluetooth, false}
      assert assigns(ready).listening == :mic
      assert_in_delta assigns(ready).t_ms, 40_000.0, 50
    end
  end

  describe "one holder at a time" do
    # A stand-in Audio screen: borrows the engine and holds it until killed.
    defp audio_screen_elsewhere do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      :ok = Lease.borrow(pid)
      Fake.hold_elsewhere(pid)
    end

    test "found busy at mount, it waits for the borrower to go, then loads" do
      audio_screen = audio_screen_elsewhere()
      view = mount_screen(PracticeScreen, @params)
      assert {assigns(view).attached, assigns(view).audio.load} == {false, nil}

      Process.exit(audio_screen, :kill)
      assert_receive {:audio_engine_reset} = reset
      back = render_info(view, reset)
      assert {assigns(back).attached, assigns(back).audio_status} == {true, :loading}
      assert assigns(ready(back)).listening == :mic
    end

    test "losing the engine while playing detaches it with no further engine calls" do
      playing = ready_view() |> put_time(40_000.0) |> render_info({:tap, :play_pause})
      Fake.hold_elsewhere()

      ticked = render_info(playing, :tick)
      assert_received {:choir_audio, :not_owner, _, _} = lost
      detached = render_info(ticked, lost)
      a = assigns(detached)
      assert {a.attached, a.playing, a.listening} == {false, false, :off}

      # Detached, it makes no calls: none of them refused, nothing changed.
      again = detached |> render_info(:tick) |> render_info({:tap, :play_pause})
      refute_received {:choir_audio, :not_owner, _, _}
      assert assigns(again).audio == a.audio
    end

    test "back from Audio but the engine is busy again: it stays detached and waits again" do
      away = ready_view() |> render_info({:tap, :audio})
      audio_screen = audio_screen_elsewhere()

      still_away = render_info(away, {:audio_engine_reset})
      refute assigns(still_away).attached

      Process.exit(audio_screen, :kill)
      assert_receive {:audio_engine_reset} = reset
      assert assigns(render_info(still_away, reset)).attached
    end

    test "a microphone that fails while listening says so; an older listening's failure doesn't" do
      view = ready_view()
      listen = assigns(view).audio.listen

      stale = render_info(view, {:choir_audio, :mic_error, :disconnected, make_ref()})
      refute PracticeScreen.subtitle(assigns(stale)) =~ "Microphone unavailable"
      assert assigns(stale).audio.source == :mic

      failed = render_info(view, {:choir_audio, :mic_error, :disconnected, listen})
      assert PracticeScreen.subtitle(assigns(failed)) =~ "Microphone unavailable"
      # The failed stream is stopped, not left polling.
      assert assigns(failed).audio.source == nil
    end
  end

  test "the headphones icon pauses and opens Audio; coming back reloads the sources in place" do
    view =
      ready_view()
      |> put_time(40_000.0)
      |> render_info({:tap, :play_pause})
      |> render_info({:tap, :audio})

    refute assigns(view).playing
    assert navigated_to(view) == AudioScreen

    back = render_info(view, {:audio_engine_reset})
    assert assigns(back).audio_status == :loading
    ready = ready(back)
    refute assigns(ready).playing
    assert_in_delta assigns(ready).t_ms, 40_000.0, 50
  end

  test "new headphones get one offer to set their delay" do
    phones = ready_view() |> through_audio({:audio_output, 31})
    assert PracticeScreen.subtitle(assigns(phones)) =~ "New headphones"

    # Opening Audio is the offer taken up; it isn't made again.
    again = through_audio(phones, {:audio_output, 31})
    refute PracticeScreen.subtitle(assigns(again)) =~ "New headphones"
  end

  # Open Audio, have it send `message`, close it and let the reload finish.
  defp through_audio(view, message) do
    opened = render_info(view, {:tap, :audio})
    assert navigated_to(opened) == AudioScreen
    opened |> render_info(message) |> render_info({:audio_engine_reset}) |> ready()
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
