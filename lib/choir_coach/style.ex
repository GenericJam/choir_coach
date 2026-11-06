defmodule ChoirCoach.Style do
  @moduledoc """
  Design tokens for the live practice screen, taken from the Claude Design
  handoff ("Choir Pitch Coach", reference artboard 390 × 844 pt).

  Colours are ARGB integers (`0xAARRGGBB`), which `Mob.Canvas` ops and node
  colour props accept directly. Opacity stays separate (the canvas `:opacity`
  modifier) so one hue can be reused at the alphas the handoff specifies.

  Feedback hues (the pitch scale) never colour chrome; the UI accent is a
  warm ivory so loop and "next" cues can't be read as pitch feedback.
  """

  import Bitwise

  # ── Surface & UI ────────────────────────────────────────────────────────

  @doc "Solid page background (bg/base)."
  def bg, do: 0xFF0E1217

  @doc "Lane lines, the active band and the playhead are white at low alpha."
  def white, do: 0xFFFFFFFF

  @doc "Neutral used for note bars, staff lines and past noteheads."
  def neutral, do: 0xFFC9D1DB

  @doc "Future noteheads on the staff."
  def notehead_future, do: 0xFFDDE2E8

  @doc "Playhead and target line."
  def playhead, do: 0xFFF4F6F8

  def text_primary, do: 0xFFF4F6F8
  def text_secondary, do: 0xFFC9D1DB
  def text_tertiary, do: 0xFF8A94A3
  def text_syllable, do: 0xFFAEB7C2

  @doc "UI accent for loop and next-cue chrome."
  def accent, do: 0xFFE9E4D8

  def play_button, do: 0xFFF2EEE6

  @doc "The mix sheet's surface, and the raised cards inside it (open rows, the ear map)."
  def surface, do: 0xFF161C24
  def surface_raised, do: 0xFF1E252E

  @doc """
  Mix swatch colours: the part's (bass a warm tan, the melody a soft rose)
  and the band's grey. Like the UI accent they sit outside the pitch scale,
  so a swatch can't be read as pitch feedback.
  """
  def swatch(:bass), do: 0xFFE2BE8C
  def swatch(:melody), do: 0xFFE3B2A4
  def swatch(:band), do: 0xFFAEB7C2

  # ── Alphas ──────────────────────────────────────────────────────────────

  def alpha(:active_band), do: 0.025
  def alpha(:semitone_line), do: 0.04
  def alpha(:beat_line), do: 0.03
  def alpha(:bar_line), do: 0.07
  def alpha(:note_future_fill), do: 0.16
  def alpha(:note_future_stroke), do: 0.30
  def alpha(:note_past_fill), do: 0.07
  def alpha(:note_past_stroke), do: 0.12
  def alpha(:note_active_fill), do: 0.14
  def alpha(:note_active_sung), do: 0.32
  def alpha(:note_active_stroke), do: 0.90
  def alpha(:playhead_line), do: 0.16
  def alpha(:playhead_core), do: 0.50
  def alpha(:target_line), do: 0.95
  def alpha(:target_tail), do: 0.35
  def alpha(:stem), do: 0.80
  def alpha(:trace_underlay), do: 0.17
  def alpha(:trace_low_confidence), do: 0.35
  def alpha(:head_halo), do: 0.22
  def alpha(:staff_line), do: 0.32
  def alpha(:staff_bar_line), do: 0.45
  def alpha(:notehead_past), do: 0.40
  def alpha(:column_wash), do: 0.10
  def alpha(:accent_fill), do: 0.14
  def alpha(:status_pill), do: 0.18

  # ── Geometry (pt / dp) ──────────────────────────────────────────────────

  @doc "Seconds of music visible behind the playhead at the design's time scale."
  def past_seconds, do: 1.75

  @doc "Seconds of music visible ahead of the playhead at the design's time scale."
  def future_seconds, do: 2.9

  @doc """
  Minimum width of one beat, in dp. The design's 2.9 s look-ahead makes an
  eighth note at ♩ = 105 about 25 dp wide, narrower than its syllable; this
  floor zooms in on faster songs so an eighth is at least 32 dp, at the cost
  of look-ahead (about one bar of 4/4 on a 411 dp phone).
  """
  def min_beat_dp, do: 64.0

  @doc "Playhead position as a fraction of the canvas width."
  def playhead_fraction, do: 0.375

  @doc "Vertical scale: dp per semitone. Short phones (≤ 700 tall) use 32."
  def semitone_dp(screen_height) when screen_height <= 700, do: 32.0
  def semitone_dp(_screen_height), do: 40.0

  def note_bar_height, do: 24.0
  def note_bar_radius, do: 12.0
  def note_gap, do: 4.0

  def trace_core_width, do: 4.0
  def trace_underlay_width, do: 12.0
  def trace_low_confidence_width, do: 2.0
  def head_radius, do: 7.0
  def head_ring_width, do: 3.0
  def head_halo_radius, do: 13.0

  def side_gutter, do: 20.0
  def edge_fade_left, do: 28.0
  def edge_fade_right, do: 38.0

  @doc "Staff strip: line spacing and the strip's height inside the canvas."
  def staff_space, do: 10.0
  def staff_strip_height, do: 106.0
  def staff_clef_zone, do: 58.0
  def staff_clef_fade, do: 20.0

  # ── Typography (size in dp) ─────────────────────────────────────────────

  def type(:active_lyric), do: 54
  def type(:expected_note), do: 26
  def type(:status), do: 15
  def type(:title), do: 17
  def type(:subtitle), do: 13
  def type(:syllable), do: 13
  def type(:syllable_active), do: 14
  def type(:caption), do: 11
  def type(:staff_lyric), do: 14

  # ── Pitch-feedback scale ────────────────────────────────────────────────

  # Stops from the handoff, cents → RGB. Flat runs cool and darker, sharp runs
  # warm and lighter, so the two sides separate by lightness as well as hue.
  @stops [
    {-50, 0x7C7CFF},
    {-25, 0x4FB3F6},
    {-10, 0x48CFD2},
    {0, 0x5EE0A8},
    {12, 0xD6D877},
    {25, 0xF5B84B},
    {50, 0xFF7A45}
  ]

  @doc """
  Feedback colour for a pitch error in cents, as ARGB.

  Linear sRGB interpolation between neighbouring stops; clamped beyond ±50¢.
  """
  @spec cents_color(number()) :: non_neg_integer()
  def cents_color(cents) do
    c = clamp(cents, -50, 50)

    {{c0, rgb0}, {c1, rgb1}} =
      @stops
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.find(fn [{lo, _}, {hi, _}] -> c >= lo and c <= hi end)
      |> List.to_tuple()

    t = if c1 == c0, do: 0.0, else: (c - c0) / (c1 - c0)
    0xFF000000 ||| lerp_rgb(rgb0, rgb1, t)
  end

  @doc "The handoff's stops, for the legend and tests."
  def cents_stops, do: Enum.map(@stops, fn {c, rgb} -> {c, 0xFF000000 ||| rgb} end)

  @doc """
  Glow radius and alpha for an absolute pitch error |c| in cents:
  `glowR = 30 + 0.7·|c|`, `glowA = min(0.42, 0.22 + 0.004·|c|)`, |c| capped at 50.
  """
  @spec glow(number()) :: {float(), float()}
  def glow(cents) do
    a = min(abs(cents), 50)
    {30.0 + 0.7 * a, min(0.42, 0.22 + 0.004 * a)}
  end

  @doc "Trace stroke width: 5 pt from 30¢ off, 4 pt otherwise."
  def trace_width(cents) when abs(cents) >= 30, do: 5.0
  def trace_width(_cents), do: 4.0

  @doc """
  Feedback band for a pitch error: `:on_pitch` within ±10¢, `:slightly` up to
  30¢, `:far` beyond. Paired with a direction this picks the status wording,
  the chevron count and whether the target→head stem shows.
  """
  @spec band(number()) :: :on_pitch | :slightly | :far
  def band(cents) when abs(cents) <= 10, do: :on_pitch
  def band(cents) when abs(cents) < 30, do: :slightly
  def band(_cents), do: :far

  defp clamp(v, lo, hi), do: v |> max(lo) |> min(hi)

  defp lerp_rgb(a, b, t) do
    channel = fn shift ->
      ca = a >>> shift &&& 0xFF
      cb = b >>> shift &&& 0xFF
      round(ca + (cb - ca) * t) <<< shift
    end

    channel.(16) ||| channel.(8) ||| channel.(0)
  end
end
