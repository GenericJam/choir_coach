defmodule ChoirCoach.AudioScreen do
  @moduledoc """
  The Audio screen, opened from the practice header's headphones icon or the
  Mix sheet's device chip (`params.practice`: the practice screen's pid, or
  nil from elsewhere).

    * **Play through**: the connected outputs (`devices/1`), plus greyed rows
      for headphones that aren't connected. Tapping one routes playback there
      and sends `{:audio_output, id}` to the practice screen.
    * **Listen with**: the phone's microphone, or the headphones' one (a
      Bluetooth headset mic drops the music to call quality, so that asks
      first). Changes go to the practice screen as `{:audio_input, id}`.
    * **Mic level**: a live meter from the microphone while the screen is open.
    * **Timing**: the headphone delay saved for the current output device
      (`ChoirCoach.Settings`), ±10 ms, and "Set by singing along": eight clicks
      at 90 bpm through the chosen output, the singer sings "ta" on each, and
      `ChoirCoach.Calibration` turns the onsets into a delay to use. Changes
      go to the practice screen as `{:mic_delay, ms}`.

  The screen borrows the engine while it is open (`ChoirCoach.Audio.Lease`,
  then a forced `acquire/2`: the engine is one per app, one holder at a
  time), with its own engine state (`new_bare/0`); the practice screen
  hands it over before pushing this one (with its `output:` and `input:`
  preferences, so the checks match). Closing releases it, and the lease,
  seeing this process gone, sends the waiting practice screen
  `{:audio_engine_reset}`: it takes the engine back, reloads its sources
  and listens again. That holds however the screen ends, crash included.
  """

  use Mob.Screen

  import Mob.Canvas

  alias ChoirCoach.{Audio, Calibration, Settings, Style}

  @tick_ms 100
  # Device list refresh (headphones plugged in or out while the screen is open).
  @devices_every 10

  @clicks %{
    bar1_ms: 0.0,
    sources: [%{file: {:sound, "clicks_90.mp3"}, channels: [:left, :right]}],
    guide_lane: nil
  }
  # Listen on past the last click for its onset window.
  @clicks_tail_ms 700

  # Mic meter: −60…0 dBFS across the bar; the marker is where singing should sit.
  @meter_floor_db -60.0
  @meter_target_db -18.0
  @quiet_db -42.0
  @loud_db -6.0

  # Colours (functions, since `@name` inside `~MOB` reads an assign).
  defp card_color, do: 0xFF1A1F27
  defp rule_color, do: 0x14FFFFFF
  defp soft_button_color, do: 0x1FFFFFFF
  defp ink, do: Style.bg()

  @output_order [:bluetooth, :wired_headphones, :wired_headset, :usb, :other, :speaker]
  @headset_mics [:bluetooth_sco, :wired_headset, :usb]
  # Usual outputs shown greyed when not connected.
  @placeholders [
    {:bluetooth, "Bluetooth headphones", "Not connected"},
    {:wired_headphones, "Wired headphones", "Not plugged in"}
  ]

  @fallback_width 390.0

  def mount(params, _session, socket) do
    engine = Audio.engine()
    :ok = Audio.Lease.borrow(self())
    {:ok, audio} = engine.acquire(engine.new_bare(), true)
    devices = engine.devices(audio)

    socket =
      socket
      |> Mob.Socket.assign(
        engine: engine,
        audio: audio,
        practice: Map.get(params, :practice),
        screen_w: screen_width(params),
        devices: devices,
        output:
          Map.get(params, :output) || Settings.output_pref(devices) ||
            engine.output_device(audio),
        input: Map.get(params, :input) || Settings.input_pref(devices),
        confirm_input: nil,
        mic: :unknown,
        listening: false,
        # Why the microphone couldn't be opened, if it couldn't.
        mic_error: nil,
        level_db: nil,
        calibration: nil,
        ticks: 0,
        tick_timer: nil
      )
      |> load_delay()
      |> request_microphone()
      |> schedule_tick()
      |> subscribe_app()

    {:ok, socket}
  end

  # ── Render ───────────────────────────────────────────────────────────────

  def render(assigns) do
    back = {self(), :back}

    ~MOB"""
    <Column background={Style.bg()} fill_height={true}>
      <Row height={56} align={:center} padding_left={8} padding_right={20}>
        <Canvas width={44} height={44} draw={chevron_icon()} on_tap={back} on_press_out={held()} />
        <Text text="Audio" text_size={24} text_color={Style.text_primary()} font_weight="bold" />
      </Row>
      <Scroll weight={1}>
        <Column padding_left={20} padding_right={20} padding_bottom={32} gap={12}>
          {section_label("Play through")}
          {card(output_rows(assigns))}
          {section_label("Listen with")}
          {card(input_rows(assigns))}
          {mic_meter(assigns)}
          {section_label("Timing")}
          {timing_card(assigns)}
        </Column>
      </Scroll>
    </Column>
    """
  end

  defp section_label(text) do
    ~MOB"""
    <Text
      text={String.upcase(text)}
      text_size={13}
      text_color={Style.text_tertiary()}
      font_weight="bold"
      letter_spacing={1.2}
      padding_top={12}
    />
    """
  end

  defp card(rows) do
    ~MOB"""
    <Box background={card_color()} corner_radius={20} fill_width={true}>
      <Column>
        {separated(rows)}
      </Column>
    </Box>
    """
  end

  defp separated(rows) do
    rows
    |> Enum.intersperse(:rule)
    |> Enum.map(fn
      # Indented to start under the titles, past the icons.
      :rule ->
        ~MOB"""
        <Box padding_left={64}>
          <Divider color={rule_color()} />
        </Box>
        """

      row ->
        row
    end)
  end

  # One device row: icon, title and detail, a check when it's the one in use.
  # `tap` nil (not connected) greys it out.
  defp device_row(id, icon, title, detail, checked, tap) do
    {title_color, detail_color, icon_color} =
      if tap,
        do: {Style.text_primary(), Style.text_secondary(), Style.text_primary()},
        else: {Style.text_tertiary(), Style.text_tertiary(), Style.text_tertiary()}

    ~MOB"""
    <Row
      id={id}
      align={:center}
      padding={16}
      gap={16}
      on_tap={tap}
      on_press_out={if(tap, do: held())}
    >
      <Canvas width={28} height={28} draw={icon(icon, icon_color)} />
      <Column weight={1} gap={2}>
        <Text text={title} text_size={17} text_color={title_color} font_weight="bold" />
        <Text text={detail} text_size={14} text_color={detail_color} />
      </Column>
      <Canvas :if={checked} id="check" width={28} height={28} draw={check_icon()} />
    </Row>
    """
  end

  defp output_rows(assigns) do
    active = active_output(assigns)
    outputs = outputs(assigns.devices)

    missing =
      for {kind, title, detail} <- @placeholders,
          not Enum.any?(outputs, &(family(&1.kind) == family(kind))) do
        device_row("output:#{kind}", :headphones, title, detail, false, nil)
      end

    row = fn device ->
      device_row(
        "output:#{device.id}",
        output_icon(device.kind),
        output_title(device),
        output_detail(device),
        active != nil and device.id == active.id,
        {self(), {:output, device.id}}
      )
    end

    # Greyed headphones sit just above the phone speaker, as in the design.
    {speakers, others} = Enum.split_with(outputs, &(&1.kind == :speaker))
    Enum.map(others, row) ++ missing ++ Enum.map(speakers, row)
  end

  defp input_rows(assigns) do
    phone = phone_mic(assigns.devices)
    headset = headset_mic(assigns.devices)
    using = active_input(assigns)

    phone_row =
      device_row(
        "input:phone",
        :mic,
        "Phone microphone",
        "Recommended",
        using == :phone,
        {self(), {:input, phone && phone.id}}
      )

    headset_row =
      if headset do
        device_row(
          "input:headset",
          :headphones,
          "Headphone microphone",
          headset_detail(headset.kind),
          using == :headset,
          {self(), {:input, headset.id}}
        )
      else
        device_row(
          "input:headset",
          :headphones,
          "Headphone microphone",
          "Not connected",
          false,
          nil
        )
      end

    [phone_row, headset_row | confirm_rows(assigns)]
  end

  defp confirm_rows(%{confirm_input: nil}), do: []

  defp confirm_rows(_assigns) do
    [
      ~MOB"""
      <Column padding={16} gap={12}>
        <Text
          text="While the headphone microphone is on, Bluetooth plays your music at call quality: mono and muffled."
          text_size={14}
          text_color={Style.text_secondary()}
        />
        <Row gap={12}>
          {pill("Use it anyway", {self(), :confirm_input}, :primary)}
          {pill("Cancel", {self(), :cancel_input}, :secondary)}
        </Row>
      </Column>
      """
    ]
  end

  defp mic_meter(assigns) do
    # Label 76 + meter + status 96, two 12 dp gaps, inside the 20 dp margins.
    width = max(assigns.screen_w - 40 - 76 - 96 - 24, 80)

    ~MOB"""
    <Row align={:center} padding_top={8} gap={12}>
      <Text
        text="Mic level"
        text_size={15}
        text_color={Style.text_secondary()}
        width={76}
        max_lines={1}
      />
      <Canvas id="mic_meter" width={width} height={20} draw={meter_ops(width, assigns.level_db)} />
      <Text
        text={level_label(assigns)}
        text_size={15}
        text_color={Style.text_primary()}
        font_weight="bold"
        text_align="end"
        width={96}
        max_lines={1}
      />
    </Row>
    """
  end

  defp meter_ops(width, db) do
    y = 10
    target = meter_fraction(@meter_target_db) * width
    level = if db, do: meter_fraction(db) * width, else: 0

    List.flatten([
      line(4, y, width - 4, y, color: Style.white(), width: 10, cap: :round, opacity: 0.08),
      if(level > 4,
        do: [line(4, y, max(level - 4, 4), y, color: Style.accent(), width: 10, cap: :round)],
        else: []
      ),
      line(target, 1, target, 19, color: Style.text_primary(), width: 2.5, cap: :round)
    ])
  end

  defp meter_fraction(db), do: ((db - @meter_floor_db) / -@meter_floor_db) |> max(0.0) |> min(1.0)

  defp level_label(%{mic: :denied}), do: "Mic off"
  defp level_label(%{mic_error: reason}) when reason != nil, do: "Mic unavailable"
  defp level_label(%{level_db: nil}), do: "—"
  defp level_label(%{level_db: db}) when db < @quiet_db, do: "Too quiet"
  defp level_label(%{level_db: db}) when db > @loud_db, do: "Too loud"
  defp level_label(_assigns), do: "Good"

  defp timing_card(assigns) do
    minus = {self(), :minus}
    plus = {self(), :plus}

    ~MOB"""
    <Box background={card_color()} corner_radius={20} fill_width={true}>
      <Column padding={20} gap={16}>
        <Column gap={2}>
          <Text
            text="Headphone delay"
            text_size={17}
            text_color={Style.text_primary()}
            font_weight="bold"
          />
          <Text text={delay_detail(assigns)} text_size={14} text_color={Style.text_secondary()} />
        </Column>
        <Row align={:center} gap={12}>
          <Spacer />
          {round_button("−", minus)}
          <Text
            text={"#{assigns.delay} ms"}
            text_size={28}
            text_color={Style.text_primary()}
            font_weight="bold"
            text_align="center"
            width={120}
          />
          {round_button("+", plus)}
          <Spacer />
        </Row>
        {calibration(assigns)}
      </Column>
    </Box>
    """
  end

  defp delay_detail(assigns) do
    what = if assigns.delay_speaker, do: "the phone speaker", else: "these headphones"
    if assigns.delay_saved, do: "Saved for #{what}", else: "Typical for #{what}"
  end

  defp round_button(label, tap) do
    ~MOB"""
    <Box
      background={soft_button_color()}
      corner_radius={28}
      width={56}
      height={56}
      on_tap={tap}
      on_press_out={held()}
    >
      <Text
        text={label}
        text_size={24}
        text_color={Style.text_primary()}
        font_weight="bold"
        text_align="center"
        fill_width={true}
        padding_top={12}
      />
    </Box>
    """
  end

  defp calibration(%{calibration: nil}) do
    [
      big_button("Set by singing along", {self(), :calibrate}, true),
      explanation(
        "Sing “ta” on eight clicks, about 10 seconds. The app measures how late it hears you and keeps your pitch line under the right notes."
      )
    ]
  end

  defp calibration(%{calibration: {:result, ms}}) do
    ~MOB"""
    <Column gap={16}>
      <Row gap={12}>
        {pill("Use #{ms} ms", {self(), :use_calibration}, :primary)}
        {pill("Try again", {self(), :calibrate}, :secondary)}
      </Row>
      {explanation("You came in about #{ms} ms after each click.")}
    </Column>
    """
  end

  defp calibration(%{calibration: {:retry, reason}}) do
    ~MOB"""
    <Column gap={16}>
      {pill("Try again", {self(), :calibrate}, :primary)}
      {explanation(retry_text(reason))}
    </Column>
    """
  end

  defp calibration(_running) do
    [
      big_button("Listening…", nil, false),
      explanation("Sing “ta” right on each click.")
    ]
  end

  defp retry_text(:too_few_onsets),
    do: "Didn't hear you on enough clicks. Sing a short, clear “ta” on each one."

  defp retry_text(:inconsistent),
    do: "Your “ta”s landed at different times. Try again, right on each click."

  defp retry_text(:mic_off), do: "The microphone is off. Allow it for ChoirCoach, then try again."
  defp retry_text(_reason), do: "Couldn't play the clicks. Try again."

  defp big_button(label, tap, mic_icon?) do
    ~MOB"""
    <Box
      background={Style.play_button()}
      corner_radius={30}
      fill_width={true}
      on_tap={tap}
      on_press_out={if(tap, do: held())}
    >
      <Row align={:center} padding={18} gap={10}>
        <Spacer />
        <Canvas :if={mic_icon?} width={24} height={24} draw={icon(:mic, ink())} />
        <Text text={label} text_size={18} text_color={ink()} font_weight="bold" />
        <Spacer />
      </Row>
    </Box>
    """
  end

  defp pill(label, tap, kind) do
    {background, color} =
      case kind do
        :primary -> {Style.play_button(), ink()}
        :secondary -> {soft_button_color(), Style.text_primary()}
      end

    ~MOB"""
    <Box
      background={background}
      corner_radius={24}
      padding={14}
      weight={1}
      on_tap={tap}
      on_press_out={held()}
    >
      <Text
        text={label}
        text_size={16}
        text_color={color}
        font_weight="bold"
        text_align="center"
        max_lines={1}
      />
    </Box>
    """
  end

  defp explanation(text) do
    ~MOB"""
    <Text text={text} text_size={15} text_color={Style.text_secondary()} line_height={1.35} />
    """
  end

  # Every tap target also declares `on_press_out` (this, ignored): the meter
  # re-renders the screen every 100 ms, and Mob's Android bridge drops a
  # plain tap whose handle is from an earlier render. A node with a press
  # handler has its tap matched by slot, pid and tag instead (MOB-380).
  defp held, do: {self(), :held}

  # ── Events ───────────────────────────────────────────────────────────────

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  # The lift after a tap (see `held/0`): nothing to do.
  def handle_info({:press_out, :held}, socket), do: {:noreply, socket}

  def handle_info({:tap, {:output, id}}, socket) do
    devices = socket.assigns.devices
    # Cancelling a run re-opens the microphone: switch on the state it returns.
    socket = stop_calibration(socket)
    a = socket.assigns

    socket =
      socket
      |> Mob.Socket.assign(audio: a.engine.set_output(a.audio, id), output: id)
      |> load_delay()

    :ok = Settings.put_output_pref(Enum.find(devices, &(&1.id == id)))
    notify(socket, {:audio_output, id})
    {:noreply, socket}
  end

  def handle_info({:tap, {:input, id}}, socket) do
    case Enum.find(socket.assigns.devices, &(&1.id == id)) do
      %{kind: :bluetooth_sco} -> {:noreply, Mob.Socket.assign(socket, :confirm_input, id)}
      _ -> {:noreply, set_input(socket, id)}
    end
  end

  def handle_info({:tap, :confirm_input}, socket),
    do: {:noreply, set_input(socket, socket.assigns.confirm_input)}

  def handle_info({:tap, :cancel_input}, socket),
    do: {:noreply, Mob.Socket.assign(socket, :confirm_input, nil)}

  def handle_info({:tap, :minus}, socket),
    do: {:noreply, save_delay(socket, socket.assigns.delay - Settings.delay_step())}

  def handle_info({:tap, :plus}, socket),
    do: {:noreply, save_delay(socket, socket.assigns.delay + Settings.delay_step())}

  def handle_info({:tap, :calibrate}, socket), do: {:noreply, start_calibration(socket)}

  def handle_info({:tap, :use_calibration}, %{assigns: %{calibration: {:result, ms}}} = socket) do
    {:noreply, socket |> save_delay(ms) |> Mob.Socket.assign(:calibration, nil)}
  end

  # Only this screen's latest load, listening and holding count: an earlier
  # run's clicks or microphone are not what is going on now.
  def handle_info({:choir_audio, _event, _payload, _load} = event, socket) do
    a = socket.assigns

    if a.engine.current?(a.audio, event),
      do: {:noreply, audio_event(event, socket)},
      else: {:noreply, socket}
  end

  def handle_info({:permission, :microphone, result}, socket) do
    {:noreply, socket |> Mob.Socket.assign(:mic, result) |> listen()}
  end

  # In the background nothing listens: the run is cancelled, the mic and the
  # tick stop. Back in front, both start again.
  def handle_info({:mob_device, :did_enter_background}, socket) do
    a = socket.assigns
    if a.tick_timer, do: Process.cancel_timer(a.tick_timer)

    {:noreply,
     Mob.Socket.assign(socket,
       audio: a.engine.stop(a.audio),
       background: true,
       calibration: nil,
       listening: false,
       level_db: nil,
       tick_timer: nil
     )}
  end

  def handle_info({:mob_device, :will_enter_foreground}, socket) do
    {:noreply, socket |> Mob.Socket.assign(:background, false) |> listen() |> schedule_tick()}
  end

  # A tick already queued when the app went to the background.
  def handle_info(:tick, %{assigns: %{background: true}} = socket), do: {:noreply, socket}

  def handle_info(:tick, socket) do
    socket =
      socket
      |> Mob.Socket.assign(tick_timer: nil, ticks: socket.assigns.ticks + 1)
      |> drain()
      |> maybe_refresh_devices()
      |> maybe_finish_calibration()
      |> schedule_tick()

    {:noreply, socket}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # The screen's own engine use ends with it: the mic and the clicks. The
  # lease sees this process end and sends the waiting practice screen
  # `{:audio_engine_reset}` (so a crash or kill does too).
  def terminate(_reason, socket) do
    a = socket.assigns
    if a[:tick_timer], do: Process.cancel_timer(a.tick_timer)
    if a[:audio], do: a.engine.release(a.audio)
    :ok
  end

  # ── Devices ──────────────────────────────────────────────────────────────

  defp outputs(devices) do
    devices
    |> Enum.filter(&(&1.direction == :output and &1.kind in @output_order))
    |> Enum.sort_by(&Enum.find_index(@output_order, fn kind -> kind == &1.kind end))
  end

  # Wired headphones and a wired headset are one row family.
  defp family(:wired_headset), do: :wired_headphones
  defp family(kind), do: kind

  # The output in use: the one picked here, else where Android routes by
  # default (headphones over the speaker).
  defp active_output(assigns) do
    outputs = outputs(assigns.devices)
    Enum.find(outputs, &(&1.id == assigns.output)) || List.first(outputs)
  end

  defp output_icon(:speaker), do: :phone
  defp output_icon(_kind), do: :headphones

  defp output_title(%{kind: :bluetooth}), do: "Bluetooth headphones"

  defp output_title(%{kind: kind}) when kind in [:wired_headphones, :wired_headset],
    do: "Wired headphones"

  defp output_title(%{kind: :usb}), do: "USB headphones"
  defp output_title(%{kind: :speaker}), do: "Phone speaker"
  defp output_title(%{name: name}), do: name

  @stereo "Stereo · your mix as set"

  defp output_detail(%{kind: :speaker}),
    do: "Mono, so balance has no effect. The mic will hear the music too."

  defp output_detail(%{kind: kind, name: name}) when kind in [:bluetooth, :usb] and name != "",
    do: "#{name} · #{@stereo}"

  defp output_detail(_device), do: @stereo

  defp phone_mic(devices),
    do: Enum.find(devices, &(&1.direction == :input and &1.kind == :builtin_mic))

  defp headset_mic(devices) do
    Enum.find(devices, &(&1.direction == :input and &1.kind in @headset_mics))
  end

  defp headset_detail(:bluetooth_sco), do: "Bluetooth drops to call quality: mono, muffled music"
  defp headset_detail(:wired_headset), do: "The microphone on your headphone cable"
  defp headset_detail(_kind), do: "The microphone on your headset"

  # Which microphone is in use: the one picked here; by default Android
  # takes a wired headset's, else the phone's.
  defp active_input(%{input: nil, devices: devices}) do
    if Enum.any?(devices, &(&1.direction == :input and &1.kind == :wired_headset)),
      do: :headset,
      else: :phone
  end

  defp active_input(%{input: id, devices: devices}) do
    case Enum.find(devices, &(&1.id == id)) do
      %{kind: kind} when kind in @headset_mics -> :headset
      _ -> :phone
    end
  end

  # A run in progress is cancelled first: its readings would mix two routes.
  # A listening microphone restarts on the new input, which can fail; one
  # that had failed is tried again.
  defp set_input(socket, id) do
    socket = stop_calibration(socket)
    a = socket.assigns
    :ok = Settings.put_input_pref(Enum.find(a.devices, &(&1.id == id)))
    notify(socket, {:audio_input, id})
    socket = Mob.Socket.assign(socket, input: id, confirm_input: nil)

    socket =
      case a.engine.set_input(a.audio, id) do
        {:ok, audio} -> socket |> Mob.Socket.assign(:audio, audio) |> listen()
        {:error, reason, audio} -> mic_failed(socket, audio, reason)
      end

    # The headset mic can move playback to the call route, with its own delay.
    refresh_devices(socket)
  end

  defp maybe_refresh_devices(%{assigns: %{ticks: ticks}} = socket)
       when rem(ticks, @devices_every) != 0,
       do: socket

  defp maybe_refresh_devices(socket), do: refresh_devices(socket)

  # The device list, and the route playing (it can change with no device
  # plugged in or out, e.g. once a stream opens).
  defp refresh_devices(socket) do
    a = socket.assigns
    socket |> Mob.Socket.assign(:devices, a.engine.devices(a.audio)) |> load_delay()
  end

  # ── Headphone delay ──────────────────────────────────────────────────────

  # The delay follows the route actually playing, as on the practice screen:
  # picking the Bluetooth headset microphone moves playback to the call route
  # (`:bluetooth_sco`), which keeps a delay of its own.
  defp delay_output(assigns) do
    a = assigns
    Settings.active_output(a.devices, a.engine.output_device(a.audio), a.output)
  end

  defp device_key(assigns),
    do: Settings.device_key(delay_output(assigns) || %{kind: :other, name: ""})

  defp load_delay(socket) do
    key = device_key(socket.assigns)

    Mob.Socket.assign(socket,
      delay: Settings.mic_delay_ms(key),
      delay_saved: Settings.known_device?(key),
      delay_speaker: match?(%{kind: :speaker}, delay_output(socket.assigns))
    )
  end

  defp save_delay(socket, ms) do
    ms = Settings.put_mic_delay_ms(device_key(socket.assigns), ms)
    notify(socket, {:mic_delay, ms})
    Mob.Socket.assign(socket, delay: ms, delay_saved: true)
  end

  defp notify(socket, message) do
    if pid = socket.assigns.practice, do: send(pid, message)
    :ok
  end

  # ── Microphone and calibration ───────────────────────────────────────────

  defp request_microphone(socket) do
    if device_calls?(),
      do: Mob.Permissions.request(socket, :microphone),
      else: socket |> Mob.Socket.assign(:mic, :granted) |> listen()
  end

  defp listen(%{assigns: %{mic: :granted, listening: false}} = socket) do
    a = socket.assigns

    case a.engine.listen(a.audio, :mic) do
      {:ok, audio} ->
        Mob.Socket.assign(socket, audio: audio, listening: true, mic_error: nil)

      {:error, reason, audio} ->
        mic_failed(socket, audio, reason)
    end
  end

  defp listen(socket), do: socket

  defp mic_failed(socket, audio, reason),
    do:
      Mob.Socket.assign(socket, audio: audio, listening: false, mic_error: reason, level_db: nil)

  defp audio_event(
         {:choir_audio, :ready, _info, _load},
         %{assigns: %{calibration: :loading}} = socket
       ),
       do: play_clicks(socket)

  defp audio_event(
         {:choir_audio, :load_error, _reason, _load},
         %{assigns: %{calibration: :loading}} = socket
       ),
       do: socket |> Mob.Socket.assign(:calibration, {:retry, :load_error}) |> listen()

  # The microphone failed while listening (unplugged, Bluetooth gone): stop
  # its stream and analysis, and the meter says so; picking a microphone or
  # coming back to the app retries.
  defp audio_event({:choir_audio, :mic_error, reason, _listen}, socket) do
    a = socket.assigns
    mic_failed(socket, a.engine.stop_listening(a.audio), reason)
  end

  # Another Audio screen took the engine: nothing here listens any more.
  defp audio_event({:choir_audio, :not_owner, _payload, _hold}, socket),
    do: Mob.Socket.assign(socket, listening: false, level_db: nil)

  # A run cancelled while loading: the clicks stay loaded and paused.
  defp audio_event(_event, socket), do: socket

  defp start_calibration(%{assigns: %{mic: mic}} = socket) when mic != :granted,
    do: Mob.Socket.assign(socket, :calibration, {:retry, :mic_off})

  # Loading the clicks closes the engine's microphone stream too, so listening
  # is off until `play_clicks/1` opens it again.
  defp start_calibration(socket) do
    a = socket.assigns
    audio = a.engine.pause(a.audio)

    Mob.Socket.assign(socket,
      audio: a.engine.load(audio, @clicks),
      calibration: :loading,
      listening: false
    )
  end

  defp play_clicks(socket) do
    a = socket.assigns
    audio = a.engine.set_mic_delay(a.audio, 0)
    # Drop what the mic heard before the first click.
    {_, audio} = a.engine.readings_with_level(audio)

    case a.engine.play(audio, 0.0) do
      {:ok, audio} ->
        socket
        |> Mob.Socket.assign(audio: audio, calibration: {:listening, []})
        |> listen()

      {:error, _reason, audio} ->
        socket
        |> Mob.Socket.assign(audio: audio, calibration: {:retry, :load_error})
        |> listen()
    end
  end

  # Cancelling a run (another output or microphone picked): quiet the clicks
  # and bring the meter back, since loading them closed the microphone.
  defp stop_calibration(%{assigns: %{calibration: c}} = socket)
       when c == :loading or (is_tuple(c) and elem(c, 0) == :listening) do
    a = socket.assigns

    socket
    |> Mob.Socket.assign(audio: a.engine.pause(a.audio), calibration: nil)
    |> listen()
  end

  defp stop_calibration(socket), do: Mob.Socket.assign(socket, :calibration, nil)

  # Readings feed the meter, and the calibration while it listens.
  defp drain(%{assigns: %{listening: false}} = socket), do: socket

  defp drain(socket) do
    a = socket.assigns
    {readings, audio} = a.engine.readings_with_level(a.audio)
    socket = Mob.Socket.assign(socket, :audio, audio)

    socket =
      case readings do
        [] ->
          socket

        _ ->
          Mob.Socket.assign(socket, :level_db, readings |> Enum.map(&elem(&1, 3)) |> Enum.max())
      end

    case a.calibration do
      {:listening, heard} ->
        Mob.Socket.assign(socket, :calibration, {:listening, heard ++ readings})

      _ ->
        socket
    end
  end

  defp maybe_finish_calibration(%{assigns: %{calibration: {:listening, heard}}} = socket) do
    a = socket.assigns
    clicks = Calibration.click_times_ms()
    done_at = List.last(clicks) + @clicks_tail_ms

    heard_to =
      case List.last(heard) do
        {ms, _, _, _} -> ms
        nil -> 0.0
      end

    {status, position} = a.engine.position(a.audio)

    if max(position, heard_to) >= done_at or (status == :paused and heard != []) do
      calibration =
        case heard |> Calibration.onsets(clicks) |> Calibration.result() do
          {:ok, ms} -> {:result, ms}
          {:retry, reason} -> {:retry, reason}
        end

      Mob.Socket.assign(socket, audio: a.engine.pause(a.audio), calibration: calibration)
    else
      socket
    end
  end

  defp maybe_finish_calibration(socket), do: socket

  # Ticks run while the screen is open (meter, calibration, device hot-plug),
  # whether or not the microphone could be opened.
  defp schedule_tick(%{assigns: %{tick_timer: nil}} = socket),
    do: Mob.Socket.assign(socket, :tick_timer, Process.send_after(self(), :tick, @tick_ms))

  defp schedule_tick(socket), do: socket

  # ── Device and icons ─────────────────────────────────────────────────────

  defp device_calls?, do: Application.get_env(:choir_coach, :device_calls, true)

  # Background / foreground events (`{:mob_device, …}`).
  defp subscribe_app(socket) do
    if device_calls?(), do: Mob.Device.subscribe(:app)
    Mob.Socket.assign(socket, :background, false)
  end

  defp screen_width(params) do
    case Map.get(params, :screen) do
      {w, _h} ->
        w

      nil ->
        if device_calls?(), do: :mob_nif.screen_info().width * 1.0, else: @fallback_width
    end
  end

  defp chevron_icon do
    [
      path([{26, 12}, {16, 22}, {26, 32}],
        color: Style.text_primary(),
        width: 2.6,
        cap: :round,
        join: :round
      )
    ]
  end

  defp check_icon do
    [
      path([{5, 15}, {11, 21}, {23, 8}],
        color: Style.text_primary(),
        width: 2.6,
        cap: :round,
        join: :round
      )
    ]
  end

  defp icon(:headphones, color) do
    [
      arc(14, 15, 10, 180, 360, color: color, width: 2.2, cap: :round),
      rect(3, 15, 6, 9, color: color, width: 2.2, radius: 2.5),
      rect(19, 15, 6, 9, color: color, width: 2.2, radius: 2.5)
    ]
  end

  defp icon(:phone, color) do
    [
      rect(8, 3, 12, 22, color: color, width: 2.2, radius: 3),
      line(12.5, 21, 15.5, 21, color: color, width: 2, cap: :round)
    ]
  end

  defp icon(:mic, color) do
    [
      rect(10, 3, 8, 14, color: color, width: 2.2, radius: 4),
      arc(14, 13, 7, 0, 180, color: color, width: 2.2, cap: :round),
      line(14, 20, 14, 25, color: color, width: 2.2, cap: :round)
    ]
  end
end
