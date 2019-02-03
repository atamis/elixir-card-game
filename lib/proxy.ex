defmodule Proxy do
  use GenServer

  @moduledoc """
  A proxy GenServer.

  Acts as a proxy, or remote controllable process. It takes an argument,
  and forwards all messages it receives to that process, wrapped in some
  metadata:

  ```
  {:proxy, <proxy pid>, <message>}
  ```

  It additionally supports "remote control" message sending, and local
  function execution.
  """

  @doc """
  Start and link a proxy, forwarding received messages to a pid, `forward`.
  """
  def start_link(forward) do
    GenServer.start_link(__MODULE__, forward)
  end

  @doc """
  Start a proxy, forwarding received messages to a pid, `forward`.
  """
  def start(forward) do
    GenServer.start(__MODULE__, forward)
  end

  @doc """
  Stop this `Proxy`.
  """
  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  @doc """
  Direct this `Proxy` to send a message to a pid.
  """
  def send(pid, to, msg) do
    GenServer.call(pid, {:send, to, msg})
  end

  @doc """
  Direct this `Proxy` to execute a function locally.

  This is most useful for calling/casting to `GenServer`s.
  """
  def exec(pid, fun) do
    GenServer.call(pid, {:exec, fun})
  end

  @doc false
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
