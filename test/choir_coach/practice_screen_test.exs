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

  test "restart and pause keep a single frame loop" do
    playing = render_info(ready_view(), {:tap, :play_pause})
    timer = assigns(playing).tick_timer
    assert is_integer(Process.read_timer(timer))

    # Whatever was pending is cancelled: one frame loop, never two.
    restarted = render_info(playing, {:tap, :restart})
    assert Process.read_timer(timer) == false
    assert is_integer(Process.read_timer(assigns(restarted).tick_timer))

    # Paused with the mic on, the hold's loop replaces playback's.
    paused = render_info(restarted, {:tap, :play_pause})
    assert Process.read_timer(assigns(restarted).tick_timer) == false
    assert is_integer(Process.read_timer(assigns(paused).tick_timer))
  end

  test "a frame queued just before play doesn't run: playback goes on" do
    {view, _note} = paused_on_note()
    # The hold's frame was due as the singer let go: its timer fired, then
    # play cancelled it, but the message is already in the mailbox.
    stale = {:tick, assigns(view).tick_token}
    playing = render_info(view, {:tap, :play_pause})
    after_stale = render_info(playing, stale)

    a = assigns(after_stale)
    assert a.playing
    assert {a.tick_timer, a.frames} == {assigns(playing).tick_timer, assigns(playing).frames}
  end

  describe "paused on a note with the microphone on" do
    # Paused mid-note (the fake engine plays nothing then; the test scripts
    # what the microphone hears) and run `n` hold frames.
    defp held(view, readings, n) do
      Enum.reduce(1..n, view, fn _, v ->
        audio = Fake.put_readings(assigns(v).audio, readings)
        %{v | socket: Mob.Socket.assign(v.socket, :audio, audio)} |> tick()
      end)
    end

    defp paused_on_note do
      view = ready_view()
      note = Enum.at(assigns(view).song.notes, 10)
      t = note.start_ms + 0.5 * note.dur_ms
      {view |> render_info({:seek, t}), note}
    end

    # A level reading as the engine gives it while paused: no song time.
    defp heard(midi), do: {-1.0e9, midi, 0.9, -20.0}
    defp silent, do: {-1.0e9, nil, 0.0, -70.0}

    test "the voice is measured against the note under the playhead, low, then on pitch" do
      {view, note} = paused_on_note()
      refute assigns(view).playing

      low = held(view, [heard(note.midi - 0.4)], 12)
      a = assigns(low)
      assert match?({:low, _}, a.feedback.status)
      assert {midi, _} = a.hold_voice
      assert_in_delta midi, note.midi - 0.4, 0.001
      assert_renderable(low)

      on = held(low, [heard(note.midi + 0.05)], 30)
      assert assigns(on).feedback.status == :on_pitch
    end

    test "scrubbed to a far note while paused, the roll comes round to it" do
      view = ready_view()
      song = assigns(view).song
      start = assigns(view).center_midi
      far = Enum.find(song.notes, &(abs(&1.midi - start) >= 5))
      moved = view |> render_info({:seek, far.start_ms + far.dur_ms / 2}) |> held([], 20)
      assert_in_delta assigns(moved).center_midi, far.midi, 0.5
    end

    test "an octave below counts as the written note, like while playing" do
      {view, note} = paused_on_note()
      a = view |> held([heard(note.midi - 12)], 30) |> assigns()
      assert a.feedback.status == :on_pitch
    end

    test "a stray reading (a harmonic, a noise) doesn't move the voice" do
      {view, note} = paused_on_note()
      steady = held(view, [heard(note.midi), heard(note.midi), heard(note.midi)], 3)
      glitch = held(steady, [heard(note.midi - 7.5), heard(note.midi)], 1)

      assert {midi, _} = assigns(glitch).hold_voice
      assert_in_delta midi, note.midi, 0.001
      assert assigns(glitch).feedback.status == :on_pitch
    end

    test "it slows down in silence and stays awake only while someone sings" do
      {view, note} = paused_on_note()
      singing = held(view, [heard(note.midi)], 3)
      assert assigns(singing).hold_awake
      assert Process.read_timer(assigns(singing).tick_timer) <= 33

      # Two seconds of silence (61 frames of 33 ms, then slower): one frame
      # per 150 ms.
      quiet = held(singing, [silent()], 70)
      assert assigns(quiet).hold_voice == nil
      assert Process.read_timer(assigns(quiet).tick_timer) > 33

      # Twenty seconds of silence: the screen may sleep again.
      asleep = held(quiet, [silent()], 140)
      refute assigns(asleep).hold_awake
    end

    test "playing ends the hold; the test mode track isn't held" do
      {view, note} = paused_on_note()
      playing = view |> held([heard(note.midi)], 3) |> render_info({:tap, :play_pause})
      assert assigns(playing).playing
      refute assigns(playing).hold_awake

      test_mode = render_info(view, {:listen, :playback})
      assert assigns(test_mode).listening == :playback
      quiet = tick(test_mode)
      assert assigns(quiet).tick_timer == nil
    end

    test "in the background the hold stops, and starts again in front" do
      {view, note} = paused_on_note()
      singing = held(view, [heard(note.midi)], 3)
      timer = assigns(singing).tick_timer

      away = render_info(singing, {:mob_device, :did_enter_background})
      assert {assigns(away).tick_timer, assigns(away).hold_awake} == {nil, false}
      assert Process.read_timer(timer) == false
      # A frame already queued does nothing.
      assert assigns(render_info(away, {:tick, assigns(singing).tick_token})).tick_timer == nil

      back = render_info(away, {:mob_device, :will_enter_foreground})
      assert is_integer(Process.read_timer(assigns(back).tick_timer))

      assert match?(
               {:low, _},
               back
               |> held([heard(note.midi - 0.4)], 12)
               |> assigns()
               |> Map.get(:feedback)
               |> Map.get(:status)
             )
    end

    test "a drag on the progress track has no frames of the hold's own; its release holds again" do
      {view, _note} = paused_on_note()
      timer = assigns(view).tick_timer

      dragging =
        view
        |> render_info({:drag, :scrub, %{x: 120.0, phase: :began}})
        |> render_info({:drag, :scrub, %{x: 140.0, phase: :dragging}})

      assert assigns(dragging).tick_timer == nil
      assert Process.read_timer(timer) == false

      released = render_info(dragging, {:drag, :scrub, %{x: 150.0, phase: :ended}})
      refute assigns(released).playing
      assert is_integer(Process.read_timer(assigns(released).tick_timer))
    end

    test "a drag whose end never came is closed by play / pause, so pausing holds again" do
      {view, _note} = paused_on_note()
      # The finger lifted, but the bridge lost the drag's end.
      stuck = render_info(view, {:drag, :scrub, %{x: 120.0, phase: :began}})
      assert assigns(stuck).scrub != nil

      paused = stuck |> render_info({:tap, :play_pause}) |> render_info({:tap, :play_pause})
      assert {assigns(paused).playing, assigns(paused).scrub} == {false, nil}
      assert is_integer(Process.read_timer(assigns(paused).tick_timer))
    end

    test "a drag that goes quiet (its end lost) ends where it was: paused holds, playing plays on" do
      {view, _note} = paused_on_note()

      moved =
        view
        |> render_info({:drag, :scrub, %{x: 120.0, phase: :began}})
        |> render_info({:drag, :scrub, %{x: 160.0, phase: :dragging}})

      t = assigns(moved).t_ms

      # An earlier event's timer is stale: only the latest one ends the drag.
      stale = render_info(moved, {:scrub_idle, make_ref()})
      assert assigns(stale).scrub != nil

      ended = render_info(moved, {:scrub_idle, assigns(moved).scrub.token})

      assert {assigns(ended).scrub, assigns(ended).playing, assigns(ended).t_ms} ==
               {nil, false, t}

      assert is_integer(Process.read_timer(assigns(ended).tick_timer))

      playing = render_info(ended, {:tap, :play_pause})
      dragged = render_info(playing, {:drag, :scrub, %{x: 200.0, phase: :began}})
      refute assigns(dragged).playing
      resting = render_info(dragged, {:drag, :scrub, %{x: 200.0, phase: :dragging}})
      resumed = render_info(resting, {:scrub_idle, assigns(resting).scrub.token})
      assert assigns(resumed).playing

      # The finger was only resting: the music went on under it, and its lift
      # where it rested neither pauses nor rewinds.
      later = %{
        resumed
        | socket: Mob.Socket.assign(resumed.socket, :t_ms, assigns(resumed).t_ms + 3_000)
      }

      lifted = render_info(later, {:drag, :scrub, %{x: 200.5, phase: :ended}})
      assert assigns(lifted).playing
      assert assigns(lifted).t_ms == assigns(later).t_ms

      # A drag that moves on does seek again.
      moved_on = render_info(lifted, {:drag, :scrub, %{x: 260.0, phase: :began}})
      refute assigns(moved_on).playing
      assert assigns(moved_on).t_ms != assigns(later).t_ms
    end

    test "in a rest, sound in the room doesn't count or keep the screen awake" do
      view = ready_view()
      song = assigns(view).song

      gap =
        Enum.find(Enum.chunk_every(song.notes, 2, 1, :discard), fn [a, b] ->
          b.start_ms - (a.start_ms + a.dur_ms) >= 300
        end)

      [before, _] = gap

      rest =
        view
        |> render_info({:seek, before.start_ms + before.dur_ms + 100})
        |> held([heard(before.midi)], 10)

      a = assigns(rest)
      assert {a.hold_voice, a.hold_awake} == {nil, false}
      assert Process.read_timer(a.tick_timer) > 33
    end
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
        |> tick()
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

      ticked = tick(playing)
      assert_received {:choir_audio, :not_owner, _, _} = lost
      detached = render_info(ticked, lost)
      a = assigns(detached)
      assert {a.attached, a.playing, a.listening} == {false, false, :off}

      # Detached, it makes no calls: none of them refused, nothing changed.
      again = detached |> tick() |> render_info({:tap, :play_pause})
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

  describe "on a tablet" do
    @tablet %{@params | screen: {834.0, 1194.0}}

    defp tablet_view(params \\ @tablet) do
      PracticeScreen
      |> mount_screen(params, %{}, size_class: {:regular, :regular})
      |> ready()
    end

    defp ids(view), do: for(%{props: %{id: id}} <- flatten(view), do: id)

    test "What you hear is docked: a strip per mix row, no Mix button, every tap kept while playing" do
      playing = tablet_view() |> put_time(10_000.0) |> render_info({:tap, :play_pause})
      ids = ids(playing)

      refute "ctl_mix" in ids
      assert Enum.all?(~w(row_part_piano row_voices row_band preset_right_ear), &(&1 in ids))

      # Each strip has its level; balance has no effect on the fake's phone
      # speaker, so no balance slider.
      sliders = for %{type: :slider, props: %{on_change: {_, tag}}} <- flatten(playing), do: tag

      assert Enum.sort(sliders) ==
               Enum.sort(for id <- [:part_piano, :voices, :band], do: {:level, id})

      assert [_, _, _] = find_all(playing, :text, text: "Balance: none in mono")

      assert for({tag, false} <- taps(playing), do: tag) == []
      assert {{:toggle_row, :band}, true} in taps(playing)
      assert {{:preset, :rehearsal}, true} in taps(playing)

      # The strips act as the sheet's rows did.
      quiet = render_info(playing, {:change, {:level, :band}, 30.0})
      assert {assigns(quiet).mix.preset, assigns(quiet).playing} == {:custom, true}
      assert find(quiet, :text, text: "Level 30")
      off = render_info(quiet, {:tap, {:toggle_row, :band}})
      refute Enum.find(assigns(off).mix.rows, &(&1.id == :band)).on

      # A whole recording plays as it is: no strips, still no Mix button.
      demo = render_info(off, {:tap, {:preset, :demo}})
      refute Enum.any?(ids(demo), &(&1 in ~w(row_band ctl_mix)))
    end

    test "the progress track shares the transport row and scrubs across its own width" do
      view = tablet_view() |> put_time(10_000.0)

      row =
        Enum.find(find_all(view, :row), fn row ->
          ids = for(%{props: %{id: id}} <- row.children, do: id)
          "ctl_play" in ids and "progress" in ids
        end)

      assert row
      track = find(view, :canvas, id: "progress")
      duration = Song.duration_ms(assigns(view).song)

      moved =
        view
        |> render_info({:drag, :scrub, %{x: track.props.width / 4, phase: :began}})
        |> render_info({:drag, :scrub, %{x: track.props.width / 4, phase: :ended}})

      assert_in_delta assigns(moved).t_ms, duration / 4, 1
    end

    test "balance shows its value and slider where it can apply, and no slider in mono" do
      view = tablet_view() |> render_info({:tap, {:preset, :right_ear}})

      balance_sliders = fn v ->
        for %{type: :slider, props: %{on_change: {_, {:balance, id}}}} <- flatten(v), do: id
      end

      assert assigns(view).mono
      assert balance_sliders.(view) == []

      phones = through_audio(view, {:audio_output, 31})
      refute assigns(phones).mono
      assert Enum.sort(balance_sliders.(phones)) == [:band, :part_piano, :voices]
      # The piano in the right ear, the band in the left.
      assert find(phones, :text, text: "Balance R 80")
      assert find(phones, :text, text: "Balance L 60")
    end

    test "with Custom and Save showing every preset chip is in the dock, which grows a line for them" do
      view = tablet_view()
      custom = render_info(view, {:change, {:level, :band}, 30.0})
      wrap = find(custom, :wrap)
      in_wrap = for(%{props: %{id: id}} <- flatten(wrap), do: id)

      assert Enum.all?(
               ~w(custom save_mix preset_rehearsal preset_right_ear preset_full_choir preset_demo),
               &(&1 in in_wrap)
             )

      canvas_h = fn v ->
        Enum.max(for %{type: :canvas, props: %{height: h}} <- flatten(v), do: h)
      end

      assert canvas_h.(custom) < canvas_h.(view)
    end

    test "the trace reaches back across the tablet's longer past" do
      song = assigns(tablet_view()).song
      from = Song.bar_start(song, 20)
      t = from + 4_000

      earliest = fn view ->
        socket = view |> put_time(from) |> render_info({:tap, :play_pause}) |> frame_at(t)
        socket.assigns.trace |> hd() |> elem(0)
      end

      # The phone keeps the 1.75 s its roll shows; the tablet shows more.
      assert earliest.(ready_view()) >= t - 1_850
      assert earliest.(tablet_view()) < t - 2_500
    end

    test "in landscape the track widens, strip controls take one line, and the short roll's status sits under the staff" do
      at = fn params ->
        view = tablet_view(params)
        song = assigns(view).song
        put_time(view, Song.bar_start(song, 22) + 300)
      end

      portrait = at.(@tablet)
      landscape = at.(%{@tablet | screen: {1194.0, 834.0}})
      track = fn v -> find(v, :canvas, id: "progress").props.width end

      assert track.(landscape) > track.(portrait) + 300
      assert find(portrait, :text, text: "Level 80")
      assert find(landscape, :text, text: "Level") && find(landscape, :text, text: "80")
      refute find(landscape, :text, text: "Level 80")

      # The big lyric floats over the tall portrait roll only.
      biggest = fn v ->
        roll = Enum.max_by(for(%{type: :canvas} = c <- flatten(v), do: c), & &1.props.height)

        roll.props.draw
        |> List.flatten()
        |> Enum.flat_map(&if(&1.op == :text, do: [&1.size], else: []))
        |> Enum.max()
      end

      assert biggest.(portrait) >= 40
      assert biggest.(landscape) < 40
      assert_renderable(landscape)
    end

    test "a regular-width window too small for the tablet layout keeps the phone's, and scrubs" do
      for screen <- [{600.0, 960.0}, {800.0, 600.0}] do
        view = tablet_view(%{@tablet | screen: screen}) |> put_time(10_000.0)
        assert assigns(view).layout == :phone
        assert find(view, :canvas, id: "ctl_mix")

        width = find(view, :canvas, id: "progress").props.width
        assert width > 100

        half =
          view
          |> render_info({:drag, :scrub, %{x: width / 2, phase: :began}})
          |> render_info({:drag, :scrub, %{x: width / 2, phase: :ended}})

        assert_in_delta assigns(half).t_ms, Song.duration_ms(assigns(view).song) / 2, 1
        assert_renderable(view)
      end
    end

    test "a resized window is laid out at its new size; a phone that stays a phone keeps its own" do
      # Off device the window measures as the reference artboard, 390 × 844.
      narrowed = change_size_class(tablet_view(), {:compact, :regular})
      assert {assigns(narrowed).layout, assigns(narrowed).screen_w} == {:phone, 390.0}
      assert find(narrowed, :canvas, id: "progress").props.width == 390 - 2 * 24 - 2 * 46

      phone = change_size_class(ready_view(), {:compact, :compact})
      assert {assigns(phone).layout, assigns(phone).screen_w} == {:phone, 411.0}
    end

    test "a regular-width window in the phone layout still follows its new size when it turns" do
      view = tablet_view(%{@tablet | screen: {600.0, 960.0}})
      assert assigns(view).layout == :phone

      Application.put_env(:choir_coach, :screen, {960.0, 600.0})
      on_exit(fn -> Application.delete_env(:choir_coach, :screen) end)
      turned = render_info(view, {:mob_device, :orientation_changed, :landscape_left})

      assert {assigns(turned).layout, assigns(turned).screen_w, assigns(turned).screen_h} ==
               {:phone, 960.0, 600.0}

      assert find(turned, :canvas, id: "progress").props.width == 960 - 2 * 24 - 2 * 46
    end

    test "the docked mix is saved as it changes: presets and toggles at once, sliders when the app goes to the background" do
      view = tablet_view()

      ear = render_info(view, {:tap, {:preset, :right_ear}})
      assert Settings.mix(:bass).preset == :right_ear

      off = render_info(ear, {:tap, {:toggle_row, :band}})
      refute Enum.find(Settings.mix(:bass).rows, &(&1.id == :band)).on

      quiet = render_info(off, {:change, {:level, :part_piano}, 30.0})
      assert Enum.find(Settings.mix(:bass).rows, &(&1.id == :part_piano)).level != 30

      render_info(quiet, {:mob_device, :did_enter_background})
      assert Enum.find(Settings.mix(:bass).rows, &(&1.id == :part_piano)).level == 30
    end
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

  # The frame the screen has pending, delivered now.
  defp tick(view), do: render_info(view, {:tick, assigns(view).tick_token})
end
