defmodule ChoirCoach.PracticeScreen do
  @moduledoc """
  The live practice screen: plays a rehearsal track, listens to the singer
  and draws how their pitch compares with the written part.

  Sound and pitch come from a `ChoirCoach.Audio` engine kept in the
  assigns. While playing, a ~30 fps frame tick reads the engine's position
  (the song time being heard), drains the pitch readings since the last
  frame into the trace, advances the feedback smoother and re-renders.

  Controls: restart, back one bar, play / pause, loop the song, and the
  accompaniment level. Tapping the part pill cycles the track: the part's
  rehearsal track, the split track (full choir), or the demo.
  """

  use Mob.Screen

  alias ChoirCoach.{
    Audio,
    ControlsView,
    Feedback,
    Pitch,
    PracticeView,
    Settings,
    SettingsScreen,
    Song,
    Style
  }

  @frame_ms 33
  @recentre_tau_ms 150.0
  # A reading this close to a written note counts for it (an early or late
  # entry); further away it's not the part being sung.
  @note_margin_ms 120
  # Silence shorter than this (one unsure reading) isn't a breath.
  @dropout_ms 150
  @header_height 55
  @controls_height 150
  @volume_steps [100, 70, 40, 0]
  @track_modes [:piano, :rehearsal, :split, :demo]
  # Reference artboard, used where the device can't be asked (host tests).
  @fallback_screen {390.0, 844.0}

  def mount(params, _session, socket) do
    %{song: song, tracks: tracks} = params
    {w, h} = Map.get_lazy(params, :screen, &screen_size/0)
    engine = Audio.engine()
    mode = hd(Enum.filter(@track_modes, &Map.has_key?(tracks, &1)))
    first = hd(song.notes)

    socket =
      Mob.Socket.assign(socket,
        song: song,
        tracks: tracks,
        track_mode: mode,
        engine: engine,
        audio:
          song
          |> engine.new()
          |> engine.set_mic_delay(Settings.mic_delay_ms())
          |> engine.load(tracks[mode]),
        audio_status: :loading,
        resume_at: nil,
        mic: :unknown,
        listening: :off,
        screen_w: w,
        screen_h: h,
        playing: false,
        t_ms: 0.0,
        trace: [],
        feedback: Feedback.new(),
        center_midi: first.midi * 1.0,
        loop: true,
        volume: 70,
        frames: 0,
        tick_timer: nil
      )

    {:ok, request_microphone(socket)}
  end

  def render(assigns) do
    sa = Map.get(assigns, :safe_area, %{top: 0.0, bottom: 0.0})
    canvas_h = canvas_height(assigns, sa)
    # Room for the two clock labels (~36 dp each) and their gaps.
    progress_w = assigns.screen_w - 2 * 24 - 2 * 46

    frame = %{
      song: assigns.song,
      t_ms: assigns.t_ms,
      width: assigns.screen_w,
      height: canvas_h,
      semitone: Style.semitone_dp(assigns.screen_h),
      center_midi: assigns.center_midi,
      trace: assigns.trace,
      feedback: assigns.feedback,
      now_ms: round(assigns.t_ms)
    }

    restart = {self(), :restart}
    back = {self(), :back_bar}
    play = {self(), :play_pause}
    loop = {self(), :loop}
    volume = {self(), :volume}

    ~MOB"""
    <Column background={Style.bg()} fill_height={true}>
      {header(assigns)}
      <Canvas width={assigns.screen_w} height={canvas_h} draw={PracticeView.ops(frame)} />
      <Column padding_left={24} padding_right={24} padding_top={8} gap={14}>
        <Row align={:center}>
          <Text
            text={clock(assigns.t_ms)}
            text_size={Style.type(:subtitle)}
            text_color={Style.text_tertiary()}
          />
          <Spacer />
          <Canvas
            width={progress_w}
            height={24}
            draw={ControlsView.progress(progress_w, progress_fraction(assigns), loop_fraction(assigns))}
          />
          <Spacer />
          <Text
            text={clock(Song.duration_ms(assigns.song))}
            text_size={Style.type(:subtitle)}
            text_color={Style.text_tertiary()}
          />
        </Row>
        <Row align={:center}>
          <Canvas
            width={ControlsView.size()}
            height={ControlsView.size()}
            draw={ControlsView.control(:restart, "Restart")}
            on_tap={restart}
          />
          <Spacer />
          <Canvas
            width={ControlsView.size()}
            height={ControlsView.size()}
            draw={ControlsView.control(:back_bar, "−1 bar")}
            on_tap={back}
          />
          <Spacer />
          <Canvas
            width={ControlsView.play_size()}
            height={ControlsView.play_size()}
            draw={ControlsView.play_button(assigns.playing)}
            on_tap={play}
          />
          <Spacer />
          <Canvas
            width={ControlsView.size()}
            height={ControlsView.size()}
            draw={ControlsView.control(:loop, loop_caption(assigns.song), assigns.loop)}
            on_tap={loop}
          />
          <Spacer />
          <Canvas
            width={ControlsView.size()}
            height={ControlsView.size()}
            draw={ControlsView.control(:volume, "Accomp #{assigns.volume}")}
            on_tap={volume}
          />
        </Row>
      </Column>
    </Column>
    """
  end

  defp header(assigns) do
    song = assigns.song
    header_height = @header_height
    back_tap = {self(), :back}
    track_tap = {self(), :track}
    settings_tap = {self(), :settings}
    pill = part_name(song.part) <> " · " <> track_label(assigns.track_mode)

    ~MOB"""
    <Row height={header_height} padding_left={8} padding_right={20} align={:center}>
      <Text
        text="‹"
        on_tap={back_tap}
        text_size={30}
        text_color={Style.text_secondary()}
        padding_left={8}
        padding_right={10}
      />
      <Column weight={1}>
        <Text
          text={song.title}
          text_size={Style.type(:title)}
          text_color={Style.text_primary()}
          font_weight="bold"
          max_lines={1}
        />
        <Text
          text={subtitle(assigns)}
          text_size={Style.type(:subtitle)}
          text_color={Style.text_tertiary()}
          max_lines={1}
        />
      </Column>
      <Box
        background={0x24FFFFFF}
        corner_radius={16}
        padding={8}
        fill_width={false}
        on_tap={track_tap}
      >
        <Text
          text={"● " <> pill}
          text_size={Style.type(:status)}
          text_color={Style.text_primary()}
          font_weight="bold"
        />
      </Box>
      <Spacer size={8} />
      <Canvas width={32} height={32} draw={ControlsView.gear(32)} on_tap={settings_tap} />
    </Row>
    """
  end

  @doc false
  # The header's second line: what's wrong if anything is, else the song facts.
  def subtitle(%{audio_status: :loading}), do: "Loading the track…"

  def subtitle(%{audio_status: {:error, reason}}),
    do: "Can't play this track (#{inspect(reason)})"

  def subtitle(%{mic: :denied}), do: "Microphone off: allow it in Settings for feedback"
  def subtitle(%{listening: {:error, reason}}), do: "Microphone unavailable (#{inspect(reason)})"
  def subtitle(%{listening: :playback}), do: "Test mode: listening to the track itself"

  def subtitle(%{song: song}) do
    "Bars #{hd(song.bars).number}–#{List.last(song.bars).number} · #{Song.key_name(song)} · ♩ = #{round(song.tempo_bpm)}"
  end

  # ── Events ───────────────────────────────────────────────────────────────

  def handle_info({:tap, :back}, socket) do
    {:noreply, Mob.Socket.pop_screen(socket)}
  end

  def handle_info({:tap, :play_pause}, socket) do
    if socket.assigns.playing, do: {:noreply, pause(socket)}, else: {:noreply, play(socket)}
  end

  def handle_info({:tap, :restart}, socket) do
    {:noreply, socket |> Mob.Socket.assign(:t_ms, loop_start(socket.assigns)) |> play()}
  end

  def handle_info({:tap, :back_bar}, socket) do
    a = socket.assigns
    bar = Song.bar_at(a.song, a.t_ms)
    previous = Song.bar_before(a.song, bar.number)
    # Within the first beat of a bar, step to the previous bar's start.
    target =
      if a.t_ms - bar.start_ms < bar.dur_ms / bar.beats,
        do: if(previous, do: previous.start_ms, else: bar.start_ms),
        else: bar.start_ms

    {:noreply, seek(socket, target)}
  end

  def handle_info({:tap, :loop}, socket) do
    {:noreply, Mob.Socket.assign(socket, :loop, not socket.assigns.loop)}
  end

  def handle_info({:tap, :volume}, socket) do
    socket = Mob.Socket.assign(socket, :volume, next_volume(socket.assigns.volume))
    {:noreply, apply_mix(socket)}
  end

  def handle_info({:tap, :track}, socket) do
    a = socket.assigns
    modes = Enum.filter(@track_modes, &Map.has_key?(a.tracks, &1))
    next = Enum.at(modes, rem(Enum.find_index(modes, &(&1 == a.track_mode)) + 1, length(modes)))
    resume = if a.playing, do: a.t_ms
    socket = if a.playing, do: pause(socket), else: socket

    {:noreply,
     Mob.Socket.assign(socket,
       track_mode: next,
       audio: a.engine.load(socket.assigns.audio, a.tracks[next]),
       audio_status: :loading,
       listening: :off,
       resume_at: resume
     )}
  end

  def handle_info({:choir_audio, :ready, _info}, socket) do
    socket = socket |> Mob.Socket.assign(:audio_status, :ready) |> apply_mix() |> maybe_listen()

    case socket.assigns.resume_at do
      nil -> {:noreply, socket}
      t -> {:noreply, socket |> Mob.Socket.assign(t_ms: t, resume_at: nil) |> play()}
    end
  end

  def handle_info({:choir_audio, :decoded, _info}, socket), do: {:noreply, socket}

  def handle_info({:choir_audio, :load_error, reason}, socket) do
    {:noreply, Mob.Socket.assign(socket, :audio_status, {:error, reason})}
  end

  def handle_info({:permission, :microphone, result}, socket) do
    {:noreply, socket |> Mob.Socket.assign(:mic, result) |> maybe_listen()}
  end

  # The gear: pause (nothing to watch while adjusting) and open settings,
  # which report changes straight back here.
  def handle_info({:tap, :settings}, socket) do
    socket = if socket.assigns.playing, do: pause(socket), else: socket
    {:noreply, Mob.Socket.push_screen(socket, SettingsScreen, %{practice: self()})}
  end

  def handle_info({:mic_delay, ms}, socket) when is_number(ms) do
    a = socket.assigns
    {:noreply, Mob.Socket.assign(socket, :audio, a.engine.set_mic_delay(a.audio, ms))}
  end

  # Jump to a song time (ms), keeping play / pause as it is.
  def handle_info({:seek, ms}, socket) when is_number(ms) do
    {:noreply, seek(socket, max(ms * 1.0, 0.0))}
  end

  # Device test hook: analyse the track itself instead of the microphone
  # (`send(pid, {:listen, :playback})`), or go back to `:mic`.
  def handle_info({:listen, source}, socket) when source in [:mic, :playback] do
    {:noreply, listen(socket, source)}
  end

  def handle_info(:tick, socket) do
    socket = Mob.Socket.assign(socket, :tick_timer, nil)

    if socket.assigns.playing do
      {:noreply, socket |> advance() |> schedule_tick()}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # Leaving the song (back, or the system back gesture): the engine is one
  # per app, so stop the music and the microphone here, or they run on
  # under the song list; and let the screen sleep again.
  def terminate(_reason, socket) do
    a = socket.assigns

    if a[:audio] do
      keep_awake(false)
      a.engine.stop(a.audio)
    end

    :ok
  end

  # ── Playback ─────────────────────────────────────────────────────────────

  defp play(%{assigns: %{audio_status: status}} = socket) when status != :ready, do: socket

  defp play(socket) do
    a = socket.assigns
    start = if a.t_ms >= Song.duration_ms(a.song), do: loop_start(a), else: a.t_ms

    case a.engine.play(a.audio, start) do
      {:ok, audio} ->
        keep_awake(true)

        socket
        |> Mob.Socket.assign(audio: audio, playing: true, t_ms: start)
        |> reset_trace()
        |> schedule_tick()

      {:error, reason, audio} ->
        Mob.Socket.assign(socket, audio: audio, audio_status: {:error, reason})
    end
  end

  defp pause(socket) do
    a = socket.assigns
    keep_awake(false)
    audio = a.engine.pause(a.audio)

    socket
    |> cancel_tick()
    |> Mob.Socket.assign(audio: audio, playing: false)
  end

  defp seek(socket, t) do
    if socket.assigns.playing,
      do: socket |> Mob.Socket.assign(:t_ms, t) |> play(),
      else: socket |> Mob.Socket.assign(:t_ms, t) |> reset_trace()
  end

  defp reset_trace(socket), do: Mob.Socket.assign(socket, trace: [], feedback: Feedback.new())

  defp apply_mix(socket) do
    a = socket.assigns
    Mob.Socket.assign(socket, :audio, a.engine.set_mix(a.audio, 1.0, a.volume / 100))
  end

  defp request_microphone(socket) do
    if device_calls?(),
      do: Mob.Permissions.request(socket, :microphone),
      else: Mob.Socket.assign(socket, :mic, :granted)
  end

  defp maybe_listen(%{assigns: %{audio_status: :ready, mic: :granted, listening: :off}} = socket),
    do: listen(socket, :mic)

  defp maybe_listen(socket), do: socket

  defp listen(socket, source) do
    a = socket.assigns

    case a.engine.listen(a.audio, source) do
      {:ok, audio} ->
        Mob.Socket.assign(socket, audio: audio, listening: source)

      {:error, reason, audio} ->
        Mob.Socket.assign(socket, audio: audio, listening: {:error, reason})
    end
  end

  @doc false
  # One frame: read the position, wrap or stop at the end, take the readings,
  # smooth. The engine reporting paused while we play means the output went
  # away (headphones unplugged, Bluetooth dropped): show it paused there;
  # play reopens it.
  def advance(socket) do
    a = socket.assigns
    {status, t} = a.engine.position(a.audio)
    duration = Song.duration_ms(a.song)

    cond do
      status == :paused ->
        socket |> pause() |> Mob.Socket.assign(:t_ms, t)

      t >= duration and a.loop ->
        socket |> Mob.Socket.assign(:t_ms, loop_start(a)) |> play()

      t >= duration ->
        socket |> pause() |> Mob.Socket.assign(:t_ms, duration)

      true ->
        step(socket, t)
    end
  end

  defp step(socket, t) do
    a = socket.assigns
    {readings, audio} = a.engine.readings(a.audio)
    keep_from = t - Style.past_seconds() * 1000 - 100

    trace =
      Enum.drop_while(a.trace ++ align_readings(a.song, readings), fn {ts, _m, _c} ->
        ts < keep_from
      end)

    dt = max(t - a.t_ms, 0.0)

    Mob.Socket.assign(socket,
      audio: audio,
      t_ms: t,
      trace: trace,
      feedback: smooth(a.feedback, current_cents(a.song, trace, t), t),
      center_midi: recentre(a.center_midi, a.song, t, dt),
      frames: a.frames + 1
    )
  end

  @doc false
  # Readings as the screen uses them:
  #   * more than 120 ms from any written note is treated as
  #     silence — whatever was heard (accompaniment bleed, a cough) isn't the
  #     part being sung;
  #   * 9½ or more semitones from the nearby note is an octave slip — the
  #     detector's, or a bass dropping to the octave below — so it's moved by
  #     whole octaves to the copy nearest the written note. Wrong notes (a
  #     few semitones off) are left alone.
  def align_readings(song, readings) do
    Enum.map(readings, fn
      {ts, midi, conf} = reading when is_number(midi) ->
        case Song.note_near(song, ts, @note_margin_ms) do
          nil ->
            {ts, nil, 0.0}

          %{midi: written} when abs(midi - written) >= 9.5 ->
            {ts, midi - 12 * round((midi - written) / 12), conf}

          _ ->
            reading
        end

      reading ->
        reading
    end)
  end

  @doc false
  # Error of the latest confident reading (from the last 150 ms, so
  # one unsure reading isn't taken for a breath) against the note sung when
  # it was taken; nil in rests or when nothing confident has been heard.
  # `:stale` when that reading predates the note now sounding (the frame
  # landed on a note change): the smoother holds its state rather than
  # reading a several-semitone miss.
  def current_cents(song, trace, t) do
    with %{} = note <- Song.note_at(song, t),
         {ts, midi, _conf} <- latest_voiced(trace, t - @dropout_ms) do
      if Song.note_at(song, ts) == note, do: Pitch.cents(midi, note.midi), else: :stale
    else
      _ -> nil
    end
  end

  defp latest_voiced(trace, since) do
    trace
    |> Enum.reverse()
    |> Enum.take_while(fn {ts, _m, _c} -> ts >= since end)
    |> Enum.find(fn {_ts, midi, conf} -> is_number(midi) and conf >= 0.2 end)
  end

  defp smooth(feedback, :stale, _t), do: feedback
  defp smooth(feedback, cents, t), do: Feedback.update(feedback, cents, round(t))

  # Ease the roll's vertical centre toward the note being sung (or the next one).
  defp recentre(center, song, t, dt) do
    case Song.note_at(song, t) || Song.next_note(song, t) do
      nil -> center
      note -> center + (note.midi - center) * (1.0 - :math.exp(-dt / @recentre_tau_ms))
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

  # At most one tick is ever pending: playing while already playing (restart)
  # must not start a second frame loop.
  defp schedule_tick(%{assigns: %{playing: true, tick_timer: nil}} = socket) do
    Mob.Socket.assign(socket, :tick_timer, Process.send_after(self(), :tick, @frame_ms))
  end

  defp schedule_tick(socket), do: socket

  defp cancel_tick(%{assigns: %{tick_timer: nil}} = socket), do: socket

  defp cancel_tick(socket) do
    Process.cancel_timer(socket.assigns.tick_timer)
    Mob.Socket.assign(socket, :tick_timer, nil)
  end

  defp loop_start(_assigns), do: 0.0

  defp canvas_height(assigns, sa) do
    max(assigns.screen_h - sa.top - sa.bottom - @header_height - @controls_height, 320.0)
  end

  defp progress_fraction(a), do: a.t_ms / Song.duration_ms(a.song)

  defp loop_fraction(%{loop: false}), do: nil
  defp loop_fraction(%{loop: true}), do: {0.0, 1.0}

  defp loop_caption(song), do: "#{hd(song.bars).number}–#{List.last(song.bars).number}"

  defp next_volume(v) do
    i = Enum.find_index(@volume_steps, &(&1 == v)) || 0
    Enum.at(@volume_steps, rem(i + 1, length(@volume_steps)))
  end

  defp track_label(:piano), do: "Piano"
  defp track_label(:rehearsal), do: "Rehearsal"
  defp track_label(:split), do: "Choir"
  defp track_label(:demo), do: "Demo"

  defp part_name(:bass), do: "Bass"
  defp part_name(part), do: part |> Atom.to_string() |> String.capitalize()

  defp clock(ms) do
    s = trunc(max(ms, 0) / 1000)
    "#{div(s, 60)}:#{s |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")}"
  end

  defp device_calls?, do: Application.get_env(:choir_coach, :device_calls, true)

  defp keep_awake(on?) do
    if device_calls?(), do: Mob.Device.keep_awake(on?)
    :ok
  end

  defp screen_size do
    if device_calls?() do
      %{width: w, height: h} = :mob_nif.screen_info()
      {w * 1.0, h * 1.0}
    else
      @fallback_screen
    end
  end
end
