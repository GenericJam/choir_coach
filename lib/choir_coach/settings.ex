defmodule ChoirCoach.Settings do
  @moduledoc """
  The singer's saved preferences, kept in `Mob.State` so they survive
  restarts.

  **Headphone delay** (`mic_delay_ms/1`), saved per output device: how much
  later the microphone's readings arrive than the moment the singer heard
  the music. Wired headphones on the moto g measured 60 ms; Bluetooth adds
  its own delay, which Android may or may not report, so it starts at a
  typical 200 ms until the singer sets it (by hand or by singing along). A
  device is keyed by `device_key/1`; a device with a saved delay is
  `known_device?/1`.

  **Mixes** (`mix/1`, `saved_mix/1`), per part: the mix last used and the
  singer's saved "My mix" (`ChoirCoach.Mix` maps), or nil.
  """

  @min 0
  @max 400
  @step 10

  # Before an output stream has opened and reported its device, the route
  # Android takes by default: headphones ahead of the speaker.
  @route_order [:bluetooth, :usb, :wired_headset, :wired_headphones]
  @headphone_kinds ["bluetooth", "bluetooth_sco", "usb", "wired_headset", "wired_headphones"]

  @doc """
  The output whose headphone delay applies, from the full device list
  (`ChoirCoach.Audio` `devices/1`, including the Bluetooth call route):
  the device the open stream `actual`ly plays on, else the `preferred` one,
  else the default route, else the speaker. nil when there are no outputs.
  """
  @spec active_output([map()], integer() | nil, integer() | nil) :: map() | nil
  def active_output(devices, actual, preferred) do
    outputs = Enum.filter(devices, &(&1.direction == :output))
    id = actual || preferred

    Enum.find(outputs, &(&1.id == id)) ||
      Enum.find_value(@route_order, fn kind -> Enum.find(outputs, &(&1.kind == kind)) end) ||
      Enum.find(outputs, &(&1.kind == :speaker))
  end

  @doc "A stable key for an output device: `\"kind:name\"`."
  @spec device_key(%{kind: atom(), name: String.t()}) :: String.t()
  def device_key(%{kind: kind, name: name}), do: "#{kind}:#{name}"

  @doc "The headphone delay saved for a device, or the default for its kind."
  @spec mic_delay_ms(String.t()) :: integer()
  def mic_delay_ms(device_key),
    do: Mob.State.get({:mic_delay_ms, device_key}) || default_delay(device_key)

  @doc "Save a device's headphone delay, snapped to 10 ms and kept within 0–400 ms."
  @spec put_mic_delay_ms(String.t(), number()) :: integer()
  def put_mic_delay_ms(device_key, ms) do
    ms = clamp_delay(ms)
    :ok = Mob.State.put({:mic_delay_ms, device_key}, ms)
    ms
  end

  @doc "Whether the device has a saved delay (so calibration isn't offered again)."
  @spec known_device?(String.t()) :: boolean()
  def known_device?(device_key), do: Mob.State.get({:mic_delay_ms, device_key}) != nil

  @doc """
  Whether setting the delay has been offered for this device: the practice
  screen offers it once, the first time new headphones are used.
  """
  @spec delay_offered?(String.t()) :: boolean()
  def delay_offered?(device_key), do: Mob.State.get({:delay_offered, device_key}, false)

  @spec put_delay_offered(String.t()) :: :ok
  def put_delay_offered(device_key), do: Mob.State.put({:delay_offered, device_key}, true)

  @doc "Snap to the 10 ms grid and clamp to 0–400 ms."
  @spec clamp_delay(number()) :: integer()
  def clamp_delay(ms), do: (round(ms / @step) * @step) |> max(@min) |> min(@max)

  @spec delay_range() :: {integer(), integer()}
  def delay_range, do: {@min, @max}

  @spec delay_step() :: integer()
  def delay_step, do: @step

  @doc """
  The output the singer picked on the Audio screen, as an id among
  `devices` (`ChoirCoach.Audio` `devices/1`), or nil for the system default.
  Kept so a remounted practice screen plays where the singer chose. Android
  numbers devices afresh on every boot, so the choice is saved with the
  device's `device_key/1`: that id while it is still the same device, else
  the device with that key under its new id (ids change across reboots).
  """
  @spec output_pref([map()]) :: integer() | nil
  def output_pref(devices), do: resolve_pref(Mob.State.get(:output_pref), devices, :output)

  @doc "Save the picked output: a device from `devices/1`, or nil for the default."
  @spec put_output_pref(map() | nil) :: :ok
  def put_output_pref(device), do: Mob.State.put(:output_pref, pref(device))

  @doc "The microphone the singer picked, resolved like `output_pref/1`."
  @spec input_pref([map()]) :: integer() | nil
  def input_pref(devices), do: resolve_pref(Mob.State.get(:input_pref), devices, :input)

  @spec put_input_pref(map() | nil) :: :ok
  def put_input_pref(device), do: Mob.State.put(:input_pref, pref(device))

  defp pref(nil), do: nil
  defp pref(device), do: %{id: device.id, key: device_key(device)}

  # Ids are per boot: the stored id while it is still that device, else the
  # same device (by key) under its new id.
  defp resolve_pref(%{id: id, key: key}, devices, direction) do
    same = Enum.filter(devices, &(&1.direction == direction and device_key(&1) == key))
    if Enum.any?(same, &(&1.id == id)), do: id, else: Enum.find_value(same, & &1.id)
  end

  defp resolve_pref(_none, _devices, _direction), do: nil

  @doc "The part's last-used mix, or nil."
  @spec mix(atom()) :: ChoirCoach.Mix.t() | nil
  def mix(part), do: Mob.State.get({:mix, part})

  @spec put_mix(atom(), ChoirCoach.Mix.t()) :: :ok
  def put_mix(part, mix), do: Mob.State.put({:mix, part}, mix)

  @doc "The part's saved \"My mix\", or nil."
  @spec saved_mix(atom()) :: ChoirCoach.Mix.t() | nil
  def saved_mix(part), do: Mob.State.get({:saved_mix, part})

  @doc "Save the mix as the part's \"My mix\"; returns it with that preset selected."
  @spec put_saved_mix(atom(), ChoirCoach.Mix.t()) :: ChoirCoach.Mix.t()
  def put_saved_mix(part, mix) do
    mix = %{mix | preset: :my_mix, recording: nil}
    :ok = Mob.State.put({:saved_mix, part}, mix)
    mix
  end

  # Headphones fall back to the single delay the previous version saved
  # (`:mic_delay_ms`), which the singer set for their headphones.
  defp default_delay(device_key) do
    kind = device_key |> String.split(":", parts: 2) |> hd()
    legacy = if kind in @headphone_kinds, do: Mob.State.get(:mic_delay_ms)

    cond do
      legacy -> legacy
      kind in ["bluetooth", "bluetooth_sco"] -> 200
      kind in ["wired_headphones", "wired_headset", "usb", "speaker"] -> 60
      true -> Application.get_env(:choir_coach, :mic_latency_ms, 60)
    end
  end
end
