defmodule GameStateTest do
  use ExUnit.Case
  doctest GameState

  test "normal" do
    state = %{deck: [1, 2], discard: []}

    {state, card1} = GameState.draw_card(state)

    assert state == %{deck: [2], discard: []}
    assert card1 == 1

    {state, card2} = GameState.draw_card(state)

    assert state == %{deck: [], discard: []}
    assert card2 == 2

  end

  test "shuffle" do
    state = %{deck: [], discard: [1]}

    {state, card1} = GameState.draw_card(state)

    assert state == %{deck: [], discard: []}
    assert card1 == 1

    state = %{deck: [], discard: [1, 2]}

    {state, card2} = GameState.draw_card(state)

    assert (state == %{deck: [1], discard: []} and card2 == 2) or
        (state == %{deck: [2], discard: []} and card2 == 1)

  end

  test "next player" do
    assert 1 == GameState.next_player(%{current: 0, num_players: 2})
    assert 0 == GameState.next_player(%{current: 1, num_players: 2})

    assert 1 == GameState.next_player(%{current: 0, num_players: 3})
    assert 2 == GameState.next_player(%{current: 1, num_players: 3})
    assert 0 == GameState.next_player(%{current: 2, num_players: 3})
  end

  test "current player lens" do
    state = %{current: 0, players: %{0 => :zero, 1 => :one}}

    # NB: this doesn't get the attribute, so it will break if that changes.
    assert :zero == state |> Lens.view([:players, {:dynamic, :current}])

  end

end
