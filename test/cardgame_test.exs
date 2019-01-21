defmodule CardgameTest do
  use ExUnit.Case
  doctest Cardgame

  test "greets the world" do
    assert Cardgame.hello() == :world
  end
end
