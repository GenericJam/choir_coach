defmodule ChoirCoach.Feedback do
  @moduledoc """
  Turns the raw per-frame pitch error into what the screen shows, following
  the handoff's motion rules so the display settles instead of flickering:

    * colour eases toward the current error over ~120 ms, and the status
      wording reads that eased value, so a quick scoop into a note doesn't
      flash "a little low";
    * glow radius follows a critically damped spring (~200 ms);
    * a new wording shows at once, then holds for at least 250 ms, with ±3¢
      hysteresis at each band edge;
    * the glow "breathes" (slow 1.6 s, ±6 %) only once the singer has been
      more than 35¢ off for 500 ms; within ±10¢ it is static.

  `update/3` is pure: it takes the previous state, the error in cents (nil
  while nothing is sung) and the frame's timestamp.
  """

  alias ChoirCoach.Style

  @color_tau_ms 120.0
  @spring_omega 20.0
  @status_hold_ms 250
  @hysteresis 3.0
  @far_breath_cents 35.0
  @far_breath_after_ms 500
  @breath_period_ms 1600.0
  @breath_depth 0.06

  @type status ::
          :on_pitch | {:low | :high, :slightly | :far} | :breathe

  @type t :: %__MODULE__{
          cents: float() | nil,
          color_cents: float(),
          glow_r: float(),
          glow_v: float(),
          status: status(),
          status_since: integer() | nil,
          far_since: integer() | nil,
          last_ms: integer() | nil
        }

  defstruct cents: nil,
            color_cents: 0.0,
            glow_r: 30.0,
            glow_v: 0.0,
            status: :breathe,
            status_since: nil,
            far_since: nil,
            last_ms: nil

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Advance the smoother to `now_ms` with the current error (nil = silence)."
  @spec update(t(), float() | nil, integer()) :: t()
  def update(%__MODULE__{} = s, cents, now_ms) do
    dt = if s.last_ms, do: max(now_ms - s.last_ms, 0), else: 0

    s
    |> ease_color(cents, dt)
    |> Map.put(:cents, cents)
    |> spring_glow(cents, dt)
    |> track_far(cents, now_ms)
    |> settle_status(cents, now_ms)
    |> Map.put(:last_ms, now_ms)
  end

  # The scale saturates at ±50¢; clamping the input keeps one wild reading
  # (a wrong octave, a cough) from dragging the colour for seconds after.
  # After silence the colour starts from on-target rather than the last
  # phrase's colour, and eases in like any change: taking the first reading
  # as is would flash "a little low" on every entry, since a voice scoops up
  # into a new phrase.
  defp ease_color(s, nil, _dt), do: s

  defp ease_color(%{cents: nil} = s, cents, dt),
    do: ease_color(%{s | cents: 0.0, color_cents: 0.0}, cents, dt)

  defp ease_color(s, cents, dt) do
    k = 1.0 - :math.exp(-dt / @color_tau_ms)
    %{s | color_cents: s.color_cents + (clamp_cents(cents) - s.color_cents) * k}
  end

  defp clamp_cents(c), do: c |> max(-60.0) |> min(60.0)

  defp spring_glow(s, nil, _dt), do: s

  defp spring_glow(s, cents, dt) do
    {target, _alpha} = Style.glow(cents)
    # Semi-implicit Euler in small steps keeps the spring stable at any frame time.
    steps = max(1, ceil(dt / 8))
    h = dt / 1000.0 / steps

    {r, v} =
      Enum.reduce(1..steps, {s.glow_r, s.glow_v}, fn _, {r, v} ->
        a = @spring_omega * @spring_omega * (target - r) - 2 * @spring_omega * v
        v = v + a * h
        {r + v * h, v}
      end)

    %{s | glow_r: r, glow_v: v}
  end

  defp track_far(%{color_cents: c} = s, cents, now_ms)
       when is_number(cents) and abs(c) > @far_breath_cents do
    %{s | far_since: s.far_since || now_ms}
  end

  defp track_far(s, _cents, _now_ms), do: %{s | far_since: nil}

  defp settle_status(s, cents, now_ms) do
    reading = classify(cents && s.color_cents, s.status)
    held = s.status_since == nil or now_ms - s.status_since >= @status_hold_ms

    if reading != s.status and held,
      do: %{s | status: reading, status_since: now_ms},
      else: s
  end

  @doc """
  The status band for `cents`, given the currently shown status. Edges move
  outward by 3¢ away from the current band so a reading hovering on a
  boundary doesn't flip the wording back and forth.
  """
  @spec classify(float() | nil, status()) :: status()
  def classify(nil, _current), do: :breathe

  def classify(cents, current) do
    {on_edge, far_edge} = edges(current)
    a = abs(cents)
    dir = if cents < 0, do: :low, else: :high

    cond do
      a <= on_edge -> :on_pitch
      a < far_edge -> {dir, :slightly}
      true -> {dir, :far}
    end
  end

  defp edges(:on_pitch), do: {10.0 + @hysteresis, 30.0}
  defp edges({_, :slightly}), do: {10.0 - @hysteresis, 30.0 + @hysteresis}
  defp edges({_, :far}), do: {10.0, 30.0 - @hysteresis}
  defp edges(:breathe), do: {10.0, 30.0}

  @doc "Glow radius to draw now, including the slow breath when held far off."
  @spec glow_radius(t(), integer()) :: float()
  def glow_radius(%__MODULE__{far_since: since} = s, now_ms)
      when is_integer(since) and now_ms - since >= @far_breath_after_ms do
    phase = 2 * :math.pi() * (now_ms - since) / @breath_period_ms
    s.glow_r * (1.0 + @breath_depth * :math.sin(phase))
  end

  def glow_radius(%__MODULE__{glow_r: r}, _now_ms), do: r
end
