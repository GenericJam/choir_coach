defmodule ChoirCoach.Calibration do
  @moduledoc """
  "Set by singing along": the singer hears 8 clicks at 90 bpm
  (`priv/sounds/clicks_90.mp3`) through the chosen output and sings "ta" on
  each. Each click's sung onset, minus the click, is that click's offset;
  the headphone delay is their median, rounded to 10 ms.

  An onset is the first reading, 0–600 ms after a click, that is either
  12 dB or more above the mean level of the preceding 100 ms, or the start
  of a confident voiced pitch. Fewer than 5 onsets, or offsets that spread more than 40 ms
  (max − min once the lowest and highest are set aside), ask the singer to
  try again.
  """

  @clicks 8
  @first_click_ms 1000.0
  @beat_ms 60_000 / 90
  @window_ms 600
  @floor_ms 100
  @jump_db 12.0
  @min_confidence 0.5
  @min_onsets 5
  @max_spread_ms 40
  @max_delay_ms 400

  @type reading :: {number(), number() | nil, number(), number()}

  @doc "The clicks' onsets in the click file, in ms."
  @spec click_times_ms() :: [float()]
  def click_times_ms, do: for(n <- 0..(@clicks - 1), do: @first_click_ms + n * @beat_ms)

  @doc """
  Per click, the sung onset's offset after the click in whole ms, or nil
  when nothing was sung within 600 ms of it. `readings` are
  `{song_ms, midi | nil, confidence, rms_db}`.
  """
  @spec onsets([reading()], [number()]) :: [integer() | nil]
  def onsets(readings, click_times) do
    readings = Enum.sort_by(readings, &elem(&1, 0))
    Enum.map(click_times, &offset(readings, &1))
  end

  defp offset(readings, click) do
    [nil | readings]
    |> Enum.zip(readings)
    |> Enum.filter(fn {_prev, {t, _, _, _}} -> t >= click and t <= click + @window_ms end)
    |> Enum.find(&onset?(&1, readings))
    |> case do
      nil -> nil
      {_prev, {t, _, _, _}} -> round(t - click)
    end
  end

  # A voiced reading after an unvoiced one, or a jump in level.
  defp onset?({prev, reading}, readings),
    do: (voiced?(reading) and not voiced?(prev)) or jump?(reading, readings)

  defp voiced?({_t, midi, conf, _db}), do: midi != nil and conf >= @min_confidence
  defp voiced?(nil), do: false

  defp jump?({t, _midi, _conf, db}, readings) do
    case for {s, _, _, d} <- readings, s >= t - @floor_ms and s < t, do: d do
      [] -> false
      floor -> db - Enum.sum(floor) / length(floor) >= @jump_db
    end
  end

  @doc """
  The delay from the per-click offsets (nil = missed click): `{:ok, ms}`
  (median, rounded to 10 ms, within 0–400 ms), or `{:retry, :too_few_onsets}`
  / `{:retry, :inconsistent}`.
  """
  @spec result([number() | nil]) :: {:ok, integer()} | {:retry, :too_few_onsets | :inconsistent}
  def result(offsets) do
    sorted = offsets |> Enum.reject(&is_nil/1) |> Enum.sort()

    cond do
      length(sorted) < @min_onsets -> {:retry, :too_few_onsets}
      spread(sorted) > @max_spread_ms -> {:retry, :inconsistent}
      true -> {:ok, sorted |> median() |> round_delay()}
    end
  end

  # Max − min after dropping the lowest and highest offset (one stray each end).
  defp spread(sorted) do
    middle = Enum.slice(sorted, 1..-2//1)
    List.last(middle) - hd(middle)
  end

  defp median(sorted) do
    n = length(sorted)
    mid = div(n, 2)

    if rem(n, 2) == 1,
      do: Enum.at(sorted, mid),
      else: (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
  end

  defp round_delay(ms), do: (round(ms / 10) * 10) |> max(0) |> min(@max_delay_ms)
end
