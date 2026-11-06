defmodule ChoirCoach.ControlsView do
  @moduledoc """
  Canvas ops for the transport row (restart, back one bar, play / pause,
  loop, the mix), the progress track with its loop range, and the header's
  headphones icon.

  Each control is its own small canvas so it can take a tap. Icons are
  drawn from lines and arcs in the handoff's chrome colours; captions sit
  under the icon in the same canvas.
  """

  import Mob.Canvas

  alias ChoirCoach.Style

  @size 64
  @play 72

  def size, do: @size
  def play_size, do: @play

  @doc "Ops for a secondary control: `:restart`, `:back_bar`, `:loop` or `:mix`."
  @spec control(atom(), String.t(), boolean()) :: [map()]
  def control(kind, caption, active \\ false) do
    cx = @size / 2
    cy = 24

    List.flatten([
      if(active,
        do:
          rect(4, 0, @size - 8, @size,
            color: Style.accent(),
            fill: true,
            radius: 14,
            opacity: Style.alpha(:accent_fill)
          ),
        else: []
      ),
      icon(kind, cx, cy, if(active, do: Style.accent(), else: Style.text_secondary())),
      text(cx, 44, caption,
        color: if(active, do: Style.accent(), else: Style.text_tertiary()),
        size: Style.type(:caption),
        weight: if(active, do: :bold, else: :regular),
        anchor: :center
      )
    ])
  end

  @doc "Ops for the play / pause button."
  @spec play_button(boolean()) :: [map()]
  def play_button(playing) do
    c = @play / 2

    icon =
      if playing do
        [
          rect(c - 9, c - 11, 6, 22, color: Style.bg(), fill: true, radius: 2),
          rect(c + 3, c - 11, 6, 22, color: Style.bg(), fill: true, radius: 2)
        ]
      else
        path([{c - 7, c - 12}, {c + 12, c}, {c - 7, c + 12}], color: Style.bg(), fill: true)
      end

    List.flatten([circle(c, c, c, color: Style.play_button(), fill: true), icon])
  end

  defp icon(:restart, cx, cy, color) do
    [
      arc(cx, cy, 9, -60, 230, color: color, width: 2, cap: :round),
      path([{cx - 10, cy - 13}, {cx - 4, cy - 8}, {cx - 11, cy - 4}],
        color: color,
        width: 2,
        cap: :round,
        join: :round
      )
    ]
  end

  defp icon(:back_bar, cx, cy, color) do
    [
      path([{cx, cy - 8}, {cx - 9, cy}, {cx, cy + 8}],
        color: color,
        width: 2,
        closed: true,
        join: :round
      ),
      path([{cx + 9, cy - 8}, {cx, cy}, {cx + 9, cy + 8}],
        color: color,
        width: 2,
        closed: true,
        join: :round
      )
    ]
  end

  defp icon(:loop, cx, cy, color) do
    [
      path([{cx - 10, cy + 2}, {cx - 10, cy - 5}, {cx + 9, cy - 5}],
        color: color,
        width: 2,
        cap: :round,
        join: :round
      ),
      path([{cx + 5, cy - 9}, {cx + 9, cy - 5}, {cx + 5, cy - 1}],
        color: color,
        width: 2,
        cap: :round,
        join: :round
      ),
      path([{cx + 10, cy - 2}, {cx + 10, cy + 5}, {cx - 9, cy + 5}],
        color: color,
        width: 2,
        cap: :round,
        join: :round
      ),
      path([{cx - 5, cy + 1}, {cx - 9, cy + 5}, {cx - 5, cy + 9}],
        color: color,
        width: 2,
        cap: :round,
        join: :round
      )
    ]
  end

  # Three slider tracks with their knobs at different heights.
  defp icon(:mix, cx, cy, color) do
    for {dx, knob} <- [{-8, -3}, {0, 4}, {8, -6}] do
      [
        line(cx + dx, cy - 10, cx + dx, cy + 10, color: color, width: 2, cap: :round),
        line(cx + dx - 4, cy + knob, cx + dx + 4, cy + knob,
          color: color,
          width: 2.4,
          cap: :round
        )
      ]
    end
  end

  @doc "A headphones icon filling a `size`-square canvas, in `color`."
  @spec headphones(number(), non_neg_integer()) :: [map()]
  def headphones(size, color \\ Style.text_secondary()) do
    s = size / 28
    c = size / 2

    List.flatten([
      arc(c, c + 2 * s, 9 * s, 180, 360, color: color, width: 2 * s, cap: :round),
      line(c - 9 * s, c + 2 * s, c - 9 * s, c + 7 * s, color: color, width: 2 * s, cap: :round),
      line(c + 9 * s, c + 2 * s, c + 9 * s, c + 7 * s, color: color, width: 2 * s, cap: :round),
      rect(c - 11 * s, c + 4 * s, 5 * s, 8 * s, color: color, fill: true, radius: 2 * s),
      rect(c + 6 * s, c + 4 * s, 5 * s, 8 * s, color: color, fill: true, radius: 2 * s)
    ])
  end

  @doc """
  Progress track: played portion, the loop range in the UI accent, and the
  position knob. `fraction` and the loop bounds are 0..1 of the section.
  """
  @spec progress(number(), number(), {number(), number()} | nil) :: [map()]
  def progress(width, fraction, loop) do
    y = 12
    knob_x = width * min(max(fraction, 0), 1)

    List.flatten([
      line(0, y, width, y, color: Style.neutral(), width: 3, cap: :round, opacity: 0.22),
      loop_range(width, y, loop),
      line(0, y, knob_x, y, color: Style.text_primary(), width: 3, cap: :round, opacity: 0.85),
      circle(knob_x, y, 7, color: Style.text_primary(), fill: true)
    ])
  end

  defp loop_range(_width, _y, nil), do: []

  defp loop_range(width, y, {from, to}) do
    x0 = width * from
    x1 = width * to

    [
      rect(x0, y - 8, x1 - x0, 16,
        color: Style.accent(),
        fill: true,
        radius: 8,
        opacity: Style.alpha(:accent_fill)
      ),
      line(x0 + 1, y - 7, x0 + 1, y + 7, color: Style.accent(), width: 2, cap: :round),
      line(x1 - 1, y - 7, x1 - 1, y + 7, color: Style.accent(), width: 2, cap: :round)
    ]
  end
end
