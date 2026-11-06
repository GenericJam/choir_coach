defmodule ChoirCoach.Audio.LeaseTest do
  use ExUnit.Case, async: true

  alias ChoirCoach.Audio.Lease

  setup do
    name = :"lease_#{System.unique_integer([:positive])}"
    start_supervised!({Lease, name: name})
    %{lease: name}
  end

  # A stand-in Audio screen: ends with the reason it's sent (or is killed).
  defp borrower, do: spawn(fn -> receive do: ({:end, reason} -> exit(reason)) end)

  defp finish(pid, :kill), do: Process.exit(pid, :kill)
  defp finish(pid, reason), do: send(pid, {:end, reason})

  for {how, reason} <- [{"closes", :normal}, {"crashes", :boom}, {"is killed", :kill}] do
    test "when the borrower #{how}, every live waiter is told once", %{lease: lease} do
      audio = borrower()
      :ok = Lease.borrow(audio, lease)
      assert Lease.await(self(), lease) == :borrowed

      finish(audio, unquote(reason))
      assert_receive {:audio_engine_reset}

      # Told, it no longer waits: the next borrower's end isn't for it.
      next = borrower()
      :ok = Lease.borrow(next, lease)
      Process.exit(next, :kill)
      refute_receive {:audio_engine_reset}, 50
    end
  end

  test "a waiter that died is dropped; the others are still told", %{lease: lease} do
    audio = borrower()
    :ok = Lease.borrow(audio, lease)
    gone = spawn(fn -> Lease.await(self(), lease) end)
    ref = Process.monitor(gone)
    assert_receive {:DOWN, ^ref, :process, _, _}
    :borrowed = Lease.await(self(), lease)

    Process.exit(audio, :kill)
    assert_receive {:audio_engine_reset}
    assert Process.alive?(GenServer.whereis(lease))
  end

  test "a remounted borrower replaces the first: only its end hands back", %{lease: lease} do
    first = borrower()
    :ok = Lease.borrow(first, lease)
    :borrowed = Lease.await(self(), lease)

    second = borrower()
    :ok = Lease.borrow(second, lease)
    Process.exit(first, :kill)
    refute_receive {:audio_engine_reset}, 50

    Process.exit(second, :kill)
    assert_receive {:audio_engine_reset}
  end

  test "with nobody borrowing, a waiter hears it's free", %{lease: lease} do
    assert Lease.await(self(), lease) == :free
    refute_receive {:audio_engine_reset}, 20
  end
end
