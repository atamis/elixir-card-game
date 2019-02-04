defmodule EventBus do
  use GenServer
  @moduledoc """
  A simple event bus.

  This allows other processes to subscribe to the events.
  When the event bus is `notified/2`, it sends the message to all subscribed
  processes with no editing or wraping.

  This does no in-bus filtering. Rather, it is tended to represent a single
  subscribable "topic", and the management and registration of multiple topics
  is left to other registration techniques.

  When processes subscribe with `subscribe_link/1` or `subscribe_link/2`, the
  event bus links itself with the process. However, the EventBus traps exits,
  so it won't exit when linked processes exit. This allows processes to be sure
  that if the event bus goes down, they also go down, and the supervision tree
  can handle the rest.
  """

  @doc """
  Delegates to `GenServer.start_link/3`, and passes `opts` directly.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [nil], opts)
  end

  @doc """
  Delegates to `GenServer.start/3`, and passes `opts` directly.
  """
  def start(opts \\ []) do
    GenServer.start(__MODULE__, [nil], opts)
  end

  @doc """
  Subscribe yourself to this event bus.
  """
  def subscribe(bus), do: subscribe(bus, self())

  @doc """
  Subscribe `subj` to this event bus.
  """
  def subscribe(bus, subj), do: GenServer.call(bus, {:subscribe, subj, false})

  @doc """
  Subscribe yourself to this event bus, and link yourself to the event bus.
  """
  def subscribe_link(bus), do: subscribe_link(bus, self())

  @doc """
  Subscribe `subj` to this event bus, and link the 2 processes.
  """
  def subscribe_link(bus, subj), do: GenServer.call(bus, {:subscribe, subj, true})

  @doc """
  Send an event to the event bus.

  This sends `msg` to all subscribed processes. The messages are sent synchronously in
  this process, although this function returns immediately. The EventBus increases its
  priority whenever broadcasting to improve performance.
  """
  def notify(pid, msg) do
    GenServer.cast(pid, {:notify, msg})
  end

  # Callbacks

  @doc false
  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, MapSet.new()}
  end

  def handle_call({:subscribe, pid, link}, _from, set) do
    if link do
      Process.link(pid)
    end
    Process.monitor(pid)
    {:reply, :ok, MapSet.put(set, pid)}
  end

  def handle_cast({:notify, msg}, set) do
    #IO.inspect({:notify, msg})

    # Prevent preemption during broadcast
    # See http://groups.google.com/group/erlang-programming/browse_thread/thread/1931368998000836/b325e869a3eea26a
    oldpriority = Process.flag(:priority, :high)

    for pid <- MapSet.to_list(set) do
      send(pid, msg)
    end

    Process.flag(:priority, oldpriority)

    {:noreply, set}
  end

  def handle_info({:EXIT, from, _reason}, set) do
    {:noreply, MapSet.delete(set, from)}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, set) do
    {:noreply, MapSet.delete(set, pid)}
  end

end
