defmodule ChoirCoach.SongsScreen do
  @moduledoc """
  The app's first screen: the singer's part (Soprano, Alto, Tenor or Bass,
  remembered in `ChoirCoach.Settings`) and the songs to practise. Tapping a
  song opens the practice screen on that part, with the melody to switch to.
  """

  use Mob.Screen

  alias ChoirCoach.{PracticeScreen, Settings, Song, Songs, Style}

  def mount(params, _session, socket) do
    modules = Map.get(params, :songs, Songs.all())

    {:ok,
     Mob.Socket.assign(socket, songs: Enum.map(modules, &entry/1), my_part: Settings.my_part())}
  end

  defp entry(module) do
    song = module.bass()
    %{module: module, title: song.title, facts: facts(song)}
  end

  @doc false
  # The card's second line, e.g. "D major · ♩ = 72 · 98 bars · 4:58".
  def facts(song) do
    secs = round((Song.duration_ms(song) - Song.start_ms(song)) / 1000)

    clock =
      "#{div(secs, 60)}:#{secs |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")}"

    "#{Song.key_name(song)} · ♩ = #{round(song.tempo_bpm)} · #{length(song.bars)} bars · #{clock}"
  end

  def render(assigns) do
    ~MOB"""
    <Column background={Style.bg()} fill_height={true} padding_left={20} padding_right={20} gap={12}>
      <Column padding_top={12} padding_bottom={4}>
        <Text
          text="Choir Coach"
          text_size={Style.type(:active_lyric)}
          text_color={Style.text_primary()}
          font_weight="bold"
        />
        <Text
          text="Your part, then a song"
          text_size={Style.type(:subtitle)}
          text_color={Style.text_tertiary()}
        />
      </Column>
      {part_picker(assigns.my_part)}
      {Enum.map(assigns.songs, &card/1)}
    </Column>
    """
  end

  # Soprano · Alto · Tenor · Bass, the singer's own filled in its colour.
  defp part_picker(mine) do
    segments =
      for part <- Settings.voice_parts() do
        selected = part == mine
        tap = {self(), {:my_part, part}}

        ~MOB"""
        <Box
          id={"my_part_#{part}"}
          background={if(selected, do: Style.swatch(part), else: 0x00000000)}
          corner_radius={18}
          padding_top={9}
          padding_bottom={9}
          weight={1}
          on_tap={tap}
        >
          <Text
            text={part |> Atom.to_string() |> String.capitalize()}
            text_size={Style.type(:status)}
            text_color={if(selected, do: Style.bg(), else: Style.text_primary())}
            font_weight="bold"
            text_align="center"
            fill_width={true}
          />
        </Box>
        """
      end

    ~MOB"""
    <Box background={0x24FFFFFF} corner_radius={22} padding={4}>
      <Row>
        {segments}
      </Row>
    </Box>
    """
  end

  defp card(%{module: module, title: title, facts: facts}) do
    tap = {self(), {:open, module}}

    ~MOB"""
    <Box background={0x24FFFFFF} corner_radius={16} padding={16} on_tap={tap}>
      <Column gap={4}>
        <Text
          text={title}
          text_size={Style.type(:title)}
          text_color={Style.text_primary()}
          font_weight="bold"
          max_lines={1}
        />
        <Text
          text={facts}
          text_size={Style.type(:subtitle)}
          text_color={Style.text_secondary()}
          max_lines={1}
        />
      </Column>
    </Box>
    """
  end

  def handle_info({:tap, {:my_part, part}}, socket) do
    if part in Settings.voice_parts() do
      :ok = Settings.put_my_part(part)
      {:noreply, Mob.Socket.assign(socket, :my_part, part)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:tap, {:open, module}}, socket) do
    if module in Enum.map(socket.assigns.songs, & &1.module) do
      parts = Songs.parts(module, socket.assigns.my_part)
      {:noreply, Mob.Socket.push_screen(socket, PracticeScreen, %{parts: parts})}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}
end
