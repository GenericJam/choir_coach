defmodule ChoirCoach.SettingsScreen do
  @moduledoc """
  Settings, opened from the practice screen's gear. For now one setting:
  the headphone delay, so the sung line lands on the notes with wired or
  Bluetooth headphones. Each change is saved and sent to the practice
  screen (`params.practice`) as `{:mic_delay, ms}`.
  """

  use Mob.Screen

  alias ChoirCoach.{Settings, Style}

  def mount(params, _session, socket) do
    {:ok,
     Mob.Socket.assign(socket,
       practice: Map.get(params, :practice),
       delay: Settings.mic_delay_ms()
     )}
  end

  def render(assigns) do
    {min, max} = Settings.delay_range()
    back = {self(), :back}
    slider = {self(), :delay}
    minus = {self(), :minus}
    plus = {self(), :plus}
    wired = {self(), :preset_wired}
    bluetooth = {self(), :preset_bluetooth}
    presets = Settings.presets()

    ~MOB"""
    <Column background={Style.bg()} fill_height={true} padding_left={20} padding_right={20} gap={16}>
      <Row height={55} align={:center}>
        <Text
          text="‹ Back"
          on_tap={back}
          text_size={Style.type(:status)}
          text_color={Style.text_secondary()}
          padding={8}
        />
        <Spacer />
        <Text
          text="Settings"
          text_size={Style.type(:title)}
          text_color={Style.text_primary()}
          font_weight="bold"
        />
        <Spacer />
        <Spacer size={72} />
      </Row>
      <Text
        text="Headphone delay"
        text_size={Style.type(:status)}
        text_color={Style.text_primary()}
        font_weight="bold"
      />
      <Text
        text="How late the microphone hears you compared with the music in your headphones. Wired headphones are usually about 60 ms; Bluetooth adds more."
        text_size={Style.type(:subtitle)}
        text_color={Style.text_tertiary()}
      />
      <Row align={:center}>
        {chip("−10", minus, 76)}
        <Spacer />
        <Text
          text={"#{assigns.delay} ms"}
          text_size={34}
          text_color={Style.text_primary()}
          font_weight="bold"
        />
        <Spacer />
        {chip("+10", plus, 76)}
      </Row>
      <Slider
        value={assigns.delay * 1.0}
        min={min * 1.0}
        max={max * 1.0}
        on_change={slider}
        color={Style.accent()}
      />
      <Row gap={12}>
        {chip("Wired #{presets[:wired]} ms", wired, :grow)}
        {chip("Bluetooth #{presets[:bluetooth]} ms", bluetooth, :grow)}
      </Row>
      <Text
        text="To fine-tune: sing a held note and come in right on the beat. If your line starts after the note's bar, raise the delay; if it starts before it, lower it."
        text_size={Style.type(:subtitle)}
        text_color={Style.text_secondary()}
      />
    </Column>
    """
  end

  # A tappable rounded button in the practice screen's chrome style: either
  # sharing a row equally (`:grow`) or a fixed `width` in dp.
  defp chip(label, tap, :grow) do
    ~MOB"""
    <Box background={0x24FFFFFF} corner_radius={14} padding={14} weight={1} on_tap={tap}>
      {chip_label(label)}
    </Box>
    """
  end

  defp chip(label, tap, width) when is_number(width) do
    ~MOB"""
    <Box background={0x24FFFFFF} corner_radius={14} padding={14} width={width} on_tap={tap}>
      {chip_label(label)}
    </Box>
    """
  end

  defp chip_label(label) do
    ~MOB"""
    <Text
      text={label}
      text_size={Style.type(:status)}
      text_color={Style.text_primary()}
      font_weight="bold"
      text_align="center"
      max_lines={1}
    />
    """
  end

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  def handle_info({:change, :delay, value}, socket), do: {:noreply, set_delay(socket, value)}

  def handle_info({:tap, :minus}, socket),
    do: {:noreply, set_delay(socket, socket.assigns.delay - Settings.delay_step())}

  def handle_info({:tap, :plus}, socket),
    do: {:noreply, set_delay(socket, socket.assigns.delay + Settings.delay_step())}

  def handle_info({:tap, :preset_wired}, socket),
    do: {:noreply, set_delay(socket, Settings.presets()[:wired])}

  def handle_info({:tap, :preset_bluetooth}, socket),
    do: {:noreply, set_delay(socket, Settings.presets()[:bluetooth])}

  def handle_info(_message, socket), do: {:noreply, socket}

  defp set_delay(socket, ms) do
    if Settings.clamp_delay(ms) == socket.assigns.delay do
      socket
    else
      ms = Settings.put_mic_delay_ms(ms)
      if socket.assigns.practice, do: send(socket.assigns.practice, {:mic_delay, ms})
      Mob.Socket.assign(socket, :delay, ms)
    end
  end
end
