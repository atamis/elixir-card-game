defmodule GameServerTest do
  use ExUnit.Case
  doctest GameServer

  import GameServer
  require Util

  test "unique append" do
    assert [1] == unique_append([], 1)
    assert [1] == unique_append([1], 1)
  end

  test "joining" do
    ref = {self(), nil}
    {:next_state, state, %{players: new_players}, _} = handle_event({:call, ref}, :join, :waiting, %{players: []})
    assert :waiting == state
    assert new_players == [self()]

    # no double join
    {:next_state, state, %{players: new_players}, _} = handle_event({:call, ref}, :join, :waiting, %{players: new_players})

    assert state == :waiting
    assert new_players == [self()]
  end

  test "proxy" do
    {:ok, pid} = Proxy.start_link(self())
    send(pid, :message)
    assert_receive({:proxy, pid, :message})

    send(pid, {:compound, :message})
    assert_receive({:proxy, pid, {:compound, :message}})

    Proxy.send(pid, self(), :ok)

    assert_receive(:ok)

    Proxy.send(pid, pid, :ok)

    assert_receive({:proxy, pid, :ok})

    Proxy.exec(pid, fn -> send(self(), :test) end)

    assert_receive({:proxy, pid, :test})
  end

  test "premature starting" do
    {:ok, sup} = GameServer.Supervisor.start_link([])
    server = GameServer.Supervisor.get_game(sup)
    assert :ok = GameServer.join(server)

    assert {:error, _} = GameServer.begin(server)
  end

  test "starting the game" do
    {:ok, sup} = GameServer.Supervisor.start_link([])
    server = GameServer.Supervisor.get_game(sup)
    {:ok, proxy} = Proxy.start_link(self())

    assert :ok = GameServer.join(server)

    assert {:ok, :ok} = Proxy.exec(proxy, Util.thunk(GameServer.join(server)))

    assert :ok = GameServer.begin(server)

    me = self()

    assert_receive({:game_begin, ^me, index1})
    assert_receive({:proxy, proxy, {:game_begin, proxy, index2}})

    assert index1 != index2

  end
end

