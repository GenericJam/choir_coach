defmodule ChoirCoach.Settings do
  @moduledoc """
  The singer's saved preferences, kept in `Mob.State` so they survive
  restarts.

  **Headphone delay** (`mic_delay_ms/0`): how much later the microphone's
  readings arrive than the moment the singer heard the music. It depends on
  the headphones: wired headphones on the moto g measured 60 ms (the
  `:mic_latency_ms` config default); Bluetooth adds its own delay, which
  Android may or may not report, so the singer tunes it.
  """

  @key :mic_delay_ms
  @min 0
  @max 400
  @step 10

  @presets [wired: 60, bluetooth: 200]

  @doc "The saved headphone delay in ms, or the configured default."
  @spec mic_delay_ms() :: integer()
  def mic_delay_ms, do: Mob.State.get(@key, default_mic_delay_ms())

  @doc "Save a headphone delay, snapped to 10 ms and kept within 0–400 ms."
  @spec put_mic_delay_ms(number()) :: integer()
  def put_mic_delay_ms(ms) do
    ms = clamp_delay(ms)
    :ok = Mob.State.put(@key, ms)
    ms
  end

  @doc "Snap to the 10 ms grid and clamp to 0–400 ms."
  @spec clamp_delay(number()) :: integer()
  def clamp_delay(ms), do: (round(ms / @step) * @step) |> max(@min) |> min(@max)

  def delay_range, do: {@min, @max}
  def delay_step, do: @step

  @doc "Starting points: wired is measured; Bluetooth is a typical value to adjust from."
  def presets, do: @presets

  defp default_mic_delay_ms, do: Application.get_env(:choir_coach, :mic_latency_ms, 60)
end
