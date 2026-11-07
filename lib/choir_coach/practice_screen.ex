defmodule ChoirCoach.PracticeScreen do
  @moduledoc """
  The live practice screen: plays a rehearsal track, listens to the singer
  and draws how their pitch compares with the written part.

  Sound and pitch come from a `ChoirCoach.Audio` engine kept in the
  assigns. While playing, a ~30 fps frame tick reads the engine's position
  (the song time being heard), drains the pitch readings since the last
  frame into the trace, advances the feedback smoother and re-renders.

  Controls: restart, back one bar, play / pause, forward one bar, loop the
  song, and Mix, which opens "What you hear" over the roll (the staff and a
  status line stay live): presets, each source's level and balance, and the
  ear map. Dragging the progress track scrubs: playback pauses while the
  finger moves and plays on from where it's let go.
  The header's switch (the singer's part | Melody) changes the part at the same song time;
  the headphones icon opens `ChoirCoach.AudioScreen`. On a tablet "What you
  hear" is docked below the transport instead (see "Tablet").
  """

  use Mob.Screen

  alias ChoirCoach.{
    Audio,
    AudioScreen,
    ControlsView,
    Feedback,
    Mix,
    MixView,
    Pitch,
    PracticeView,
    Settings,
    Song,
    Style,
    Window
  }

  @frame_ms 33
  @recentre_tau_ms 150.0
  # A reading this close to a written note counts for it (an early or late
  # entry); further away it's not the part being sung.
  @note_margin_ms 120
  # Silence shorter than this (one unsure reading) isn't a breath.
  @dropout_ms 150
  @header_height 96
  @controls_height 166
  # Outputs worth measuring a delay for (headphones, wired or not; the
  # Bluetooth call route once the singer picks the headset microphone).
  @headphone_kinds [:bluetooth, :bluetooth_sco, :usb, :wired_headset, :wired_headphones]
  # Outputs that play one channel: the phone's speakers and the call route.
  @mono_kinds [:speaker, :earpiece, :bluetooth_sco]
  # Engine busy with nobody on loan to wait for: try again after this.
  @retry_ms 500
  # The tablet layout (see "Tablet"), in dp.
  @tablet_header_h 80
  @tablet_transport_h 106
  @tablet_gap 10
  @tablet_clock_w 52
  @dock_margin 12
  @dock_padding 16
  @dock_gap 12
  # The dock's first line: "What you hear" (this wide) and the preset chips.
  @dock_title_w 186
  @chip_h 46
  @chip_gap 8
  # A roll shorter than this under the staff shows its status on one line.
  @cluster_min_roll 300
  # Strips are laid out for three mix rows (a part's), so the dock keeps its
  # height when the melody (two rows) is switched to.
  @strip_slots 3
  @strip_gap 12
  @strip_padding 14
  @strip_stack_below 300
  # What a strip's content takes on iOS, with a little to spare.
  @strip_stacked_h 244
  @strip_lines_h 152
  # The tablet layout only where it fits: a progress track at least this
  # wide, and a canvas at least this tall.
  @min_progress_w 120
  @min_canvas_h 320.0

  def mount(params, _session, socket) do
    # `parts`: the singer's part and the melody, each with its song and
    # tracks (`ChoirCoach.Songs.parts/2`).
    parts = Map.fetch!(params, :parts)
    part = Map.get(params, :part, parts |> hd() |> elem(0))
    %{song: song, tracks: tracks} = Keyword.fetch!(parts, part)
    engine = Audio.engine()
    mix = Settings.mix(part) || Mix.new(part, tracks)
    first = hd(song.notes)
    audio = engine.new(song)
    devices = engine.devices(audio)

    socket =
      Mob.Socket.assign(socket,
        parts: parts,
        part: part,
        song: song,
        tracks: tracks,
        mix: mix,
        mix_open: false,
        open_row: nil,
        engine: engine,
        audio: audio,
        # Whether this screen holds the engine; while it doesn't it makes no
        # engine call and waits for the lease (see "Engine hand-over").
        attached: false,
        output_pref: Settings.output_pref(devices),
        input_pref: Settings.input_pref(devices),
        output: nil,
        mono: false,
        mic_delay: 0,
        audio_status: :loading,
        resume_at: nil,
        # While the progress track is dragged: whether to play on release.
        scrub: nil,
        mic: :unknown,
        listening: :off,
        # What to listen to whenever a track is ready: the mic, or the track
        # itself in test mode.
        listen_source: :mic,
        playing: false,
        t_ms: 0.0,
        trace: [],
        feedback: Feedback.new(),
        center_midi: first.midi * 1.0,
        loop: true,
        frames: 0,
        tick_timer: nil
      )
      |> Window.assign(Window.size(params), &layout_of/1)
      |> refresh_output()
      |> attach()

    # Rotations, and the app going to the background (`:app`), where a
    # tablet saves its docked mix.
    Window.follow([:app])
    {:ok, request_microphone(socket)}
  end

  # Phones (and windows too small for it) keep the phone's design; a tablet
  # (`layout_of/1`) docks the mixer below the roll.
  def render(assigns) do
    case assigns.layout do
      :tablet -> render_tablet(assigns)
      :phone -> render_phone(assigns)
    end
  end

  # The tablet layout for a regular-by-regular window (`Style.layout/1`)
  # whose screen holds it: its transport keeps a usable progress track and
  # its canvas the phone's minimum height, with the dock at its tallest (all
  # chips showing).
  defp layout_of(assigns) do
    fits =
      tablet_progress_width(assigns.screen_w) >= @min_progress_w and
        tablet_canvas_height(assigns, all_chip_labels()) >= @min_canvas_h

    if Style.layout(assigns[:size_class]) == :tablet and fits, do: :tablet, else: :phone
  end

  defp render_phone(assigns) do
    sa = Map.get(assigns, :safe_area, %{top: 0.0, bottom: 0.0})
    progress_w = progress_width(assigns)
    # Restart, −1 bar, +1 bar, loop and Mix share the row with play, with
    # fixed gaps between them: a flexible Spacer keeps a minimum width on iOS
    # (~8 pt), so five of them overflowed the row and iOS centred it,
    # cutting off the left edge of the whole screen.
    row_w = assigns.screen_w - 2 * 24
    ctl_w = ControlsView.control_width(row_w, 5)
    ctl_h = ControlsView.size()
    gap = max(Float.floor((row_w - 5 * ctl_w - ControlsView.play_size()) / 5 * 1.0, 1), 0.0)

    frame = %{
      song: assigns.song,
      t_ms: assigns.t_ms,
      width: assigns.screen_w,
      height: canvas_height(assigns, sa),
      semitone: Style.semitone_dp(assigns.screen_h),
      center_midi: assigns.center_midi,
      trace: assigns.trace,
      feedback: assigns.feedback,
      now_ms: round(assigns.t_ms)
    }

    restart = {self(), :restart}
    back = {self(), :back_bar}
    forward = {self(), :forward_bar}
    play = {self(), :play_pause}
    loop = {self(), :loop}
    mix = {self(), :mix}
    # Scrubbing re-renders the roll: ~20 updates a second is smooth enough.
    scrub = {self(), :scrub, [throttle: 50]}

    ~MOB"""
    <Column background={Style.bg()} fill_height={true}>
      {header(assigns)}
      {stage(assigns, frame)}
      <Column padding_left={24} padding_right={24} padding_top={8} gap={14}>
        <Row align={:center}>
          <Text
            text={clock(assigns.t_ms)}
            text_size={Style.type(:subtitle)}
            text_color={Style.text_tertiary()}
          />
          <Spacer />
          <Canvas
            id="progress"
            width={progress_w}
            height={ControlsView.progress_height()}
            draw={ControlsView.progress(progress_w, progress_fraction(assigns), loop_fraction(assigns))}
            on_drag={scrub}
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
            id="ctl_restart"
            width={ctl_w}
            height={ctl_h}
            draw={ControlsView.control(:restart, "Restart", false, ctl_w)}
            on_tap={restart}
            on_press_out={held()}
          />
          <Spacer size={gap} />
          <Canvas
            id="ctl_back_bar"
            width={ctl_w}
            height={ctl_h}
            draw={ControlsView.control(:back_bar, "−1 bar", false, ctl_w)}
            on_tap={back}
            on_press_out={held()}
          />
          <Spacer size={gap} />
          <Canvas
            id="ctl_play"
            width={ControlsView.play_size()}
            height={ControlsView.play_size()}
            draw={ControlsView.play_button(shows_pause?(assigns))}
            on_tap={play}
            on_press_out={held()}
          />
          <Spacer size={gap} />
          <Canvas
            id="ctl_forward_bar"
            width={ctl_w}
            height={ctl_h}
            draw={ControlsView.control(:forward_bar, "+1 bar", false, ctl_w)}
            on_tap={forward}
            on_press_out={held()}
          />
          <Spacer size={gap} />
          <Canvas
            id="ctl_loop"
            width={ctl_w}
            height={ctl_h}
            draw={ControlsView.control(:loop, loop_caption(assigns.song), assigns.loop, ctl_w)}
            on_tap={loop}
            on_press_out={held()}
          />
          <Spacer size={gap} />
          <Canvas
            id="ctl_mix"
            width={ctl_w}
            height={ctl_h}
            draw={ControlsView.control(:mix, Mix.caption(assigns.mix), assigns.mix_open, ctl_w)}
            on_tap={mix}
            on_press_out={held()}
          />
        </Row>
      </Column>
    </Column>
    """
  end

  # ── Tablet ───────────────────────────────────────────────────────────────
  #
  # One header row (title and facts; the part switch and the headphones on
  # the right), the staff and roll across the width at the phone's time scale
  # (more of the song shows, not the same seconds stretched), one transport
  # row with the progress track inline, and "What you hear" docked below:
  # the presets and one channel strip per mix row, always visible. No ear
  # map: the strips show every level and balance, and the roll needs the
  # height (landscape especially). Chrome is `Style.ui/2`-sized.

  defp render_tablet(assigns) do
    # Once a frame: it reads the saved "My mix".
    chips = chip_specs(assigns)
    m = tablet_metrics(assigns, chips)

    frame = %{
      song: assigns.song,
      t_ms: assigns.t_ms,
      width: assigns.screen_w,
      time_width: time_width(assigns),
      status_band: m.status_band,
      height: m.canvas_h,
      semitone: m.semitone,
      center_midi: assigns.center_midi,
      trace: assigns.trace,
      feedback: assigns.feedback,
      now_ms: round(assigns.t_ms)
    }

    ~MOB"""
    <Column background={Style.bg()} fill_height={true}>
      {tablet_header(assigns)}
      <Canvas width={frame.width} height={frame.height} draw={PracticeView.ops(frame)} />
      {tablet_transport(assigns, m)}
      {mix_dock(assigns, chips, m)}
    </Column>
    """
  end

  # Heights and widths of the tablet layout (dp). The header, transport and
  # dock have fixed heights, so the canvas takes exactly the rest.
  defp tablet_metrics(assigns, chips) do
    {stacked, strip_h} = strip_form(assigns.screen_w)
    labels = for {label, _tap, _selected} <- chips, do: label
    canvas_h = tablet_canvas_height(assigns, labels)

    # A short roll (landscape) can't hold the big lyric and note clear of
    # the notes and trace: its status goes on one line under the staff.
    status_band = canvas_h - PracticeView.staff_height() < @cluster_min_roll

    roll_top =
      if status_band, do: PracticeView.compact_height(), else: PracticeView.staff_height()

    %{
      canvas_h: canvas_h,
      status_band: status_band,
      # About nine semitones over the roll, between 28 and 40 dp each.
      semitone: ((canvas_h - roll_top) / 9) |> min(40.0) |> max(28.0),
      ctl: Style.ui(ControlsView.size(), :tablet),
      play: Style.ui(ControlsView.play_size(), :tablet),
      progress_w: tablet_progress_width(assigns.screen_w),
      transport_h: @tablet_transport_h,
      stacked: stacked,
      strip_h: strip_h,
      strip_gap: @strip_gap,
      strip_padding: @strip_padding,
      dock_margin: @dock_margin,
      dock_padding: @dock_padding,
      dock_gap: @dock_gap,
      chips_h: chips_height(assigns.screen_w, labels),
      chip_h: @chip_h,
      chip_gap: @chip_gap,
      title_w: @dock_title_w
    }
  end

  # What the header, transport and dock (with chips `labels`) leave the
  # canvas.
  defp tablet_canvas_height(assigns, labels) do
    sa = Map.get(assigns, :safe_area, %{top: 0.0, bottom: 0.0})
    {_stacked, strip_h} = strip_form(assigns.screen_w)
    dock_h = 2 * @dock_padding + chips_height(assigns.screen_w, labels) + @dock_gap + strip_h

    assigns.screen_h - sa.top - sa.bottom - @tablet_header_h - @tablet_transport_h - dock_h -
      @dock_margin
  end

  # Narrow strips (portrait) stack each control under its name; wide ones
  # (landscape) give each control one line, which keeps the dock short.
  # {stacked, strip height}.
  defp strip_form(screen_w) do
    strip_w = (dock_inner_width(screen_w) - (@strip_slots - 1) * @strip_gap) / @strip_slots

    if strip_w - 2 * @strip_padding < @strip_stack_below,
      do: {true, @strip_stacked_h},
      else: {false, @strip_lines_h}
  end

  defp dock_inner_width(screen_w), do: screen_w - 2 * (@dock_margin + @dock_padding)

  # "What you hear" and the preset chips (`labels`) wrap onto a second line
  # when they don't fit one (portrait with Custom and Save showing).
  defp chips_height(screen_w, labels) do
    runs =
      chip_runs([@dock_title_w | Enum.map(labels, &chip_width/1)], dock_inner_width(screen_w))

    runs * @chip_h + (runs - 1) * @chip_gap
  end

  # Every chip that can show at once: Custom, Save and all the presets.
  defp all_chip_labels, do: ["Custom", "Save" | Enum.map(Mix.presets(nil, :saved), & &1.label)]

  # How many lines items `widths` wide take, `@chip_gap` apart, in `width`.
  defp chip_runs(widths, width) do
    widths
    |> Enum.reduce({1, nil}, fn
      w, {runs, nil} -> {runs, w}
      w, {runs, used} when used + @chip_gap + w <= width -> {runs, used + @chip_gap + w}
      w, {runs, _used} -> {runs + 1, w}
    end)
    |> elem(0)
  end

  # A chip's width, generously estimated from its label (bold system font
  # averages about half an em a character).
  defp chip_width(label),
    do: String.length(label) * Style.type(:status, :tablet) * 0.55 + 2 * Style.ui(16, :tablet)

  defp tablet_header(assigns) do
    back_tap = {self(), :back}
    audio_tap = {self(), :audio}

    ~MOB"""
    <Row height={80} align={:center} padding_left={8} padding_right={20} gap={12}>
      <Text
        id="nav_back"
        text="‹"
        on_tap={back_tap}
        on_press_out={held()}
        text_size={38}
        text_color={Style.text_secondary()}
        padding_left={8}
        padding_right={6}
      />
      <Column weight={1} gap={2}>
        <Text
          text={assigns.song.title}
          text_size={Style.ui(20, :tablet)}
          text_color={Style.text_primary()}
          font_weight="bold"
          max_lines={1}
        />
        <Text
          text={subtitle(assigns)}
          text_size={Style.type(:subtitle, :tablet)}
          text_color={if(assigns.offer_delay, do: Style.accent(), else: Style.text_tertiary())}
          font_weight={if(assigns.offer_delay, do: "bold", else: "normal")}
          max_lines={1}
          on_tap={if(assigns.offer_delay, do: audio_tap)}
          on_press_out={if(assigns.offer_delay, do: held())}
        />
      </Column>
      {part_switch(assigns, :tablet)}
      <Canvas
        id="audio_icon"
        width={44}
        height={44}
        draw={ControlsView.headphones(44)}
        on_tap={audio_tap}
        on_press_out={held()}
      />
    </Row>
    """
  end

  # Restart, −1 bar, play, +1 bar, loop, then the clocks around the progress
  # track, which takes the rest of the row.
  defp tablet_transport(assigns, m) do
    s = Style.ui_scale(:tablet)
    gap = @tablet_gap
    clock_w = @tablet_clock_w
    scrub = {self(), :scrub, [throttle: 50]}

    ~MOB"""
    <Row height={m.transport_h} align={:center} padding_left={24} padding_right={24}>
      <Canvas
        id="ctl_restart"
        width={m.ctl}
        height={m.ctl}
        draw={ControlsView.control(:restart, "Restart", false, m.ctl, s)}
        on_tap={{self(), :restart}}
        on_press_out={held()}
      />
      <Spacer size={gap} />
      <Canvas
        id="ctl_back_bar"
        width={m.ctl}
        height={m.ctl}
        draw={ControlsView.control(:back_bar, "−1 bar", false, m.ctl, s)}
        on_tap={{self(), :back_bar}}
        on_press_out={held()}
      />
      <Spacer size={gap} />
      <Canvas
        id="ctl_play"
        width={m.play}
        height={m.play}
        draw={ControlsView.play_button(shows_pause?(assigns), m.play / ControlsView.play_size())}
        on_tap={{self(), :play_pause}}
        on_press_out={held()}
      />
      <Spacer size={gap} />
      <Canvas
        id="ctl_forward_bar"
        width={m.ctl}
        height={m.ctl}
        draw={ControlsView.control(:forward_bar, "+1 bar", false, m.ctl, s)}
        on_tap={{self(), :forward_bar}}
        on_press_out={held()}
      />
      <Spacer size={gap} />
      <Canvas
        id="ctl_loop"
        width={m.ctl}
        height={m.ctl}
        draw={ControlsView.control(:loop, loop_caption(assigns.song), assigns.loop, m.ctl, s)}
        on_tap={{self(), :loop}}
        on_press_out={held()}
      />
      <Spacer size={16} />
      <Text
        text={clock(assigns.t_ms)}
        text_size={Style.type(:subtitle, :tablet)}
        text_color={Style.text_tertiary()}
        text_align="right"
        width={clock_w}
      />
      <Spacer size={8} />
      <Canvas
        id="progress"
        width={m.progress_w}
        height={ControlsView.progress_height()}
        draw={ControlsView.progress(m.progress_w, progress_fraction(assigns), loop_fraction(assigns))}
        on_drag={scrub}
      />
      <Spacer size={8} />
      <Text
        text={clock(Song.duration_ms(assigns.song))}
        text_size={Style.type(:subtitle, :tablet)}
        text_color={Style.text_tertiary()}
        width={clock_w}
      />
    </Row>
    """
  end

  # "What you hear", always open: the presets, then a strip per mix row (or,
  # for a whole recording, what it plays). Fixed heights sit on unpadded
  # nodes only: iOS adds padding outside a node's height.
  defp mix_dock(assigns, specs, m) do
    chips = for spec <- specs, do: chip(spec, :tablet)

    ~MOB"""
    <Column padding_left={m.dock_margin} padding_right={m.dock_margin} padding_bottom={m.dock_margin}>
      <Box background={Style.surface()} corner_radius={24}>
        <Column padding={m.dock_padding} gap={m.dock_gap}>
          <Column height={m.chips_h}>
            <Wrap spacing={m.chip_gap} run_spacing={m.chip_gap}>
              <Row width={m.title_w} height={m.chip_h} align={:center}>
                <Text
                  text="What you hear"
                  text_size={Style.ui(22, :tablet)}
                  text_color={Style.text_primary()}
                  font_weight="bold"
                  max_lines={1}
                />
              </Row>
              {chips}
            </Wrap>
          </Column>
          {dock_body(assigns, assigns.mix, m)}
        </Column>
      </Box>
    </Column>
    """
  end

  defp dock_body(_assigns, %{recording: rec}, m) when rec != nil do
    ~MOB"""
    <Column height={m.strip_h}>
      <Text
        text={"#{recording_name(rec)} plays the recording as it is. Pick Rehearsal or Me in right ear to set each source."}
        text_size={Style.type(:status, :tablet)}
        text_color={Style.text_tertiary()}
      />
    </Column>
    """
  end

  defp dock_body(assigns, mix, m) do
    strips = for row <- mix.rows, do: strip(assigns, row, m)

    ~MOB"""
    <Row height={m.strip_h} gap={m.strip_gap}>
      {strips}
    </Row>
    """
  end

  # One mix row as a channel strip: its swatch (tap: on / off), name and
  # detail, then its level and balance.
  defp strip(assigns, row, m) do
    toggle = {self(), {:toggle_row, row.id}}
    level = {self(), {:level, row.id}}
    balance = {self(), {:balance, row.id}}
    label_color = if row.on, do: Style.text_primary(), else: Style.text_tertiary()
    color = Style.swatch(assigns.part)

    swatch = ~MOB"""
    <Canvas
      id={"row_#{row.id}"}
      width={44}
      height={44}
      draw={MixView.swatch(assigns.part, row, 44)}
      on_tap={toggle}
      on_press_out={held()}
    />
    """

    controls =
      if m.stacked do
        ~MOB"""
        <Column align={:center} gap={4}>
          {swatch}
          <Text
            text={row.label}
            text_size={Style.ui(17, :tablet)}
            text_color={label_color}
            font_weight="bold"
            max_lines={1}
          />
          <Text
            text={row.detail}
            text_size={Style.type(:subtitle, :tablet)}
            text_color={Style.text_tertiary()}
            max_lines={1}
          />
          <Slider
            value={row.level * 1.0}
            min={0.0}
            max={100.0}
            on_change={level}
            color={color}
            fill_width={true}
          />
          {strip_value("Level #{row.level}")}
          {strip_balance(assigns, row, balance, color, :stacked)}
        </Column>
        """
      else
        ~MOB"""
        <Column gap={6}>
          <Row align={:center} gap={12}>
            {swatch}
            <Column weight={1}>
              <Text
                text={row.label}
                text_size={Style.ui(17, :tablet)}
                text_color={label_color}
                font_weight="bold"
                max_lines={1}
              />
              <Text
                text={row.detail}
                text_size={Style.type(:subtitle, :tablet)}
                text_color={Style.text_tertiary()}
                max_lines={1}
              />
            </Column>
          </Row>
          {strip_line("Level", "#{row.level}", row.level, {0.0, 100.0}, level, color)}
          {strip_balance(assigns, row, balance, color, :line)}
        </Column>
        """
      end

    ~MOB"""
    <Box background={Style.surface_raised()} corner_radius={18} padding={m.strip_padding} weight={1}>
      {controls}
    </Box>
    """
  end

  defp strip_value(text) do
    ~MOB"""
    <Text
      text={text}
      text_size={Style.type(:status, :tablet)}
      text_color={Style.text_primary()}
      font_weight="bold"
    />
    """
  end

  defp strip_line(label, value, current, {min, max}, change, color) do
    ~MOB"""
    <Row align={:center} gap={10}>
      {strip_label(label)}
      <Slider value={current * 1.0} min={min} max={max} on_change={change} color={color} weight={1} />
      <Text
        text={value}
        text_size={Style.type(:status, :tablet)}
        text_color={Style.text_primary()}
        font_weight="bold"
        width={60}
      />
    </Row>
    """
  end

  # A row's balance as L 45 / C / R 70 with its slider; on a mono output
  # (the speaker, a call route) balance has no effect, so no slider: it says
  # so, and the setting waits for headphones.
  defp strip_balance(%{mono: true}, _row, _change, _color, form) do
    {label, note} =
      case form do
        :stacked -> {nil, "Balance: none in mono"}
        :line -> {"Balance", "None in mono"}
      end

    ~MOB"""
    <Row align={:center} gap={10} height={36}>
      {if label, do: strip_label(label), else: []}
      <Text
        text={note}
        text_size={Style.type(:status, :tablet)}
        text_color={Style.text_tertiary()}
        max_lines={1}
      />
    </Row>
    """
  end

  defp strip_balance(_assigns, row, change, color, :stacked) do
    ~MOB"""
    <Column gap={4}>
      <Slider
        value={row.balance * 1.0}
        min={-100.0}
        max={100.0}
        on_change={change}
        color={color}
        fill_width={true}
      />
      {strip_value("Balance " <> balance_label(row.balance, false))}
    </Column>
    """
  end

  defp strip_balance(_assigns, row, change, color, :line) do
    strip_line(
      "Balance",
      balance_label(row.balance, false),
      row.balance,
      {-100.0, 100.0},
      change,
      color
    )
  end

  defp strip_label(label) do
    ~MOB"""
    <Text
      text={label}
      text_size={Style.type(:status, :tablet)}
      text_color={Style.text_secondary()}
      width={76}
    />
    """
  end

  # Every tap target here also declares `on_press_out` (this, ignored). While
  # a song plays the screen re-renders ~30 times a second, and Mob's Android
  # bridge drops a plain tap whose handle is from an earlier render, so most
  # taps during playback were lost. A node with a press handler gets its tap
  # matched by slot, pid and tag instead (Mob's MOB-380 path), which survives
  # the re-render.
  defp held, do: {self(), :held}

  # The roll, or (mix open) the compact staff + status line over the sheet.
  defp stage(%{mix_open: false}, frame) do
    ~MOB"""
    <Canvas width={frame.width} height={frame.height} draw={PracticeView.ops(frame)} />
    """
  end

  defp stage(assigns, frame) do
    compact_h = PracticeView.compact_height()

    ~MOB"""
    <Column>
      <Canvas width={frame.width} height={compact_h} draw={PracticeView.compact_ops(frame)} />
      {mix_sheet(assigns, frame.height - compact_h)}
    </Column>
    """
  end

  defp header(assigns) do
    back_tap = {self(), :back}
    audio_tap = {self(), :audio}

    ~MOB"""
    <Column height={96} padding_left={8} padding_right={16}>
      <Row height={56} align={:center}>
        <Text
          id="nav_back"
          text="‹"
          on_tap={back_tap}
          on_press_out={held()}
          text_size={30}
          text_color={Style.text_secondary()}
          padding_left={8}
          padding_right={10}
        />
        <Text
          text={assigns.song.title}
          text_size={18}
          text_color={Style.text_primary()}
          font_weight="bold"
          max_lines={1}
          weight={1}
        />
        <Canvas
          id="audio_icon"
          width={36}
          height={36}
          draw={ControlsView.headphones(36)}
          on_tap={audio_tap}
          on_press_out={held()}
        />
      </Row>
      <Row height={40} align={:center} padding_left={14}>
        <Text
          text={subtitle(assigns)}
          text_size={Style.type(:subtitle)}
          text_color={if(assigns.offer_delay, do: Style.accent(), else: Style.text_tertiary())}
          font_weight={if(assigns.offer_delay, do: "bold", else: "normal")}
          max_lines={1}
          weight={1}
          on_tap={if(assigns.offer_delay, do: audio_tap)}
          on_press_out={if(assigns.offer_delay, do: held())}
        />
        {part_switch(assigns, :phone)}
      </Row>
    </Column>
    """
  end

  # The singer's part | Melody as a segmented control: both options visible,
  # the current one filled with the UI accent.
  defp part_switch(assigns, layout) do
    segments =
      for {part, _} <- assigns.parts do
        selected = part == assigns.part
        tap = {self(), {:part, part}}

        ~MOB"""
        <Box
          id={"part_#{part}"}
          background={if(selected, do: Style.accent(), else: 0x00000000)}
          corner_radius={Style.ui(17, layout)}
          padding_left={Style.ui(14, layout)}
          padding_right={Style.ui(14, layout)}
          padding_top={Style.ui(7, layout)}
          padding_bottom={Style.ui(7, layout)}
          fill_width={false}
          on_tap={tap}
          on_press_out={held()}
        >
          <Text
            text={part_name(part)}
            text_size={Style.type(:status, layout)}
            text_color={if(selected, do: Style.bg(), else: Style.text_primary())}
            font_weight="bold"
          />
        </Box>
        """
      end

    ~MOB"""
    <Box
      background={0x24FFFFFF}
      corner_radius={Style.ui(20, layout)}
      padding={Style.ui(3, layout)}
      fill_width={false}
    >
      <Row>
        {segments}
      </Row>
    </Box>
    """
  end

  # ── What you hear ────────────────────────────────────────────────────────

  defp mix_sheet(assigns, height) do
    close = {self(), :mix}
    audio_tap = {self(), :audio}
    map_w = assigns.screen_w - 40

    ~MOB"""
    <Box background={Style.surface()} corner_radius={24} height={height}>
      <Scroll>
        <Column padding_left={20} padding_right={20} padding_bottom={16} gap={12}>
          <Box padding_top={8} padding_bottom={4} on_tap={close} on_press_out={held()}>
            <Row>
              <Spacer />
              <Box background={0x40FFFFFF} corner_radius={2} width={36} height={4} />
              <Spacer />
            </Row>
          </Box>
          <Row align={:center} gap={10}>
            <Text
              text="What you hear"
              text_size={22}
              text_color={Style.text_primary()}
              font_weight="bold"
              weight={1}
            />
            <Box
              id="mix_done"
              background={Style.accent()}
              corner_radius={18}
              padding_left={16}
              padding_right={16}
              padding_top={8}
              padding_bottom={8}
              fill_width={false}
              on_tap={close}
              on_press_out={held()}
            >
              <Text
                text="Done"
                text_size={Style.type(:status)}
                text_color={Style.bg()}
                font_weight="bold"
              />
            </Box>
          </Row>
          <Row>
            <Box
              background={0x24FFFFFF}
              corner_radius={18}
              padding={8}
              fill_width={false}
              on_tap={audio_tap}
              on_press_out={held()}
            >
              <Row align={:center} gap={6}>
                <Canvas
                  width={20}
                  height={20}
                  draw={ControlsView.headphones(20, Style.text_primary())}
                />
                <Text
                  text={output_label(assigns.output) <> "  ›"}
                  text_size={Style.type(:status)}
                  text_color={Style.text_primary()}
                  font_weight="bold"
                />
              </Row>
            </Box>
          </Row>
          {preset_chips(assigns)}
          {mix_body(assigns, assigns.mix, map_w)}
        </Column>
      </Scroll>
    </Box>
    """
  end

  # The phone's chips scroll sideways under the sheet's title; a tablet's
  # wrap after "What you hear" (`mix_dock/2`).
  defp preset_chips(assigns) do
    chips = for spec <- chip_specs(assigns), do: chip(spec, :phone)

    ~MOB"""
    <Scroll axis="horizontal">
      <Row gap={8}>
        {chips}
      </Row>
    </Scroll>
    """
  end

  # Each chip as {label, tap, selected}: Custom (no tap) and Save while the
  # mix is custom, then the presets.
  defp chip_specs(assigns) do
    mix = assigns.mix

    custom =
      if mix.preset == :custom,
        do: [{"Custom", nil, true}, {"Save", {self(), :save_mix}, false}],
        else: []

    presets =
      for p <- Mix.presets(mix, Settings.saved_mix(assigns.part)),
          do: {p.label, {self(), {:preset, p.id}}, mix.preset == p.id}

    custom ++ presets
  end

  defp chip({label, tap, selected}, layout) do
    ~MOB"""
    <Box
      id={chip_id(tap)}
      background={if(selected, do: 0x40FFFFFF, else: 0x14FFFFFF)}
      corner_radius={Style.ui(20, layout)}
      padding_left={Style.ui(16, layout)}
      padding_right={Style.ui(16, layout)}
      padding_top={Style.ui(10, layout)}
      padding_bottom={Style.ui(10, layout)}
      fill_width={false}
      on_tap={tap}
      on_press_out={if(tap, do: held())}
    >
      <Text
        text={label}
        text_size={Style.type(:status, layout)}
        text_color={if(selected, do: Style.text_primary(), else: Style.text_secondary())}
        font_weight="bold"
      />
    </Box>
    """
  end

  # Ids for the device check (`scripts/controls_check.exs`) to find chips by.
  defp chip_id({_pid, {:preset, id}}), do: "preset_#{id}"
  defp chip_id({_pid, :save_mix}), do: "save_mix"
  defp chip_id(nil), do: "custom"

  # A whole recording plays as it is; the rows mix the part, voices and band.
  defp mix_body(_assigns, %{recording: rec}, _map_w) when rec != nil do
    ~MOB"""
    <Text
      text={"#{recording_name(rec)} plays the recording as it is. Pick Rehearsal or Me in right ear to set each source."}
      text_size={Style.type(:subtitle)}
      text_color={Style.text_tertiary()}
    />
    """
  end

  defp mix_body(assigns, mix, map_w) do
    rows = for row <- mix.rows, do: mix_row(assigns, row)

    ~MOB"""
    <Column gap={6}>
      <Canvas width={map_w} height={84} draw={MixView.ear_map(mix, assigns.mono, map_w, 84)} />
      {rows}
    </Column>
    """
  end

  defp mix_row(assigns, row) do
    open = assigns.open_row == row.id
    toggle = {self(), {:toggle_row, row.id}}
    expand = {self(), {:open_row, row.id}}

    ~MOB"""
    <Box
      background={if(open, do: Style.surface_raised(), else: 0x00000000)}
      corner_radius={16}
      padding_left={8}
      padding_right={8}
      padding_top={6}
      padding_bottom={6}
    >
      <Column gap={6}>
        <Row align={:center} gap={12}>
          <Canvas
            id={"row_#{row.id}"}
            width={40}
            height={40}
            draw={MixView.swatch(assigns.part, row, 40)}
            on_tap={toggle}
            on_press_out={held()}
          />
          <Box weight={1} on_tap={expand} on_press_out={held()}>
            <Row align={:center}>
              <Column weight={1}>
                <Text
                  text={row.label}
                  text_size={17}
                  text_color={if(row.on, do: Style.text_primary(), else: Style.text_tertiary())}
                  font_weight="bold"
                />
                <Text
                  text={row.detail}
                  text_size={Style.type(:subtitle)}
                  text_color={Style.text_tertiary()}
                />
              </Column>
              <Text
                text={Mix.value_label(row, assigns.mono) <> if(open, do: "   ˄", else: "   ˅")}
                text_size={Style.type(:status)}
                text_color={Style.text_secondary()}
                font_weight="bold"
              />
            </Row>
          </Box>
        </Row>
        {if open, do: row_sliders(assigns, row), else: []}
      </Column>
    </Box>
    """
  end

  defp row_sliders(assigns, row) do
    level = {self(), {:level, row.id}}
    balance = {self(), {:balance, row.id}}

    ~MOB"""
    <Column gap={2} padding_left={6} padding_right={6}>
      <Row align={:center} gap={10}>
        <Text
          text="Level"
          text_size={Style.type(:status)}
          text_color={Style.text_secondary()}
          width={64}
        />
        <Slider
          value={row.level * 1.0}
          min={0.0}
          max={100.0}
          on_change={level}
          color={Style.swatch(assigns.part)}
          weight={1}
        />
        <Text
          text={"#{row.level}"}
          text_size={Style.type(:status)}
          text_color={Style.text_primary()}
          font_weight="bold"
          width={48}
        />
      </Row>
      <Row align={:center} gap={10}>
        <Text
          text="Balance"
          text_size={Style.type(:status)}
          text_color={Style.text_secondary()}
          width={64}
        />
        <Slider
          value={row.balance * 1.0}
          min={-100.0}
          max={100.0}
          on_change={balance}
          color={Style.swatch(assigns.part)}
          weight={1}
        />
        <Text
          text={balance_label(row.balance, assigns.mono)}
          text_size={Style.type(:status)}
          text_color={Style.text_primary()}
          font_weight="bold"
          width={48}
        />
      </Row>
    </Column>
    """
  end

  defp balance_label(_balance, true), do: "—"
  defp balance_label(0, false), do: "C"
  defp balance_label(b, false) when b < 0, do: "L #{-b}"
  defp balance_label(b, false), do: "R #{b}"

  defp recording_name(:split), do: "Full choir"
  defp recording_name(:demo), do: "Demo"

  defp output_label(nil), do: "Phone"
  defp output_label(%{kind: :bluetooth}), do: "Bluetooth"
  defp output_label(%{kind: kind}) when kind in [:wired_headphones, :wired_headset], do: "Wired"
  defp output_label(%{kind: :usb}), do: "USB"
  defp output_label(_device), do: "Speaker"

  @doc false
  # The play button shows pause while playing or while a start is pending
  # (a track loading after a switch): tapping it then stops either.
  def shows_pause?(assigns), do: assigns.playing or assigns.resume_at != nil

  @doc false
  # The header's second line: what's wrong if anything is, else the song facts.
  def subtitle(%{audio_status: :loading}), do: "Loading the track…"

  def subtitle(%{audio_status: {:error, reason}}),
    do: "Can't play this track (#{inspect(reason)})"

  def subtitle(%{mic: :denied}), do: "Microphone off: allow it in Settings for feedback"
  def subtitle(%{listening: {:error, reason}}), do: "Microphone unavailable (#{inspect(reason)})"
  def subtitle(%{listening: :playback}), do: "Test mode: listening to the track itself"
  def subtitle(%{offer_delay: true}), do: "New headphones: set their delay  ›"

  def subtitle(%{song: song, t_ms: t}) do
    "#{Song.key_name(song)} · ♩ = #{round(song.tempo_bpm)} · bar #{Song.bar_at(song, t).number} of #{List.last(song.bars).number}"
  end

  # ── Events ───────────────────────────────────────────────────────────────

  # The window turned or was resized (`ChoirCoach.Window.refresh/2`: a
  # screen that was and stays phone-laid-out keeps its size, as it always
  # has). Rotating a tablet changes no size class, hence both messages.
  def handle_info({:mob_device, :orientation_changed, _orientation}, socket),
    do: {:noreply, Window.refresh(socket, &layout_of/1)}

  def handle_info({:mob_size_class_changed, _size_class}, socket),
    do: {:noreply, Window.refresh(socket, &layout_of/1)}

  # The app went to the background, where the OS may end it unannounced: a
  # tablet saves its docked mix (a phone's is saved as the sheet closes).
  def handle_info({:mob_device, :did_enter_background}, socket),
    do: {:noreply, persist_docked_mix(socket)}

  # While the Audio screen has the engine this screen makes no engine call:
  # its device and delay choices are kept for the engine's return, and
  # engine events and frame ticks are dropped.
  def handle_info(message, %{assigns: %{attached: false}} = socket),
    do: {:noreply, detached(message, socket)}

  def handle_info({:tap, :back}, socket) do
    {:noreply, Mob.Socket.pop_screen(socket)}
  end

  # The lift after a tap (see `held/0`): nothing to do.
  def handle_info({:press_out, :held}, socket), do: {:noreply, socket}

  # While a track loads, play / pause toggles whether it starts once ready.
  def handle_info({:tap, :play_pause}, socket) do
    a = socket.assigns
    if a.playing or a.resume_at, do: {:noreply, pause(socket)}, else: {:noreply, play(socket)}
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

  # The next bar's start; nothing past the last bar.
  def handle_info({:tap, :forward_bar}, socket) do
    a = socket.assigns

    case Song.bar_after(a.song, Song.bar_at(a.song, a.t_ms).number) do
      nil -> {:noreply, socket}
      next -> {:noreply, seek(socket, next.start_ms)}
    end
  end

  # Dragging the progress track: playback pauses while the finger moves and
  # the staff and roll follow it; letting go plays on from there if it was
  # playing (or about to) when the drag began. A :began always starts afresh,
  # so a drag whose end never arrived can't carry its intent into the next.
  def handle_info({:drag, :scrub, %{x: x, phase: phase}}, socket) do
    a = socket.assigns
    t = scrub_time(a, x)

    socket =
      if a.scrub && phase != :began,
        do: socket,
        else:
          socket
          |> then(&if(a.playing or a.resume_at, do: pause(&1), else: &1))
          |> Mob.Socket.assign(:scrub, %{resume: a.playing or a.resume_at != nil})

    socket = socket |> Mob.Socket.assign(:t_ms, t) |> reset_trace()

    if phase in [:began, :dragging] do
      {:noreply, socket}
    else
      resume = socket.assigns.scrub.resume
      socket = Mob.Socket.assign(socket, :scrub, nil)
      {:noreply, if(resume, do: play(socket), else: socket)}
    end
  end

  def handle_info({:tap, :loop}, socket) do
    {:noreply, Mob.Socket.assign(socket, :loop, not socket.assigns.loop)}
  end

  # The other part at the same song time (the parts share the bar timeline):
  # its own mix, notes, staff, readings and engine state (the host engine's
  # singer sings the part shown).
  def handle_info({:tap, {:part, part}}, socket) do
    a = socket.assigns

    if part != a.part and Keyword.has_key?(a.parts, part),
      do: {:noreply, switch_part(socket, part)},
      else: {:noreply, socket}
  end

  def handle_info({:tap, :mix}, socket) do
    if socket.assigns.mix_open, do: persist_mix(socket)
    {:noreply, Mob.Socket.assign(socket, mix_open: not socket.assigns.mix_open, open_row: nil)}
  end

  def handle_info({:tap, {:preset, id}}, socket) do
    a = socket.assigns
    mix = Mix.apply_preset(a.mix, id, Settings.saved_mix(a.part))
    {:noreply, socket |> change_mix(mix) |> persist_docked_mix()}
  end

  def handle_info({:tap, :save_mix}, socket) do
    a = socket.assigns

    {:noreply,
     socket |> change_mix(Settings.put_saved_mix(a.part, a.mix)) |> persist_docked_mix()}
  end

  def handle_info({:tap, {:toggle_row, id}}, socket) do
    {:noreply,
     socket |> change_mix(Mix.toggle_row(socket.assigns.mix, id)) |> persist_docked_mix()}
  end

  def handle_info({:tap, {:open_row, id}}, socket) do
    open = if socket.assigns.open_row == id, do: nil, else: id
    {:noreply, Mob.Socket.assign(socket, :open_row, open)}
  end

  def handle_info({:change, {field, id}, value}, socket) when field in [:level, :balance] do
    {:noreply, change_mix(socket, Mix.set_row(socket.assigns.mix, id, field, round(value)))}
  end

  # Only this screen's latest load, listening and holding count: a part
  # switch or a reload drops what the replaced one sends late.
  def handle_info({:choir_audio, _event, _payload, _load} = event, socket) do
    a = socket.assigns

    if a.engine.current?(a.audio, event),
      do: {:noreply, audio_event(event, socket)},
      else: {:noreply, socket}
  end

  def handle_info({:permission, :microphone, result}, socket) do
    {:noreply, socket |> Mob.Socket.assign(:mic, result) |> maybe_listen()}
  end

  # Headphones icon or the sheet's device chip: open Audio, handing it the
  # engine (one holder at a time): release it (music and mic stop) and wait
  # for the lease's `{:audio_engine_reset}` once the Audio screen is gone.
  def handle_info({:tap, :audio}, socket) do
    a = socket.assigns
    if a.offer_delay, do: Settings.put_delay_offered(a.output_key)

    socket =
      socket
      |> Mob.Socket.assign(audio: a.engine.release(a.audio), offer_delay: false)
      |> detach(retry: false)

    {:noreply,
     Mob.Socket.push_screen(socket, AudioScreen, %{
       practice: self(),
       output: a.output_pref,
       input: a.input_pref
     })}
  end

  # Jump to a song time (ms), keeping play / pause as it is.
  def handle_info({:seek, ms}, socket) when is_number(ms) do
    {:noreply, seek(socket, max(ms * 1.0, 0.0))}
  end

  # Device test hook: analyse the track itself instead of the microphone
  # (`send(pid, {:listen, :playback})`), or go back to `:mic`. Kept across
  # track and part switches; while a track loads it starts once it's ready.
  def handle_info({:listen, source}, socket) when source in [:mic, :playback] do
    socket = Mob.Socket.assign(socket, :listen_source, source)

    if socket.assigns.audio_status == :ready,
      do: {:noreply, listen(socket, source)},
      else: {:noreply, Mob.Socket.assign(socket, :listening, :off)}
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
  # per app, so give it back with its music and microphone stopped, or they
  # run on under the song list; and let the screen sleep again. (A release
  # by a screen that doesn't hold the engine changes nothing.)
  def terminate(_reason, socket) do
    a = socket.assigns

    if a[:audio] do
      keep_awake(false)
      persist_mix(socket)
      a.engine.release(a.audio)
    end

    :ok
  end

  # ── Engine hand-over ─────────────────────────────────────────────────────
  #
  # The engine has one holder at a time (`ChoirCoach.Audio`). This screen
  # takes it at mount, gives it to the Audio screen before pushing it, and
  # can find it busy or lose it (a remounted Audio screen takes it by force).
  # Then it is detached: no engine calls, engine events and frame ticks
  # dropped, device and delay choices recorded; it waits on
  # `ChoirCoach.Audio.Lease` for `{:audio_engine_reset}` and tries again.

  # Take the engine and load the sources at the same song time, with the
  # current device and delay choices; or wait for it if someone holds it.
  defp attach(socket) do
    a = socket.assigns

    case a.engine.acquire(a.audio, false) do
      {:ok, audio} ->
        # Listening starts with the load's ready.
        audio =
          audio
          |> a.engine.set_mic_delay(a.mic_delay)
          |> a.engine.set_output(a.output_pref)
          |> a.engine.set_input(a.input_pref)
          |> engine_state()

        socket
        |> Mob.Socket.assign(audio: audio, attached: true)
        |> load_audio(Mix.load_spec(a.mix, a.tracks))

      {:error, :busy, audio} ->
        socket |> Mob.Socket.assign(:audio, audio) |> detach(retry: true)
    end
  end

  # Stop using the engine and wait for the lease. `retry`: with no borrower
  # to wait for (it left before we asked), try again shortly instead.
  defp detach(socket, retry: retry) do
    keep_awake(false)

    socket =
      socket
      |> cancel_tick()
      |> Mob.Socket.assign(
        attached: false,
        playing: false,
        resume_at: nil,
        listening: :off,
        scrub: nil
      )

    if Audio.Lease.await(self()) == :free and retry,
      do: Process.send_after(self(), {:audio_engine_reset}, @retry_ms)

    socket
  end

  # Messages while detached. Device and delay choices apply on attaching;
  # the test hooks just record.
  defp detached({:audio_output, id}, socket), do: Mob.Socket.assign(socket, :output_pref, id)
  defp detached({:audio_input, id}, socket), do: Mob.Socket.assign(socket, :input_pref, id)

  defp detached({:mic_delay, ms}, socket) when is_number(ms),
    do: Mob.Socket.assign(socket, :mic_delay, ms)

  defp detached({:permission, :microphone, result}, socket),
    do: Mob.Socket.assign(socket, :mic, result)

  defp detached({:listen, source}, socket) when source in [:mic, :playback],
    do: Mob.Socket.assign(socket, :listen_source, source)

  defp detached({:seek, ms}, socket) when is_number(ms),
    do: socket |> Mob.Socket.assign(:t_ms, max(ms * 1.0, 0.0)) |> reset_trace()

  # The borrower has gone (its calibration may have replaced the sources):
  # take the engine back, or wait again if it's busy.
  defp detached({:audio_engine_reset}, socket), do: attach(socket)

  defp detached(_message, socket), do: socket

  # ── Playback ─────────────────────────────────────────────────────────────

  defp audio_event({:choir_audio, :ready, _info, _load}, socket) do
    socket =
      socket
      |> Mob.Socket.assign(:audio_status, :ready)
      |> refresh_output()
      |> apply_mix()
      |> maybe_listen()

    case socket.assigns.resume_at do
      nil -> socket
      t -> socket |> Mob.Socket.assign(t_ms: t, resume_at: nil) |> play()
    end
  end

  # The track can't play: before it was ready, or part way through decoding
  # (`:decode_error` can follow `:ready`), so stop whatever had started:
  # playback, the frame tick, keep-awake and the microphone.
  defp audio_event({:choir_audio, :load_error, reason, _load}, socket) do
    socket = pause(socket)
    a = socket.assigns

    Mob.Socket.assign(socket,
      audio: a.engine.stop_listening(a.audio),
      listening: :off,
      audio_status: {:error, reason}
    )
  end

  defp audio_event({:choir_audio, :decoded, _info, _load}, socket), do: socket

  # The microphone failed (unplugged, Bluetooth gone): stop its stream and
  # analysis; the subtitle says so until a new listen.
  defp audio_event({:choir_audio, :mic_error, reason, _listen}, socket) do
    a = socket.assigns

    Mob.Socket.assign(socket,
      audio: a.engine.stop_listening(a.audio),
      listening: {:error, reason}
    )
  end

  # Another screen took the engine: stop using it and wait for it back.
  defp audio_event({:choir_audio, :not_owner, _payload, _hold}, socket),
    do: detach(socket, retry: true)

  defp engine_state({:ok, audio}), do: audio
  defp engine_state({:error, _reason, audio}), do: audio

  # Load an engine spec. Playing pauses now and resumes at the same song
  # time once the sources are ready; a resume still pending from an earlier
  # load (switching again while loading, or after a failed load) carries over.
  defp load_audio(socket, spec) do
    a = socket.assigns
    resume = if a.playing, do: a.t_ms, else: a.resume_at
    socket = if a.playing, do: pause(socket), else: socket

    Mob.Socket.assign(socket,
      audio: a.engine.load(socket.assigns.audio, spec),
      audio_status: :loading,
      listening: :off,
      resume_at: resume
    )
  end

  defp switch_part(socket, part) do
    persist_mix(socket)
    a = socket.assigns
    %{song: song, tracks: tracks} = Keyword.fetch!(a.parts, part)
    mix = Settings.mix(part) || Mix.new(part, tracks)
    near = Song.note_at(song, a.t_ms) || Song.next_note(song, a.t_ms) || hd(song.notes)

    socket
    |> Mob.Socket.assign(
      audio: a.engine.set_song(a.audio, song),
      part: part,
      song: song,
      tracks: tracks,
      mix: mix,
      open_row: nil,
      center_midi: near.midi * 1.0
    )
    |> load_audio(Mix.load_spec(mix, tracks))
    |> reset_trace()
  end

  # A mix change only re-sets the gains unless it needs other recordings
  # (to or from a whole-recording preset), which reloads at the same time.
  defp change_mix(socket, mix) do
    a = socket.assigns
    socket = Mob.Socket.assign(socket, :mix, mix)

    if Mix.same_load?(a.mix, mix),
      do: apply_mix(socket),
      else: load_audio(socket, Mix.load_spec(mix, a.tracks))
  end

  # Saved when the sheet closes, the part changes or the song is left, not on
  # every slider step.
  defp persist_mix(socket), do: Settings.put_mix(socket.assigns.part, socket.assigns.mix)

  # A tablet's mix is always showing, with no sheet to close: it is saved on
  # each preset, toggle or save, and (for its sliders) when the app goes to
  # the background, where the OS may end it without `terminate/2`.
  defp persist_docked_mix(%{assigns: %{layout: :tablet}} = socket) do
    persist_mix(socket)
    socket
  end

  defp persist_docked_mix(socket), do: socket

  # Which output plays (`Settings.active_output/3`): it sets mono (the phone
  # speaker) and which headphones' delay applies.
  defp refresh_output(socket) do
    a = socket.assigns

    output =
      Settings.active_output(
        a.engine.devices(a.audio),
        a.engine.output_device(a.audio),
        a.output_pref
      )

    key = Settings.device_key(output || %{kind: :other, name: ""})
    delay = Settings.mic_delay_ms(key)

    # New headphones (no delay saved, never offered): offer to set it, once.
    offer =
      output != nil and output.kind in @headphone_kinds and not Settings.known_device?(key) and
        not Settings.delay_offered?(key)

    Mob.Socket.assign(socket,
      output: output,
      output_key: key,
      offer_delay: offer,
      mono: output != nil and output.kind in @mono_kinds,
      mic_delay: delay,
      audio: a.engine.set_mic_delay(a.audio, delay)
    )
  end

  # Not ready (loading, or a load that failed): play from here once a track is.
  defp play(%{assigns: %{audio_status: status}} = socket) when status != :ready,
    do: Mob.Socket.assign(socket, :resume_at, socket.assigns.t_ms)

  defp play(socket) do
    a = socket.assigns
    start = if a.t_ms >= Song.duration_ms(a.song), do: loop_start(a), else: a.t_ms

    case a.engine.play(a.audio, start) do
      {:ok, audio} ->
        keep_awake(true)

        # The stream now reports the device it really plays through.
        socket
        |> Mob.Socket.assign(audio: audio, playing: true, t_ms: start)
        |> refresh_output()
        |> apply_mix()
        |> reset_trace()
        |> schedule_tick()

      # The `:not_owner` message that came with it detaches this screen.
      {:error, :not_owner, audio} ->
        Mob.Socket.assign(socket, :audio, audio)

      {:error, reason, audio} ->
        Mob.Socket.assign(socket, audio: audio, audio_status: {:error, reason})
    end
  end

  # Also drops a pending start: pausing while a track loads means stay paused.
  defp pause(socket) do
    a = socket.assigns
    keep_awake(false)
    audio = a.engine.pause(a.audio)

    socket
    |> cancel_tick()
    |> Mob.Socket.assign(audio: audio, playing: false, resume_at: nil)
  end

  defp seek(socket, t) do
    a = socket.assigns

    cond do
      a.playing -> socket |> Mob.Socket.assign(:t_ms, t) |> play()
      # Loading with a start pending: it starts at the new place.
      a.resume_at -> socket |> Mob.Socket.assign(t_ms: t, resume_at: t) |> reset_trace()
      true -> socket |> Mob.Socket.assign(:t_ms, t) |> reset_trace()
    end
  end

  defp reset_trace(socket), do: Mob.Socket.assign(socket, trace: [], feedback: Feedback.new())

  defp apply_mix(socket) do
    a = socket.assigns
    Mob.Socket.assign(socket, :audio, a.engine.set_mix(a.audio, Mix.lane_gains(a.mix, a.mono)))
  end

  defp request_microphone(socket) do
    if device_calls?(),
      do: Mob.Permissions.request(socket, :microphone),
      else: Mob.Socket.assign(socket, :mic, :granted)
  end

  defp maybe_listen(
         %{assigns: %{audio_status: :ready, listening: :off, listen_source: :playback}} = socket
       ),
       do: listen(socket, :playback)

  defp maybe_listen(%{assigns: %{audio_status: :ready, mic: :granted, listening: :off}} = socket),
    do: listen(socket, :mic)

  defp maybe_listen(socket), do: socket

  defp listen(socket, source) do
    a = socket.assigns

    case a.engine.listen(a.audio, source) do
      {:ok, audio} ->
        Mob.Socket.assign(socket, audio: audio, listening: source)

      {:error, :not_owner, audio} ->
        Mob.Socket.assign(socket, :audio, audio)

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
      # Nothing to report (the engine was just lost: its message detaches us).
      status == :loading ->
        socket

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
    keep_from = t - max(Style.past_seconds() * 1000, PracticeView.past_ms(time_frame(a))) - 100

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

  # The track spans the row between the two clock labels (~36 dp each and
  # their gaps) inside the 24 dp margins; on a tablet, what the transport
  # controls leave of the row (`layout_of/1` keeps it usable).
  defp progress_width(%{layout: :phone} = assigns), do: assigns.screen_w - 2 * 24 - 2 * 46
  defp progress_width(%{layout: :tablet} = assigns), do: tablet_progress_width(assigns.screen_w)

  defp tablet_progress_width(screen_w) do
    controls =
      4 * Style.ui(ControlsView.size(), :tablet) + Style.ui(ControlsView.play_size(), :tablet) +
        4 * @tablet_gap

    screen_w - 2 * 24 - controls - 16 - 2 * (@tablet_clock_w + 8)
  end

  # The width the roll's time scale is taken from: the canvas's on a phone,
  # the reference artboard's on a tablet (it shows more seconds instead).
  defp time_width(%{layout: :phone} = assigns), do: assigns.screen_w
  defp time_width(%{layout: :tablet}), do: Style.reference_width()

  defp time_frame(a), do: %{width: a.screen_w, time_width: time_width(a), song: a.song}

  # Song time under a finger `x` dp along the progress track.
  defp scrub_time(a, x) do
    fraction = (x / progress_width(a)) |> max(0.0) |> min(1.0)
    fraction * Song.duration_ms(a.song)
  end

  defp loop_fraction(%{loop: false}), do: nil
  defp loop_fraction(%{loop: true}), do: {0.0, 1.0}

  defp loop_caption(song), do: "#{hd(song.bars).number}–#{List.last(song.bars).number}"

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
end
