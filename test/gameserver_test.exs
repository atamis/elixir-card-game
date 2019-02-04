defmodule GameServerTest do
  use ExUnit.Case
  doctest GameServer

  import GameServer
  require Util

  setup context do

    opts = Util.cond_put context[:bus], %{} do
      {:ok, bus} = EventBus.start_link()
      %{bus: bus}
    end

    opts = Util.cond_put(context[:server], opts) do
      {:ok, sup} = GameServer.Supervisor.start_link([])
      server = GameServer.Supervisor.get_game(sup)
      bus = GameServer.Supervisor.get_bus(sup)
      %{server: server, bus: bus, sup: sup}
    end

    opts = Util.cond_put opts[:bus] && context[:proxy], opts do
      {:ok, proxy} = Proxy.start_link(self())
      EventBus.subscribe(opts[:bus], proxy)
      %{proxy: proxy}
    end

    opts = Util.cond_put(true, opts, %{asdf: :asdf})

    {:ok, opts}
  end

  setup context do
    #IO.inspect(context)
    {:ok, context}
  end

  test "unique append" do
    assert [1] == unique_append([], 1)
    assert [1] == unique_append([1], 1)
  end

  @tag :bus
  test "joining", %{bus: bus} do
    ref = {self(), nil}

    {:keep_state, %{players: new_players}, _} = handle_event({:call, ref}, :join, :waiting, %{bus: bus, players: []})
    assert new_players == [self()]

    # no double join
    {:keep_state, %{players: new_players}, _} = handle_event({:call, ref}, :join, :waiting, %{bus: bus, players: new_players})

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

  test "nil proxy" do
    {:ok, pid} = Proxy.start_link(nil)
    send(pid, :test)
    refute_receive({:proxy, _, _})
  end

  @tag :server
  test "premature starting", %{server: server} do
    # {:ok, sup} = GameServer.Supervisor.start_link([])
    #server = GameServer.Supervisor.get_game(sup)
    assert :ok = GameServer.join(server)

    assert {:error, _} = GameServer.begin(server)
  end

  @tag :server
  @tag :proxy
  test "starting the game", %{bus: bus, server: server, proxy: proxy} do
    EventBus.subscribe(bus)
    assert :ok = GameServer.join(server)

    me = self()

    assert_receive {:player_join, ^me}
    assert_receive {:proxy, ^proxy, {:player_join, ^me}}

    assert {:ok, :ok} = Proxy.exec(proxy, Util.thunk(GameServer.join(server)))

    assert_receive {:player_join, ^proxy}
    assert_receive {:proxy, ^proxy, {:player_join, ^proxy}}

    assert :ok = GameServer.begin(server)

    assert_receive({:game_begin, mapping})
    assert_receive({:proxy, ^proxy, {:game_begin, ^mapping}})

    assert mapping[me] != mapping[proxy]

    assert_receive({:gamestate, state})
    assert_receive({:proxy, ^proxy, {:gamestate, ^state}})

    GameServer.hand_play(server, 0)

    assert_receive({:gamestate, state})
    assert_receive({:proxy, ^proxy, {:gamestate, ^state}})
  end
end

