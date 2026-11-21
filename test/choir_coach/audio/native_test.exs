defmodule ChoirCoach.Audio.NativeTest do
  # The device engine on the host: mob_audio_io's fake streams and decodes,
  # and a double of the choir_audio NIF that keeps its rules.
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias ChoirCoach.Audio.Native
  alias ChoirCoach.Audio.Native.Io
  alias ChoirCoach.Test.{FakeAudioNif, FakeIos}
  alias MobAudioIo.Fake

  @spec_one %{
    bar1_ms: 0.0,
    sources: [%{file: "song/one.wav", channels: [:left, :right]}],
    guide_lane: 0
  }

  setup do
    Fake.reset()
    FakeAudioNif.reset()
    FakeIos.reset()
    Enum.each(~w(choir_out choir_mic choir_src0 choir_src1), &Fake.register_processor/1)
    Application.put_env(:choir_coach, :audio_platform, :android)

    root = Path.join(System.tmp_dir!(), "choir_native_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "priv/audio/song"))
    write_wav(Path.join(root, "priv/audio/song/one.wav"), 2)
    write_wav(Path.join(root, "priv/audio/song/two.wav"), 1)
    System.put_env("MOB_BEAMS_DIR", root)

    start_supervised!(Io)

    on_exit(fn ->
      System.delete_env("MOB_BEAMS_DIR")
      Application.delete_env(:choir_coach, :audio_platform)
      File.rm_rf!(root)
    end)

    :ok
  end

  # 0.1 s of 44.1 kHz 16-bit PCM.
  defp write_wav(path, channels) do
    frames = 4410
    data = :binary.copy(<<0::little-16>>, frames * channels)
    rate = 44_100

    header =
      <<"RIFF", 36 + byte_size(data)::little-32, "WAVE", "fmt ", 16::little-32, 1::little-16,
        channels::little-16, rate::little-32, rate * channels * 2::little-32,
        channels * 2::little-16, 16::little-16, "data", byte_size(data)::little-32>>

    File.write!(path, header <> data)
  end

  defp held do
    {:ok, state} = Native.acquire(Native.new_bare(), false)
    state
  end

  defp loaded(spec \\ @spec_one) do
    state = Native.load(held(), spec)
    load = state.load
    assert_receive {:choir_audio, :decoded, _info, ^load}, 2_000
    state
  end

  defp streams(processor), do: Enum.filter(Fake.status().streams, &(&1.processor == processor))
  defp ids(processor), do: Enum.map(streams(processor), & &1.id)

  defp eventually(fun, tries \\ 100) do
    cond do
      fun.() -> true
      tries == 0 -> flunk("never happened")
      true -> Process.sleep(10) && eventually(fun, tries - 1)
    end
  end

  describe "loading" do
    test "each file decodes into its source's processor; the holder hears ready, then decoded" do
      spec = %{
        bar1_ms: 0.0,
        sources: [
          %{file: "song/one.wav", channels: [:left, :right]},
          %{file: "song/two.wav", channels: [:left]}
        ],
        guide_lane: nil
      }

      state = Native.load(held(), spec)
      load = state.load
      assert_receive {:choir_audio, :ready, _, ^load}, 2_000
      assert_receive {:choir_audio, :decoded, %{complete: true}, ^load}

      assert [{:load, _, [[:left, :right], [:left]], nil}] = FakeAudioNif.calls(:load)

      assert FakeAudioNif.calls(:source_done) |> Enum.map(&elem(&1, 2)) |> Enum.sort() == [0, 1]
      # As recorded: lanes 0, 1 to their ears, the mono file to both.
      assert FakeAudioNif.state().gains == [{1.0, 0.0}, {0.0, 1.0}, {1.0, 1.0}]
    end

    test "a missing file ends the load with :not_found, tagged with it" do
      spec = %{@spec_one | sources: [%{file: "song/missing.wav", channels: [:left]}]}
      state = Native.load(held(), spec)
      load = state.load
      assert_receive {:choir_audio, :load_error, :not_found, ^load}, 2_000
      refute_received {:choir_audio, :ready, _, _}
    end

    test "a load closes the output and the microphone, and waits for the last load's decodes" do
      state = loaded()
      {:ok, state} = Native.play(state, 0.0)
      {:ok, state} = Native.listen(state, :mic)
      assert [_] = streams("choir_out")
      assert [_] = streams("choir_mic")

      # The double refuses a load under an open stream or a running decode.
      state = Native.load(state, @spec_one)
      load = state.load
      assert is_integer(load)
      assert streams("choir_out") == [] and streams("choir_mic") == []
      assert state.source == nil

      again = Native.load(state, @spec_one)
      assert is_integer(again.load) and again.load != load
      assert_receive {:choir_audio, :decoded, _, latest}, 2_000
      assert latest == again.load
    end
  end

  describe "playing" do
    test "play opens one output stream at the tracks' rate; once paused a while it closes; play reopens" do
      state = loaded()
      {:ok, state} = Native.play(state, 500.0)
      assert [out] = streams("choir_out")
      assert {out.rate, out.channels, out.session} == {44_100, 2, :play_and_record}
      assert {:playing, 500.0} = Native.position(state)

      {:ok, state} = Native.play(state, 900.0)
      assert [out.id] == ids("choir_out")

      state = Native.pause(state)
      assert {:paused, _} = Native.position(state)
      eventually(fn -> streams("choir_out") == [] end)

      {:ok, _state} = Native.play(state, 0.0)
      assert [_] = streams("choir_out")
    end

    test "a play right after a pause keeps the stream" do
      state = loaded()
      {:ok, state} = Native.play(state, 0.0)
      [out] = ids("choir_out")
      state = Native.pause(state)
      {:ok, _} = Native.play(state, 0.0)
      Process.sleep(100)
      assert [out] == ids("choir_out")
    end

    test "an output that can't open: :output_unavailable, and nothing plays" do
      state = loaded()
      Fake.fail_next_open({:unavailable, "test"})
      assert {:error, :output_unavailable, _} = Native.play(state, 0.0)
      refute FakeAudioNif.state().playing
    end

    for kind <- [:device_lost, :interrupted] do
      test "#{kind} on the output pauses where it was heard and closes it" do
        state = loaded()
        {:ok, state} = Native.play(state, 1200.0)
        [out] = streams("choir_out")
        Fake.inject(out.id, unquote(kind), %{})
        eventually(fn -> streams("choir_out") == [] end)
        assert {:paused, 1200.0} = Native.position(state)
        assert Native.output_device(state) == nil
      end
    end

    test "a media-services reset pauses too; a new route plays on" do
      state = loaded()
      {:ok, state} = Native.play(state, 0.0)
      [out] = streams("choir_out")
      Fake.inject(out.id, :route_changed, %{reason: :new_route})
      Process.sleep(50)
      assert {:playing, _} = Native.position(state)
      Fake.inject(out.id, :route_changed, %{reason: :media_reset})
      eventually(fn -> streams("choir_out") == [] end)
      assert {:paused, _} = Native.position(state)
    end

    test "Android: a new output reopens a playing stream there and plays on where it was heard" do
      state = loaded()
      {:ok, state} = Native.play(state, 700.0)
      [old] = streams("choir_out")
      _state = Native.set_output(state, 31)
      assert [new] = streams("choir_out")
      assert new.id != old.id
      assert stream_opts(new.id).device == "31"
      assert {:play, _, 700.0} = List.last(FakeAudioNif.calls(:play))
      assert FakeAudioNif.state().playing
    end
  end

  describe "listening" do
    test "the microphone opens on listen, with the default preset, and closes on stop" do
      state = held()
      {:ok, state} = Native.listen(state, :mic)
      assert state.source == :mic
      assert [mic] = streams("choir_mic")
      assert {mic.direction, mic.preset, mic.input_channels} == {:input, :default, 1}
      state = Native.stop_listening(state)
      assert state.source == nil
      assert streams("choir_mic") == []
    end

    test "without the microphone permission: :microphone_unavailable" do
      Fake.deny_permission()
      assert {:error, :microphone_unavailable, state} = Native.listen(held(), :mic)
      assert state.source == nil
      assert streams("choir_mic") == []
    end

    test "a lost microphone is :disconnected, an interrupted one :input_error, tagged with the listening" do
      {:ok, state} = Native.listen(held(), :mic)
      listen = state.listen
      [mic] = streams("choir_mic")
      Fake.inject(mic.id, :device_lost, %{})
      assert_receive {:choir_audio, :mic_error, :disconnected, ^listen}, 1_000
      eventually(fn -> streams("choir_mic") == [] end)

      {:ok, state} = Native.listen(state, :mic)
      listen = state.listen
      [mic] = streams("choir_mic")
      Fake.inject(mic.id, :interrupted, %{})
      assert_receive {:choir_audio, :mic_error, :input_error, ^listen}, 1_000
    end

    test "a new input restarts a listening microphone on it" do
      {:ok, state} = Native.listen(held(), :mic)
      [old] = streams("choir_mic")
      {:ok, state} = Native.set_input(state, 9)
      assert [new] = streams("choir_mic")
      assert new.id != old.id and stream_opts(new.id).device == "9"
      assert state.listen != nil
    end

    test "test mode listens to the playback without the microphone" do
      {:ok, state} = Native.listen(loaded(), :playback)
      assert state.source == :playback
      assert streams("choir_mic") == []
    end
  end

  describe "holding" do
    test "taking the engine by force closes the holder's streams; its calls then say :not_owner" do
      state = loaded()
      {:ok, state} = Native.play(state, 0.0)
      {:ok, state} = Native.listen(state, :mic)

      test = self()

      spawn_link(fn ->
        {:ok, _} = Native.acquire(Native.new_bare(), true)
        send(test, :taken)
        Process.sleep(:infinity)
      end)

      assert_receive :taken
      assert Fake.status().streams == []
      hold = state.hold
      assert {:loading, _} = Native.position(state)
      assert_received {:choir_audio, :not_owner, nil, ^hold}
      assert {:error, :not_owner, _} = Native.play(state, 0.0)
      assert streams("choir_out") == []
    end

    test "release closes everything" do
      state = loaded()
      {:ok, state} = Native.play(state, 0.0)
      Native.release(state)
      assert Fake.status().streams == []
    end
  end

  describe "devices" do
    test "Android: the plugin's kinds as the engine names them" do
      Fake.set_devices(:output, [
        %{id: 2, name: "Pixel 8", kind: :builtin_speaker},
        %{id: 3, name: "Pixel 8", kind: :builtin_earpiece},
        %{id: 31, name: "WH-1000XM4", kind: :bluetooth_a2dp},
        %{id: 33, name: "WH-1000XM4", kind: :bluetooth},
        %{id: 40, name: "Buds LE", kind: :bluetooth},
        %{id: 50, name: "TV", kind: :hdmi}
      ])

      Fake.set_devices(:input, [
        %{id: 9, name: "Pixel 8", kind: :builtin_mic},
        %{id: 32, name: "WH-1000XM4", kind: :bluetooth}
      ])

      assert Enum.map(Native.devices(Native.new_bare()), &{&1.id, &1.direction, &1.kind}) == [
               {2, :output, :speaker},
               {3, :output, :earpiece},
               {31, :output, :bluetooth},
               {33, :output, :bluetooth_sco},
               {40, :output, :bluetooth},
               {50, :output, :other},
               {9, :input, :builtin_mic},
               {32, :input, :bluetooth_sco}
             ]
    end

    test "iOS: the route's outputs, the speaker to choose, the inputs, by port" do
      Application.put_env(:choir_coach, :audio_platform, :ios)

      Fake.set_devices(:output, [%{id: "wired-uid", name: "Headphones", kind: :wired_headphones}])

      Fake.set_devices(:input, [
        %{id: "mic-uid", name: "iPhone Microphone", kind: :builtin_mic},
        %{id: "headset-uid", name: "Headset Microphone", kind: :wired_headset}
      ])

      assert Native.devices(Native.new_bare()) == [
               %{
                 id: "out:wired-uid",
                 direction: :output,
                 kind: :wired_headset,
                 name: "Headphones"
               },
               %{id: "speaker", direction: :output, kind: :speaker, name: "Speaker"},
               %{
                 id: "in:mic-uid",
                 direction: :input,
                 kind: :builtin_mic,
                 name: "iPhone Microphone"
               },
               %{
                 id: "in:headset-uid",
                 direction: :input,
                 kind: :wired_headset,
                 name: "Headset Microphone"
               }
             ]
    end
  end

  describe "iOS" do
    setup do
      Application.put_env(:choir_coach, :audio_platform, :ios)
      stop_supervised!(Io)
      start_supervised!(Io)
      :ok
    end

    test "the speaker is an override, set again at every play; the output stream has a 10 ms buffer" do
      state = loaded()
      state = Native.set_output(state, "speaker")
      assert FakeIos.speaker() == true
      FakeIos.reset()
      {:ok, state} = Native.play(state, 0.0)
      assert FakeIos.speaker() == true
      assert [%{buffer: 441}] = streams("choir_out")
      assert stream_opts(hd(streams("choir_out")).id).device == ""

      Fake.set_devices(:output, [%{id: "spk", name: "Speaker", kind: :builtin_speaker}])
      assert Native.output_device(state) == "speaker"
      Native.set_output(state, nil)
      assert FakeIos.speaker() == false
    end

    test "the input is chosen by its port" do
      {:ok, _} = Native.set_input(held(), "in:headset-uid")
      {:ok, _} = Native.listen(held(), :mic)
      assert stream_opts(hd(streams("choir_mic")).id).device == "headset-uid"
    end

    test "a route losing its device pauses, and ends a listening whose microphone went with it" do
      state = loaded()
      {:ok, state} = Native.play(state, 300.0)
      {:ok, state} = Native.listen(state, :mic)
      listen = state.listen
      send(Io, {:choir_ios, :route_lost, true})
      assert_receive {:choir_audio, :mic_error, :disconnected, ^listen}, 1_000
      assert {:paused, 300.0} = Native.position(state)
      eventually(fn -> streams("choir_mic") == [] and streams("choir_out") == [] end)
    end
  end

  # The normalized options a fake stream was opened with.
  defp stream_opts(id), do: Agent.get(Fake, &get_in(&1, [:streams, id, :opts]))
end
