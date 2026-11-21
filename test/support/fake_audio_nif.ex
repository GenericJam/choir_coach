defmodule ChoirCoach.Test.FakeAudioNif do
  @moduledoc """
  `ChoirCoach.Audio.Nif` for host tests (`config :choir_coach, :audio_nif`),
  so `ChoirCoach.Audio.Native` and its `Io` run on the host over
  `MobAudioIo.Fake`.

  It keeps the NIF's rules: one holder (`acquire/2`, `release/1`, holder
  checks by pid or by the calling process); `load/3` refuses with
  `{:error, :output_open}` while a `"choir_out"` stream is open and
  `{:error, :decoding}` while a decode runs, as the NIF does, so the order
  `Io` closes things in is checked; `listen(pid, :mic)` needs an open
  `"choir_mic"` stream. A load is ready and decoded once every source's
  `source_done/2` came; the first `load_failed/2` sends `:load_error`;
  `mic_failed/1` sends the listener `:mic_error`. Tracks are 44.1 kHz.

  `calls/0` lists the calls, oldest first. State is global: `async: false`
  tests, `reset/0` in `setup`.
  """

  use Agent

  @rate 44_100

  defp initial do
    %{
      calls: [],
      holder: nil,
      epoch: 0,
      io: nil,
      generation: 0,
      sources: 0,
      done: MapSet.new(),
      failed: false,
      loaded: false,
      playing: false,
      at: 0.0,
      source: :none,
      listen: 0,
      gains: []
    }
  end

  @doc "Back to nobody holding, nothing loaded, no calls."
  def reset do
    ensure_started()
    Agent.update(__MODULE__, fn _ -> initial() end)
  end

  @doc "The calls so far, oldest first, as `{name, args...}`."
  def calls, do: get(&Enum.reverse(&1.calls))

  @doc "The calls named `name`, oldest first."
  def calls(name), do: Enum.filter(calls(), &(elem(&1, 0) == name))

  @doc "The fake engine's state."
  def state, do: get(& &1)

  def acquire(pid, force) do
    alive? = fn s -> s.holder != nil and Process.alive?(s.holder) end

    update(&record(&1, {:acquire, pid, force}), fn s ->
      cond do
        s.holder == pid -> {{:ok, s.epoch, false}, s}
        alive?.(s) and not force -> {{:error, :busy}, s}
        true -> {{:ok, s.epoch + 1, true}, stop(%{s | holder: pid, epoch: s.epoch + 1})}
      end
    end)
  end

  def release(pid) do
    update(&record(&1, {:release, pid}), fn s ->
      if s.holder == pid, do: {{:ok, true}, %{stop(s) | holder: nil}}, else: {{:ok, false}, s}
    end)
  end

  def attach(pid), do: update(&record(&1, {:attach, pid}), &{:ok, %{&1 | io: pid}})

  def load(pid, sources, guide) do
    out? = open?("choir_out")
    decoding? = decoding?()

    update(&record(&1, {:load, pid, sources, guide}), fn s ->
      cond do
        s.holder != pid ->
          {{:error, :not_owner}, s}

        out? ->
          {{:error, :output_open}, s}

        decoding? ->
          {{:error, :decoding}, s}

        true ->
          s = %{stop(s) | generation: s.generation + 1, sources: length(sources)}
          {{:ok, s.generation}, %{s | done: MapSet.new(), failed: false, loaded: true, at: 0.0}}
      end
    end)
  end

  def source_done(generation, index) do
    update(&record(&1, {:source_done, generation, index}), fn s ->
      if generation == s.generation and not s.failed,
        do: {:ok, finish(%{s | done: MapSet.put(s.done, index)}, generation)},
        else: {:ok, s}
    end)
  end

  # Every source in: ready, then decoded.
  defp finish(s, generation) do
    if MapSet.size(s.done) == s.sources do
      info = %{duration_ms: 1000.0, sample_rate: @rate, complete: true}
      event(s, :ready, info, generation)
      event(s, :decoded, info, generation)
    end

    s
  end

  def load_failed(generation, reason) do
    update(&record(&1, {:load_failed, generation, reason}), fn s ->
      if generation == s.generation and not s.failed do
        event(s, :load_error, reason, generation)
        {:ok, %{s | failed: true}}
      else
        {:ok, s}
      end
    end)
  end

  def play(pid, from_ms) do
    update(&record(&1, {:play, pid, from_ms}), fn s ->
      cond do
        s.holder != pid -> {{:error, :not_owner}, s}
        not s.loaded -> {{:error, :not_loaded}, s}
        true -> {{:ok, @rate}, %{s | playing: true, at: from_ms}}
      end
    end)
  end

  def pause do
    me = self()

    update(&record(&1, {:pause}), fn s ->
      if s.holder == me, do: {:ok, %{s | playing: false}}, else: {{:error, :not_owner}, s}
    end)
  end

  def halt,
    do: update(&record(&1, {:halt}), fn s -> {{s.playing, s.at}, %{s | playing: false}} end)

  def playing, do: get(& &1.playing)

  def position do
    me = self()

    get(fn s ->
      cond do
        s.holder != me -> {:error, :not_owner}
        not s.loaded -> {:empty, 0.0}
        s.playing -> {:playing, s.at}
        true -> {:paused, s.at}
      end
    end)
  end

  def set_mix(gains) do
    me = self()

    update(&record(&1, {:set_mix, gains}), fn s ->
      if s.holder == me, do: {:ok, %{s | gains: gains}}, else: {{:error, :not_owner}, s}
    end)
  end

  def listen(pid, source) do
    mic? = open?("choir_mic")

    update(&record(&1, {:listen, pid, source}), fn s ->
      cond do
        s.holder != pid -> {{:error, :not_owner}, s}
        source == :mic and not mic? -> {{:error, :microphone_unavailable}, s}
        source == :playback and not s.loaded -> {{:error, :not_loaded}, s}
        true -> {{:ok, s.listen + 1}, %{s | source: source, listen: s.listen + 1}}
      end
    end)
  end

  def stop_listening(pid) do
    update(&record(&1, {:stop_listening, pid}), fn s ->
      if s.holder == pid,
        do: {:ok, %{s | source: :none, listen: s.listen + 1}},
        else: {{:error, :not_owner}, s}
    end)
  end

  def listening(pid) do
    get(fn s -> if s.holder == pid, do: {:ok, s.source, s.listen}, else: {:error, :not_owner} end)
  end

  def mic_failed(reason) do
    update(&record(&1, {:mic_failed, reason}), fn s ->
      if s.holder && s.source == :mic,
        do: send(s.holder, {:choir_audio, :mic_error, reason, s.listen})

      {:ok, s}
    end)
  end

  def readings do
    me = self()
    get(fn s -> if s.holder == me, do: [], else: {:error, :not_owner} end)
  end

  def info,
    do: get(&%{track_rate: @rate, sources: &1.sources, listening: &1.source, playing: &1.playing})

  # ── Helpers ───────────────────────────────────────────────────────────────

  # A holder change, release or load: music and listening stop, the load's
  # events end.
  defp stop(s), do: %{s | playing: false, source: :none, listen: s.listen + 1}

  defp event(%{holder: nil}, _kind, _payload, _tag), do: :ok
  defp event(s, kind, payload, tag), do: send(s.holder, {:choir_audio, kind, payload, tag})

  defp open?(processor),
    do: Enum.any?(MobAudioIo.Fake.status().streams, &(&1.processor == processor))

  defp decoding?, do: Agent.get(MobAudioIo.Fake, &(map_size(&1.decodes) > 0))

  defp record(s, call), do: %{s | calls: [call | s.calls]}

  defp get(fun) do
    ensure_started()
    Agent.get(__MODULE__, fun)
  end

  defp update(record, fun) do
    ensure_started()

    Agent.get_and_update(__MODULE__, fn s ->
      s |> record.() |> fun.()
    end)
  end

  defp ensure_started do
    case Agent.start(&initial/0, name: __MODULE__) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end
end

defmodule ChoirCoach.Test.FakeIos do
  @moduledoc "`ChoirCoach.Ios` for host tests: the speaker override and the route watcher, recorded."

  @doc "The last `set_speaker/1`, or nil."
  def speaker, do: :persistent_term.get({__MODULE__, :speaker}, nil)

  @doc "Forget the override."
  def reset, do: :persistent_term.put({__MODULE__, :speaker}, nil)

  def screen_size, do: {390.0, 844.0}

  def set_speaker(on) do
    :persistent_term.put({__MODULE__, :speaker}, on)
    :ok
  end

  def watch_route(_pid), do: :ok
end
