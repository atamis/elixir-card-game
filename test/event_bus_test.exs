defmodule EventBusTest do
  use ExUnit.Case
  doctest GameServer

  setup do
    {:ok, bus} = EventBus.start_link()
    %{bus: bus}
  end

  test "basic notify", %{bus: bus} do
    EventBus.subscribe(bus)
    EventBus.notify(bus, :message1)

    assert_receive :message1
  end

  test "basic broadcast", %{bus: bus} do
    {:ok, proxy} = Proxy.start_link(self())
    EventBus.subscribe(bus)
    EventBus.subscribe_link(bus, proxy)

    EventBus.notify(bus, :message)

    assert_receive(:message)
    assert_receive({:proxy, ^proxy, :message})
  end

  test "client failure", %{bus: bus} do
    # Testing internal implementation details is a bad idea
    # but it's important to be sure that exits are properly handled

    {:ok, proxy} = Proxy.start(self())
    EventBus.subscribe(bus, proxy)

    assert MapSet.member?(:sys.get_state(bus), proxy)

    Proxy.stop(proxy)

    assert not MapSet.member?(:sys.get_state(bus), proxy)
  end

  test "linked client failure", %{bus: bus} do
    {:ok, proxy} = Proxy.start(self())
    EventBus.subscribe_link(bus, proxy)

    assert MapSet.member?(:sys.get_state(bus), proxy)

    Proxy.stop(proxy)

    # It can take a little bit for the kill to propagate
    Process.sleep(100)

    assert not MapSet.member?(:sys.get_state(bus), proxy)
  end

  test "linked bus failure" do
    {:ok, bus} = EventBus.start()
    {:ok, proxy} = Proxy.start(self())

    EventBus.subscribe_link(bus, proxy)

    Process.exit(bus, :kill)

    assert not Process.alive?(bus)
    assert not Process.alive?(proxy)
  end


  test "legacy combo test" do
    {:ok, bus} = EventBus.start_link([nil])

    EventBus.subscribe(bus)

    EventBus.notify(bus, :message)

    assert_receive(:message)

    {:ok, proxy} = Proxy.start_link(self())

    EventBus.subscribe(bus, proxy)

    EventBus.notify(bus, :message)

    assert_receive(:message)
    assert_receive({:proxy, ^proxy, :message})

    Process.exit(proxy, :normal)

    EventBus.notify(bus, :message)

    assert_receive(:message)
  end
end
