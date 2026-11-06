defmodule ChoirCoach.Audio.Lease do
  @moduledoc """
  Who gets the audio engine back, and when.

  The engine (`ChoirCoach.Audio`) has one holder at a time, and the engine
  enforces it. The lease handles the hand-back: the Audio screen *borrows*
  the engine while it is open, and practice screens that gave it up, or
  found it busy, *await* it. When the borrower's process goes down — popped,
  crashed or killed, so also when Mob remounts a crashed Audio screen — every
  waiter still alive gets `{:audio_engine_reset}` (and stops waiting): it
  acquires the engine again, and waits again if the Audio screen is back
  first.

  Started from `ChoirCoach.App.on_start/0` (and the test helper).
  """

  use GenServer

  @doc false
  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, :ok, name: Keyword.get(opts, :name, __MODULE__))

  @doc """
  `pid` has the engine on loan until its process ends. A new borrower
  replaces an earlier one (whose end then wakes nobody).
  """
  @spec borrow(pid(), GenServer.server()) :: :ok
  def borrow(pid, server \\ __MODULE__), do: GenServer.call(server, {:borrow, pid})

  @doc """
  `pid` wants the engine back: it gets `{:audio_engine_reset}` when the
  borrower's process ends. `:borrowed` if there is a live borrower now, else
  `:free` (nobody to wait for: the caller should try acquiring again).
  """
  @spec await(pid(), GenServer.server()) :: :borrowed | :free
  def await(pid, server \\ __MODULE__), do: GenServer.call(server, {:await, pid})

  @impl true
  def init(:ok), do: {:ok, %{borrower: nil, waiters: %{}}}

  @impl true
  def handle_call({:borrow, pid}, _from, state) do
    with {_old, ref} <- state.borrower, do: Process.demonitor(ref, [:flush])
    {:reply, :ok, %{state | borrower: {pid, Process.monitor(pid)}}}
  end

  def handle_call({:await, pid}, _from, state) do
    waiters = Map.put_new_lazy(state.waiters, pid, fn -> Process.monitor(pid) end)
    reply = if state.borrower, do: :borrowed, else: :free
    {:reply, reply, %{state | waiters: waiters}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{borrower: {_, ref}} = state) do
    for {waiter, waiter_ref} <- state.waiters do
      Process.demonitor(waiter_ref, [:flush])
      if Process.alive?(waiter), do: send(waiter, {:audio_engine_reset})
    end

    {:noreply, %{borrower: nil, waiters: %{}}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state),
    do: {:noreply, %{state | waiters: Map.delete(state.waiters, pid)}}
end
