defmodule ChoirCoach.Window do
  @moduledoc """
  The size a screen lays out for, and the layout it picks for it.

  A screen takes its size at mount (`size/1`: the `:screen` param, else the
  device's screen) and keeps `screen_w`, `screen_h` and `layout` (`:phone`
  or `:tablet`, from the screen's own rule) in its assigns. `follow/1`
  subscribes it to rotations; on a rotation or a size-class change (Split
  View, Slide Over, Stage Manager, Android multi-window, a foldable)
  `refresh/2` reads the size again, unless the window's size class was and
  still is a phone's (not regular both ways): a phone keeps the size it
  mounted with, as it always has. A regular-by-regular window always takes
  the new size, whichever layout fits it.

  Mob reports the screen's size, not the window's (`UIScreen.bounds` on
  iOS), so a window narrower than the screen is measured as the screen.
  """

  alias ChoirCoach.Style

  # The reference artboard, where the device can't be asked (host tests,
  # which may set another as `config :choir_coach, :screen`).
  @fallback {390.0, 844.0}

  @doc "The size to lay out for at mount: `params.screen`, else the device's."
  def size(params), do: Map.get_lazy(params, :screen, &current/0)

  @doc "The device's screen size now, `{width, height}` in pt / dp."
  def current do
    if device_calls?() do
      %{width: w, height: h} = :mob_nif.screen_info()
      {w * 1.0, h * 1.0}
    else
      Application.get_env(:choir_coach, :screen, @fallback)
    end
  end

  @doc "Subscribe the calling screen to rotations, plus Mob.Device `categories`."
  def follow(categories \\ []) do
    if device_calls?(), do: Mob.Device.subscribe([:display | categories])
    :ok
  end

  @doc """
  Assign the size `{w, h}`, the layout `layout_of` makes of the assigns
  with it, and the size class it was taken for.
  """
  def assign(socket, {w, h}, layout_of) do
    socket = Mob.Socket.assign(socket, screen_w: w, screen_h: h)

    Mob.Socket.assign(socket,
      layout: layout_of.(socket.assigns),
      sized_for: socket.assigns[:size_class]
    )
  end

  @doc """
  After a rotation or a size-class change (`assigns.size_class` already the
  new one): the size now and its layout, unless the size class it was taken
  for and the new one are both a phone's.
  """
  def refresh(socket, layout_of) do
    a = socket.assigns

    if Style.layout(a.sized_for) == :phone and Style.layout(a[:size_class]) == :phone,
      do: Mob.Socket.assign(socket, :sized_for, a[:size_class]),
      else: assign(socket, current(), layout_of)
  end

  defp device_calls?, do: Application.get_env(:choir_coach, :device_calls, true)
end
