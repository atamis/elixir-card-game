
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
      %{id: :gen_event, start: {:gen_event, :start_link, []}},
      {GameServer, [me]},
      {Task, fn -> after_init(me) end}
    ]
  end

  def get_bus(pid) do
    find_worker(pid, :gen_event)
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
    :gen_event.add_handler(bus, BusPrinter, [])
  end

  def init(_) do
    children = children()

    Supervisor.init(children, strategy: :one_for_all)
  end
end

defmodule BusPrinter do
  @behaviour :gen_event

  def init(_) do
    {:ok, nil}
  end

  def handle_call(request, state) do
    IO.inspect({self(), :call, request})
    {:ok, :ok, state}
  end

  def handle_event(event, state) do
    IO.inspect({self(), :event, event})
    {:ok, state}
  end
end

defmodule BusProxy do
  @behavior :gen_event

  def init(forward) do
    {:ok, forward}
  end

  def handle_call(request, forward) do
    send(forward, {:bus_proxy, :call, self(), request})
    {:ok, :ok, forward}
  end

  def handle_event(event, forward) do
    send(forward, {:bus_proxy, :event, self(), event})
    {:ok, forward}
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
  def callback_mode(), do: :handle_event_function


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

  def handle_event({:call, from}, :join, :waiting, %{players: players} = data) do
    {pid, _} = from

    {:next_state, :waiting,
     %{data | players: unique_append(players, pid)},
     [{:reply, from, :ok}]
    }
  end

  def handle_event(:cast, :debug, state, data) do
    IO.inspect({:cast, :debug, state, data})
    {:next_state, :waiting, data}
  end

  def handle_event({:call, from}, :begin, :waiting, %{players: players} = data) when length(players) < @min_players do
    {:next_state, :waiting, data, [{:reply, from, {:error, :not_enough_players}}]}
  end

  def handle_event({:call, from}, :begin, :waiting, %{players: players}) do
    pid_index = players
    |> Enum.with_index()
    |> Enum.into(%{})

    index_pid = pid_index
    |> Enum.map(fn {a, b} -> {b, a} end)
    |> Enum.into(%{})

    for {pid, index} <- pid_index do
      send(pid, {:game_begin, pid, index})
    end

    {:next_state, :playing,
     %{pid_index: pid_index, index_pid: index_pid}, # todo actually start game
     [{:reply, from, :ok}]}
  end

  # Any state

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
