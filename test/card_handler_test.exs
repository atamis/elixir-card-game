defmodule CardHandlerTest do
  use ExUnit.Case
  doctest DefaultCards

  test "draw card" do
    state1 = %{current: 0,
              players: %{0 => %{hand: []}},
              deck: [:card1, :card2],
              play_area: [%{name: :draw}],
              discard: []
             }

    state2 = %{state1 | players: %{0 => %{hand: [:card1]}},
               deck: [:card2],
               play_area: [],
               discard: [%{name: :draw}]}

    assert state2 == DefaultCards.handle_card(state1, %{name: :draw})
  end
end
