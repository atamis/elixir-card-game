defmodule EventBus do
  use GenServer
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [nil], opts)
  end

  def start(opts \\ []) do
    GenServer.start(__MODULE__, [nil], opts)
  end

  def subscribe(bus), do: subscribe(bus, self())
  def subscribe(bus, subj), do: GenServer.call(bus, {:subscribe, subj, false})

  def subscribe_link(bus), do: subscribe_link(bus, self())
  def subscribe_link(bus, subj), do: GenServer.call(bus, {:subscribe, subj, true})

  def notify(pid, msg) do
    GenServer.cast(pid, {:notify, msg})
  end

  # Callbacks

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
