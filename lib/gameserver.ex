defmodule GameServer do
  @min_players 2

  @behaviour :gen_statem
  def callback_mode(), do: :handle_event_function


  def start_link() do
    :gen_statem.start_link(__MODULE__, nil, [])
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

  def init(_args) do
    {:ok, :waiting, %{players: []}}
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
end
