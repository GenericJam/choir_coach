defmodule ChoirCoach.PracticeScreen do
  @moduledoc """
  The live practice screen for one song section.

  Playback is a clock: song time = position when play was pressed + time
  since. While playing, a frame tick reads the clock, appends the pitch
  readings since the last frame to the trace, advances the feedback smoother
  and re-renders. Readings come from `ChoirCoach.FakeSinger` until the audio
  engine supplies real ones; the trace format is the same either way.

  Controls: restart, back one bar, play / pause, loop the section, and the
  accompaniment level (kept here for the audio engine; no audio plays yet).
  """

  use Mob.Screen

  alias ChoirCoach.{ControlsView, FakeSinger, Feedback, Pitch, PracticeView, Song, Style}
  alias ChoirCoach.Songs.GloriousNight

  @frame_ms 33
  @sample_ms 10
  @recentre_tau_ms 150.0
  @header_height 55
  @controls_height 150
  @volume_steps [100, 70, 40, 0]
  # Reference artboard, used where the device can't be asked (host tests).
  @fallback_screen {390.0, 844.0}

  def mount(params, _session, socket) do
    song = Map.get_lazy(params, :song, &GloriousNight.verse_excerpt/0)
    {w, h} = Map.get_lazy(params, :screen, &screen_size/0)
    first = hd(song.notes)

    {:ok,
     Mob.Socket.assign(socket,
       song: song,
       screen_w: w,
       screen_h: h,
       playing: false,
       base_ms: 0.0,
       started_at: nil,
       t_ms: 0.0,
       trace: [],
       sampled_to: -@sample_ms * 1.0,
       feedback: Feedback.new(),
       center_midi: first.midi * 1.0,
       loop: true,
       volume: 70,
       frames: 0,
       tick_timer: nil
     )}
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
    first = hd(song.bars).number
    last = List.last(song.bars).number
    subtitle = "Bars #{first}–#{last} · #{song.key_name} · ♩ = #{song.tempo_bpm}"
    header_height = @header_height

    ~MOB"""
    <Row height={header_height} padding_left={20} padding_right={20} align={:center}>
      <Column weight={1}>
        <Text
          text={song.title}
          text_size={Style.type(:title)}
          text_color={Style.text_primary()}
          font_weight="bold"
          max_lines={1}
        />
        <Text
          text={subtitle}
          text_size={Style.type(:subtitle)}
          text_color={Style.text_tertiary()}
          max_lines={1}
        />
      </Column>
      <Box background={0x24FFFFFF} corner_radius={16} padding={8} fill_width={false}>
        <Text
          text={"● " <> part_name(song.part)}
          text_size={Style.type(:status)}
          text_color={Style.text_primary()}
          font_weight="bold"
        />
      </Box>
    </Row>
    """
  end

  # ── Events ───────────────────────────────────────────────────────────────

  def handle_info({:tap, :play_pause}, socket) do
    if socket.assigns.playing, do: {:noreply, pause(socket)}, else: {:noreply, play(socket)}
  end

  def handle_info({:tap, :restart}, socket) do
    {:noreply, socket |> seek(loop_start(socket.assigns)) |> play()}
  end

  def handle_info({:tap, :back_bar}, socket) do
    a = socket.assigns
    t = current_ms(a)
    bar = Song.bar_at(a.song, t)
    # Within the first beat of a bar, step to the previous bar's start.
    target =
      if t - bar.start_ms < Song.beat_ms(a.song),
        do: max(bar.start_ms - a.song.beats_per_bar * Song.beat_ms(a.song), 0.0),
        else: bar.start_ms

    {:noreply, seek(socket, target)}
  end

  def handle_info({:tap, :loop}, socket) do
    {:noreply, Mob.Socket.assign(socket, :loop, not socket.assigns.loop)}
  end

  def handle_info({:tap, :volume}, socket) do
    {:noreply, Mob.Socket.assign(socket, :volume, next_volume(socket.assigns.volume))}
  end

  def handle_info(:tick, socket) do
    socket = Mob.Socket.assign(socket, :tick_timer, nil)

    if socket.assigns.playing do
      {:noreply, socket |> advance(now_ms()) |> schedule_tick()}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # ── Clock ────────────────────────────────────────────────────────────────

  defp play(socket) do
    a = socket.assigns
    start = if a.t_ms >= Song.duration_ms(a.song), do: loop_start(a), else: a.t_ms
    keep_awake(true)

    socket
    |> Mob.Socket.assign(playing: true, base_ms: start, started_at: now_ms(), t_ms: start)
    |> reset_trace(start)
    |> schedule_tick()
  end

  defp pause(socket) do
    keep_awake(false)
    t = current_ms(socket.assigns)

    socket
    |> cancel_tick()
    |> Mob.Socket.assign(playing: false, base_ms: t, started_at: nil, t_ms: t)
  end

  defp seek(socket, t) do
    started = if socket.assigns.playing, do: now_ms(), else: nil

    socket
    |> Mob.Socket.assign(base_ms: t, started_at: started, t_ms: t)
    |> reset_trace(t)
  end

  defp reset_trace(socket, t) do
    Mob.Socket.assign(socket, trace: [], sampled_to: t - @sample_ms, feedback: Feedback.new())
  end

  defp current_ms(%{playing: true, base_ms: base, started_at: started}),
    do: base + (now_ms() - started)

  defp current_ms(%{t_ms: t}), do: t

  @doc false
  # One frame: read the clock, wrap or stop at the end, sample, smooth.
  def advance(socket, now) do
    a = socket.assigns
    t = a.base_ms + (now - a.started_at)
    duration = Song.duration_ms(a.song)

    cond do
      t >= duration and a.loop ->
        start = loop_start(a)

        socket
        |> Mob.Socket.assign(base_ms: start, started_at: now, t_ms: start)
        |> reset_trace(start)

      t >= duration ->
        keep_awake(false)

        Mob.Socket.assign(socket,
          playing: false,
          base_ms: duration,
          started_at: nil,
          t_ms: duration
        )

      true ->
        step(socket, t)
    end
  end

  defp step(socket, t) do
    a = socket.assigns
    {trace, sampled_to} = sample_until(a.song, a.trace, a.sampled_to, t)
    keep_from = t - Style.past_seconds() * 1000 - 100
    trace = Enum.drop_while(trace, fn {ts, _m, _c} -> ts < keep_from end)
    dt = max(t - a.t_ms, 0.0)

    Mob.Socket.assign(socket,
      t_ms: t,
      trace: trace,
      sampled_to: sampled_to,
      feedback: smooth(a.feedback, current_cents(a.song, trace, t), t),
      center_midi: recentre(a.center_midi, a.song, t, dt),
      frames: a.frames + 1
    )
  end

  defp sample_until(song, trace, sampled_to, t) do
    times =
      Stream.iterate(sampled_to + @sample_ms, &(&1 + @sample_ms)) |> Enum.take_while(&(&1 <= t))

    new =
      Enum.map(times, fn ts ->
        case FakeSinger.sample(song, ts) do
          nil -> {ts, nil, 0.0}
          %{midi: m, confidence: c} -> {ts, m, c}
        end
      end)

    {trace ++ new, List.last(times) || sampled_to}
  end

  @doc false
  # Error of the latest confident reading against the note sung when it was
  # taken; nil in rests or when nothing confident is heard. `:stale` when the
  # reading predates the note now sounding (the frame landed on a note
  # change): the smoother holds its state rather than reading a
  # several-semitone miss or a one-frame silence.
  def current_cents(song, trace, t) do
    with %{} = note <- Song.note_at(song, t),
         {ts, midi, conf} when is_number(midi) and conf >= 0.2 <- List.last(trace) do
      if Song.note_at(song, ts) == note, do: Pitch.cents(midi, note.midi), else: :stale
    else
      _ -> nil
    end
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

  defp now_ms, do: System.monotonic_time(:millisecond)

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

  defp part_name(:bass), do: "Bass"
  defp part_name(part), do: part |> Atom.to_string() |> String.capitalize()

  defp clock(ms) do
    s = trunc(ms / 1000)
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
