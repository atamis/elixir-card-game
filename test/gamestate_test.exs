defmodule GameStateTest.DispatchTest do
  use GenServer

  def start_link(output) do
    GenServer.start_link(__MODULE__, output)
  end

  def init(output) do
    {:ok, output}
  end

  def handle_call({:handle_card, _, _}, _, output) do
    {:reply, output, output}
  end
end

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

    assert :one == state |> Lens.view(GameState.nth_player_lens(1))
  end

  test "simple end turn" do
    state1 = %{current: 0, num_players: 2, players: %{0 => :zero, 1 => :one}}

    state2 = GameState.end_turn(state1)

    assert %{state1 | current: 1} == state2

    assert %{state2 | current: 0} == GameState.end_turn(state2)
  end

  test "card finished" do
    state = %{play_area: [%{name: :card1, data: 4}], discard: []}

    assert %{play_area: [], discard: [%{name: :card1, data: 4}]} == GameState.card_finished(state)
  end

  describe "card dispatch" do
    setup do
      state1 = %{current: 0,
                 players: %{0 => %{hand: []}},
                 deck: [:card1, :card2],
                 play_area: [%{name: :draw}],
                 discard: []
                }

      state2 = %{state1 | players: %{0 => %{hand: [:card1]}},
                 deck: [:card2],
                 play_area: [],
                 discard: [%{name: :draw}]
                }
      {:ok, %{state1: state1, state2: state2}}
    end

    test "default dispatch", %{state1: state1, state2: state2} do

      {:ok, end_state} = GameState.tick(state1)

      assert state2 == end_state
    end

    test "nonexistant card", %{state1: state1} do
      state = %{state1 | play_area: [nil]}

      assert_raise FunctionClauseError, fn ->
        GameState.tick(state, DefaultCards)
      end
    end

    test "raw function dispatch", %{state1: state1, state2: state2} do
      assert {:ok, state2} == GameState.tick(state1, fn _, _ -> state2 end)
    end
    
    test "module function tuple dispatch", %{state1: state1, state2: state2} do
      assert {:ok, state2} == GameState.tick(state1, {DefaultCards, :handle_card})
    end

    test "genserver dispatch", %{state1: state1, state2: state2} do
      {:ok, pid} = GameStateTest.DispatchTest.start_link(state2)
      assert {:ok, state2} == GameState.tick(state1, pid)
    end

  end

end
