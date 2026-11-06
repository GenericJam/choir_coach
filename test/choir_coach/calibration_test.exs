defmodule ChoirCoach.CalibrationTest do
  use ExUnit.Case, async: true

  alias ChoirCoach.Calibration

  @clicks Calibration.click_times_ms()

  # Mic readings every 10 ms: room tone at −60 dB, and a 150 ms "ta" at
  # −20 dB starting `delay` ms after each click (nil = not sung). `voiced?`
  # gives the "ta" a confident pitch from its second reading on.
  defp readings(delays, opts \\ []) do
    voiced? = Keyword.get(opts, :voiced?, false)
    sung = for {c, d} <- Enum.zip(@clicks, delays), d != nil, do: c + d

    for t <- 0..7000//10 do
      case Enum.find(sung, &(t >= &1 and t < &1 + 150)) do
        nil -> {t * 1.0, nil, 0.0, -60.0}
        start when voiced? and t >= start + 10 -> {t * 1.0, 45.0, 0.9, -20.0}
        _ -> {t * 1.0, nil, 0.1, -20.0}
      end
    end
  end

  test "8 clicks at 90 bpm after 1 s of silence" do
    assert [1000.0 | _] = @clicks
    gaps = @clicks |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [a, b] -> b - a end)
    assert [_, _, _, _, _, _, _] = gaps
    assert Enum.all?(gaps, &(abs(&1 - 666.667) < 0.01))
  end

  test "a clean take measures the delay" do
    offsets = Calibration.onsets(readings(List.duplicate(180, 8)), @clicks)
    assert Enum.all?(offsets, &(&1 in 180..190))

    assert {:ok, 180} =
             Calibration.result(Calibration.onsets(readings(List.duplicate(180, 8)), @clicks))
  end

  test "a voiced onset counts even without a level jump" do
    quiet =
      for {t, midi, conf, _db} <- readings(List.duplicate(200, 8), voiced?: true),
          do: {t, midi, conf, -60.0}

    assert {:ok, 210} = Calibration.result(Calibration.onsets(quiet, @clicks))
  end

  test "nothing sung within 600 ms of a click is a missed click" do
    offsets = Calibration.onsets(readings([150, nil, 150, 700, 150, 150, 150, 150]), @clicks)
    assert Enum.at(offsets, 1) == nil
    assert Enum.at(offsets, 3) == nil
    assert Enum.count(offsets, &is_nil/1) == 2
  end

  test "fewer than 5 onsets asks for another try" do
    delays = [150, nil, 150, nil, 150, nil, 150, nil]

    assert {:retry, :too_few_onsets} =
             Calibration.result(Calibration.onsets(readings(delays), @clicks))
  end

  test "nothing heard at all (no readings, or one) asks for another try" do
    assert {:retry, :too_few_onsets} = Calibration.result(Calibration.onsets([], @clicks))
    assert {:retry, :too_few_onsets} = Calibration.result([150])
  end

  test "one stray onset at each end is tolerated" do
    assert {:ok, 150} = Calibration.result([20, 140, 150, 150, 160, 150, 145, 500])
  end

  test "a spread over 40 ms in the middle asks for another try" do
    assert {:retry, :inconsistent} = Calibration.result([100, 110, 120, 130, 150, 160, 170, 180])
    assert {:ok, 140} = Calibration.result([100, 120, 130, 140, 140, 150, 160, 200])
  end

  test "the median is rounded to 10 ms and kept within 0–400 ms" do
    assert {:ok, 130} = Calibration.result([123, 124, 126, 127, 128, nil, nil, nil])
    assert {:ok, 120} = Calibration.result([114, 118, 120, 122, 124, 116])
    assert {:ok, 0} = Calibration.result([-10, -8, -6, -4, -2])
    assert {:ok, 400} = Calibration.result([440, 445, 450, 455, 460])
  end
end
