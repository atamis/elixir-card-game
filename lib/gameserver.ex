
# :gen_event message bus
# players join event bus to receive broadcasts.
# broadcasts are: chat messages, new game states
# players interact with the GameServer with GenServer calls
# players identify themselves with a name

# Supervisor
#   Registry
#   Supervisor
#       :gen_event
#       GameServer

defmodule GameServer.Supervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  def children() do
    me = self()
    [
      EventBus,
      BusPrinter,
      {GameServer, [me]},
      {Task, fn -> after_init(me) end}
    ]
  end

  def get_bus(pid) do
    find_worker(pid, EventBus)
  end

  def get_game(pid) do
    find_worker(pid, GameServer)
  end

  defp find_worker(pid, tag) do
    Supervisor.which_children(pid)
    |> Enum.find_value(fn
      {^tag, pid, _, _} -> pid
      _ -> false
    end)
  end

  def after_init(sup) do
    bus = get_bus(sup)
    printer = find_worker(sup, BusPrinter)
    EventBus.subscribe_link(bus, printer)
  end

  def init(_) do
    children = children()

    Supervisor.init(children, strategy: :one_for_all)
  end
end

defmodule BusPrinter do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [nil])
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_info(message, state) do
    IO.inspect({self(), :message, message})
    {:noreply, state}
  end
end

defmodule GameServer do
  @min_players 2

  def child_spec(args) do
    %{id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      type: :worker,
      restart: :permanent,
      shutdown: 500,
    }
  end

  @behaviour :gen_statem
  def callback_mode(), do: [:handle_event_function, :state_enter]


  def start_link(opts) do
    :gen_statem.start_link(__MODULE__, opts, [])
  end

  def debug(pid) do
    :gen_statem.cast(pid, :debug)
  end

  def join(pid) do
    :gen_statem.call(pid, :join)
  end

  def begin(pid) do
    :gen_statem.call(pid, :begin)
  end

  # Callbacks

  def init([supervisor]) do
    send(self(), :after_init)
    {:ok, :waiting, %{supervisor: supervisor, bus: nil, players: []}}
  end

  def handle_event(:info, :after_init, :waiting, state) do
    bus = get_bus(state)
    {:next_state, :waiting,  %{state | bus: bus}}
  end

  # Waiting state

  def handle_event({:call, from}, :join, :waiting, %{players: players, bus: bus} = data) do
    {pid, _} = from

    EventBus.notify(bus, {:player_join, pid})

    {:keep_state,
     %{data | players: unique_append(players, pid)},
     [{:reply, from, :ok}]
    }
  end

  def handle_event(:cast, :debug, state, data) do
    IO.inspect({:cast, :debug, state, data})
    {:keep_state, data}
  end

  def handle_event({:call, from}, :begin, :waiting, %{players: players} = data) when length(players) < @min_players do
    {:keep_state, data, [{:reply, from, {:error, :not_enough_players}}]}
  end

  def handle_event({:call, from}, :begin, :waiting, %{players: players, bus: bus} = data) do
    pid_index = players
    |> Enum.with_index()
    |> Enum.into(%{})

    index_pid = pid_index
    |> Enum.map(fn {a, b} -> {b, a} end)
    |> Enum.into(%{})

    EventBus.notify(bus, {:game_begin, pid_index})

    newdata = Map.merge(data, %{pid_index: pid_index, index_pid: index_pid})

    {:next_state, :starting,
     newdata, # todo actually start game
     [{:reply, from, :ok}]}
  end

  def handle_event(:enter, _, :starting, %{bus: bus, players: players} = data) do
    gamestate = GameState.new_game(length(players))

    EventBus.notify(bus, {:gamestate, gamestate})

    {:new_state, {:playing, 0}, Map.put(data, :gamestate, gamestate), []}
  end

  # Playing state

  def handle_event(:enter, _, {:playing, n} = state, %{bus: bus, gamestate: gamestate} = data) do
    {gamestate, newstate} = case GameState.tick(gamestate) do
      {:ok, newstate, :ready} -> {newstate, {:playing, n}}
      {:ok, newstate, :requiresplay} -> {newstate, {:playing, n}}
      {:ok, newstate} -> {newstate, {:playing, n + 1}}
    end

    EventBus.notify(bus, {:gamestate, newstate})

    data = %{data | gamestate: gamestate}

    if newstate == state do
      {:keep_state, data, []}
    else
      {:new_state, newstate, data, []}
    end
  end

  # Any state


  def handle_event(:enter, oldstate, newstate, _) do
    IO.inspect({self(), :state_change, oldstate, newstate})
    {:keep_state_and_data, []}
  end

  def terminate(reason, state, data) do
    IO.inspect({:termination, self(), {reason, state, data}})
  end

  # Utility

  def unique_append([], item) do
    [item]
  end

  def unique_append([head | tail], item) do
    [head |
    if head == item do
      tail
    else
      unique_append(tail, item)
    end
    ]
  end

  defp get_bus(%{supervisor: supervisor}) do
    GameServer.Supervisor.get_bus(supervisor)
  end
end
