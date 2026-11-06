defmodule ChoirCoach.SettingsTest do
  # Mob.State is one shared store; these tests write to it.
  use ExUnit.Case, async: false

  alias ChoirCoach.{Mix, Settings}
  alias Mob.ScreenCase.StateOwner

  setup do
    {:ok, ref} = StateOwner.checkout()
    on_exit(fn -> StateOwner.checkin(ref) end)
    for {key, _} <- Mob.State.match({:mic_delay_ms, :_}), do: Mob.State.delete(key)
    Mob.State.delete(:mic_delay_ms)
    for part <- [:bass, :melody], do: Mob.State.delete({:saved_mix, part})
    :ok
  end

  @buds Settings.device_key(%{kind: :bluetooth, name: "Pixel Buds"})
  @wired Settings.device_key(%{kind: :wired_headphones, name: "USB-C to 3.5mm"})

  test "the delay starts from the device kind's default" do
    assert Settings.mic_delay_ms(@buds) == 200
    assert Settings.mic_delay_ms(@wired) == 60
    assert Settings.mic_delay_ms(Settings.device_key(%{kind: :speaker, name: "Phone"})) == 60
    assert Settings.mic_delay_ms(Settings.device_key(%{kind: :other, name: "Dock"})) == 60
    refute Settings.known_device?(@buds)
  end

  test "a saved delay is per device, snapped to 10 ms and kept in 0–400 ms" do
    assert Settings.put_mic_delay_ms(@buds, 233.7) == 230
    assert Settings.mic_delay_ms(@buds) == 230
    assert Settings.known_device?(@buds)
    assert Settings.mic_delay_ms(@wired) == 60
    refute Settings.known_device?(@wired)

    assert Settings.put_mic_delay_ms(@wired, 900) == 400
    assert Settings.put_mic_delay_ms(@wired, -20) == 0
    assert Settings.mic_delay_ms(@wired) == 0
  end

  test "headphones start from the single delay the previous version saved" do
    :ok = Mob.State.put(:mic_delay_ms, 150)

    assert Settings.mic_delay_ms(@buds) == 150
    assert Settings.mic_delay_ms(@wired) == 150

    assert Settings.mic_delay_ms(Settings.device_key(%{kind: :bluetooth_sco, name: "Buds"})) ==
             150

    assert Settings.mic_delay_ms(Settings.device_key(%{kind: :speaker, name: "Phone"})) == 60

    Settings.put_mic_delay_ms(@buds, 220)
    assert Settings.mic_delay_ms(@buds) == 220
  end

  describe "active_output/3: the output whose delay applies" do
    @speaker %{id: 2, direction: :output, kind: :speaker, name: "Phone"}
    @a2dp %{id: 31, direction: :output, kind: :bluetooth, name: "Buds"}
    @sco %{id: 40, direction: :output, kind: :bluetooth_sco, name: "Buds"}
    @sco_mic %{id: 32, direction: :input, kind: :bluetooth_sco, name: "Buds"}
    @devices [@speaker, @a2dp, @sco, @sco_mic]

    test "the route actually playing wins over the choice, even the call route" do
      assert Settings.active_output(@devices, 40, 31) == @sco
      assert Settings.active_output(@devices, 2, 31) == @speaker
    end

    test "before a stream opens: the choice, else headphones ahead of the speaker" do
      assert Settings.active_output(@devices, nil, 2) == @speaker
      assert Settings.active_output(@devices, nil, nil) == @a2dp
      assert Settings.active_output([@speaker, @sco_mic], nil, 32) == @speaker
      assert Settings.active_output([@sco_mic], nil, nil) == nil
    end

    test "a picked device is found again under a new id, and never mistaken for another" do
      :ok = Settings.put_output_pref(@a2dp)
      assert Settings.output_pref(@devices) == 31

      # After a reboot the same headphones come back as 57; id 31 is now the speaker.
      rebooted = [%{@speaker | id: 31}, %{@a2dp | id: 57}]
      assert Settings.output_pref(rebooted) == 57
      assert Settings.output_pref([%{@speaker | id: 31}]) == nil
    end
  end

  test "a saved mix comes back as My mix" do
    tracks = %{rehearsal: %{file: "s/bass.mp3", bar1_ms: 0.0}}
    assert Settings.saved_mix(:bass) == nil

    custom = Mix.new(:bass, tracks) |> Mix.set_row(:band, :level, 30)
    saved = Settings.put_saved_mix(:bass, custom)

    assert Mix.caption(saved) == "My mix"
    assert Settings.saved_mix(:bass) == saved
    assert Settings.saved_mix(:melody) == nil
  end
end
