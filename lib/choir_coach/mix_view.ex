defmodule ChoirCoach.MixView do
  @moduledoc """
  Canvas ops for the mix sheet: each row's swatch, and the ear map.

  A source is drawn as a disc in its colour: the part's tan or rose with its
  letter, the part on piano as an outlined disc with a keyboard, the band in
  grey with three lines. An off row's swatch is a dashed outline at 55 %
  opacity. The ear map is read-only: one disc per row that's on, at x = its
  balance and y = its level, and a bar at each edge for how loud that ear is.
  """

  import Mob.Canvas

  alias ChoirCoach.{Mix, Style}

  @off_opacity 0.55

  @doc "A row's swatch, filling a `size`-square canvas."
  @spec swatch(atom(), map(), number()) :: [map()]
  def swatch(part, row, size) do
    c = size / 2
    r = c - 2

    if row.on do
      disc(part, row, c, c, r, 1.0)
    else
      List.flatten([
        circle(c, c, r, color: color(part, row), width: 1.5, dash: [3, 3], opacity: @off_opacity),
        glyph(part, row, c, c, r, @off_opacity, false)
      ])
    end
  end

  @doc """
  The ear map, `width` × `height`: dots for the rows that are on, edge bars
  for each ear's loudness. On a mono output every dot sits in the middle.
  """
  @spec ear_map(Mix.t(), boolean(), number(), number()) :: [map()]
  def ear_map(mix, mono?, width, height) do
    {left, right} = Mix.ear_levels(mix, mono?)
    bar_h = height - 28
    mid = width / 2
    reach = mid - 52

    dots =
      for row <- mix.rows, row.on do
        x = if mono?, do: mid, else: mid + row.balance / 100 * reach
        y = height - 18 - row.level / 100 * (height - 40)
        disc(mix.part, row, x, y, 13, 1.0)
      end

    List.flatten([
      rect(0, 0, width, height, color: Style.surface_raised(), fill: true, radius: 14),
      line(mid, 10, mid, height - 10,
        color: Style.text_tertiary(),
        width: 1,
        dash: [3, 4],
        opacity: 0.6
      ),
      text(16, 8, "L", color: Style.text_tertiary(), size: Style.type(:caption), weight: :bold),
      text(width - 24, 8, "R",
        color: Style.text_tertiary(),
        size: Style.type(:caption),
        weight: :bold
      ),
      ear_bar(10, height - 14, bar_h, left),
      ear_bar(width - 16, height - 14, bar_h, right),
      dots
    ])
  end

  defp ear_bar(x, bottom, full, level) do
    h = max(full * min(level, 1.0), 2)

    [
      rect(x, bottom - full, 6, full, color: Style.white(), fill: true, radius: 3, opacity: 0.08),
      rect(x, bottom - h, 6, h, color: Style.accent(), fill: true, radius: 3)
    ]
  end

  defp disc(part, row, cx, cy, r, opacity) do
    filled? = row.id != :part_piano

    List.flatten([
      if(filled?,
        do: circle(cx, cy, r, color: color(part, row), fill: true, opacity: opacity),
        else: [
          circle(cx, cy, r, color: Style.bg(), fill: true, opacity: opacity),
          circle(cx, cy, r, color: color(part, row), width: 2, opacity: opacity)
        ]
      ),
      glyph(part, row, cx, cy, r, opacity, filled?)
    ])
  end

  # The part on piano: a small keyboard.
  defp glyph(part, %{id: :part_piano} = row, cx, cy, r, opacity, _filled?) do
    w = r * 1.1
    h = r * 0.75
    x0 = cx - w / 2
    y0 = cy - h / 2
    c = color(part, row)

    [
      rect(x0, y0, w, h, color: c, width: 1.6, radius: 1.5, opacity: opacity)
      | for(
          i <- 1..3,
          do:
            line(x0 + i * w / 4, y0, x0 + i * w / 4, y0 + h * 0.6,
              color: c,
              width: 1.4,
              opacity: opacity
            )
        )
    ]
  end

  # The band: three lines.
  defp glyph(_part, %{id: :band}, cx, cy, r, opacity, filled?) do
    c = if filled?, do: Style.bg(), else: Style.swatch(:band)

    for dy <- [-0.32, 0, 0.32] do
      line(cx - r * 0.38, cy + dy * r, cx + r * 0.38, cy + dy * r,
        color: c,
        width: 1.8,
        cap: :round,
        opacity: opacity
      )
    end
  end

  # Voices: the part's letter (B for bass, S for the sopranos who lead the melody).
  defp glyph(part, row, cx, cy, r, opacity, filled?) do
    size = round(r * 0.95)

    text(cx, cy - size * 0.62, letter(part),
      color: if(filled?, do: Style.bg(), else: color(part, row)),
      size: size,
      weight: :bold,
      anchor: :center,
      opacity: opacity
    )
  end

  defp letter(:bass), do: "B"
  defp letter(:melody), do: "S"
  defp letter(part), do: part |> Atom.to_string() |> String.first() |> String.upcase()

  defp color(_part, %{id: :band}), do: Style.swatch(:band)
  defp color(part, _row), do: Style.swatch(part)
end
