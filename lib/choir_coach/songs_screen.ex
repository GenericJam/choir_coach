defmodule ChoirCoach.SongsScreen do
  @moduledoc """
  The app's first screen: the songs to practise. Tapping one opens the
  practice screen on its bass part and recordings.
  """

  use Mob.Screen

  alias ChoirCoach.{PracticeScreen, Song, Songs, Style}

  def mount(params, _session, socket) do
    modules = Map.get(params, :songs, Songs.all())
    {:ok, Mob.Socket.assign(socket, songs: Enum.map(modules, &entry/1))}
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
      <Column padding_top={12} padding_bottom={8}>
        <Text
          text="Choir Coach"
          text_size={Style.type(:active_lyric)}
          text_color={Style.text_primary()}
          font_weight="bold"
        />
        <Text
          text="Bass · pick a song"
          text_size={Style.type(:subtitle)}
          text_color={Style.text_tertiary()}
        />
      </Column>
      {Enum.map(assigns.songs, &card/1)}
    </Column>
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

  def handle_info({:tap, {:open, module}}, socket) do
    if module in Enum.map(socket.assigns.songs, & &1.module) do
      {:noreply,
       Mob.Socket.push_screen(socket, PracticeScreen, %{
         song: module.bass(),
         tracks: module.tracks()
       })}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}
end
