defmodule GameState do
  require Util

  # @empty_state %{players: %{},
  #                current: %{},
  #                num_players: 0,
  #                play_area: [],
  #                deck: [],
  #                discard: []}

  # @default_player %{hand: []}

  # Example GameState lenses.
  @deck [:deck]
  @players [:players]
  @discard [:discard]
  # @topdeck @deck ++ [0]
  @topplay [:play_area, 0]
  # @current_player @players ++ [{:dynamic, :current}]
  @hand_size 5

  def nth_player_lens(n), do: @players ++ [n]

  def default_deck() do
    Stream.repeatedly(Util.thunk(%{name: :draw}))
    |> Stream.take(100)
    |> Enum.to_list()

  end

  def new_game(num_players), do: new_game(num_players, default_deck())

  def new_game(num_players, deck, hand_size \\ @hand_size) do
    deck = Enum.shuffle(deck)
    all_hands = Enum.chunk_every(deck, hand_size)

    {player_hands, remaining} = Enum.split(all_hands, num_players)

    remaining_deck = List.flatten(remaining)

    players = player_hands
    |> Enum.map(fn hand -> %{hand: hand} end)
    |> Enum.with_index()
    |> Enum.map(fn {a, b} -> {b, a} end)
    |> Enum.into(%{})

    %{current: 0,
      num_players: num_players,
      discard: [],
      deck: remaining_deck,
      players: players,
      play_area: []
    }
  end

  def tick(state) do
    tick(state, DefaultCards)
  end

  @doc """
  Executes a "game tick", returning `{:ok, state}` normally,
  `{:ok, state, :ready}` if the state is ready for the next
  play, and `{:ok, state, :requires_play}` if the player needs to
  play a card (see tick/2)
  """
  def tick(%{play_area: []} = state, _) do
    {:ok, state, :ready}
  end

  def tick(state, dispatch) do
    case Lens.view(state, @topplay) do
      :requires_play -> {:ok, state, :requires_play}
      card -> {:ok, card_dispatch(state, card, dispatch), :continue}
    end
  end

  def tick(%{play_area: [:requires_play | _]} = state, card, dispatch) do
    state = Lens.set(state, @topplay, card)
    tick(state, dispatch)
  end

  @doc """
  Play a card from the current player's hand.
  """
  def hand_play(state, index) do
    {card, state} = Lens.get_update(state,
      [:players, {:dynamic, :current}, :hand],
      &(List.pop_at(&1, index))
    )

    Lens.map(state, [:play_area], &(push(&1, card)))
  end

  @doc """
  Draws a card from the deck, shuffling the discard into the deck if empty.
  Returns {new_state, card}
  """
  def draw_card(state) do
    state = if state[:deck] == [] do
      discard = state |> Lens.view(@discard)
      state = state |> Lens.set(@discard, [])

      state
      |> Lens.set(@deck, Enum.shuffle(discard))
    else
      state
    end

    {card, state} = state |> Lens.get_update(:deck, &pop/1)

    {state, card}
  end

  @doc """
  Find the player index of the next player.
  """
  def next_player(%{num_players: num_players, current: current}) do
    rem(current + 1, num_players)
  end

  def card_finished(state) do
    {card, state} = Lens.get_update(state, [:play_area], &pop/1)

    state |>
    Lens.map([:discard], &(push(&1, card)))
  end

  @doc """
  End the current player's turn.
  """
  def end_turn(state) do
    state |> Lens.set([:current], next_player(state))
  end

  #require IEx; IEx.pry()

  def card_dispatch(state, card, dispatch) when is_function(dispatch) do
    dispatch.(state, card)
  end

  def card_dispatch(state, card, dispatch) when is_atom(dispatch) do
    :erlang.apply(dispatch, :handle_card, [state, card])
  end

  def card_dispatch(state, card, dispatch) when is_pid(dispatch) do
    GenServer.call(dispatch, {:handle_card, state, card})
  end

  def card_dispatch(state, card, {module, func}) when is_atom(module) and is_atom(func) do
    :erlang.apply(module, func, [state, card])
  end

  defp push(lst, item), do: List.insert_at(lst, 0, item)
  defp pop(lst), do: List.pop_at(lst, 0)

end

defmodule MalformedStateError do
  defexception [:message]

  @impl true
  def exception(state) do
    %MalformedStateError{message: "Encountered malformed game state, #{inspect(state)}"}
  end
end

