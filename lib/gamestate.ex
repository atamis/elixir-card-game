defmodule GameState do
  import Lens

  @empty_state %{players: %{},
                 current: %{},
                 num_players: 0,
                 play_area: nil,
                 deck: [],
                 discard: []}

  @deck [:deck]
  @players [:players]
  @discard [:discard]
  @topdeck @deck ++ [0]
  @current_player @players ++ [{:dynamic, :curent}]

  # Draws a card from the deck, shuffling the discard into the deck if empty.
  # Returns {new_state, card}
  def draw_card(state) do
    state = if state[:deck] == [] do
      discard = state |> Lens.view(@discard)
      state = state |> Lens.set(@discard, [])

      state
      |> Lens.set(@deck, Enum.shuffle(discard))
    else
      state
    end

    {card, state} = Map.get_and_update(state, :deck, &(List.pop_at(&1, 0)))

    {state, card}
  end

  def next_player(%{num_players: num_players, current: current}) do
    rem(current + 1, num_players)
  end

end

