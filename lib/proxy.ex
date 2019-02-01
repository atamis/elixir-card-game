defmodule Proxy do
  use GenServer

  def start_link(forward) do
    GenServer.start_link(__MODULE__, forward)
  end

  def start(forward) do
    GenServer.start(__MODULE__, forward)
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def send(pid, to, msg) do
    GenServer.call(pid, {:send, to, msg})
  end

  def exec(pid, fun) do
    GenServer.call(pid, {:exec, fun})
  end

  def init(forward) do
    {:ok, forward}
  end

  def handle_call(:stop, _from, forward) do
    {:stop, :shutdown, :ok, forward}
  end

  def handle_call({:send, to, msg}, _from, forward) do
    send(to, msg)
    {:reply, :ok, forward}
  end

  def handle_call({:exec, fun}, _from, forward) do
    fun.()
    {:reply, {:ok, fun.()}, forward}
  end

  def handle_info(msg, forward) do
    send(forward, {:proxy, self(), msg})
    {:noreply, forward}
  end

end
