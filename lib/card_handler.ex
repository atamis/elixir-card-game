defmodule DefaultCards do

  @players [:players]
  @current_player @players ++ [{:dynamic, :current}]

  def handle_card(state, %{name: :draw}) do
    {state, card} = GameState.draw_card(state)


    state
    |> Lens.map(@current_player ++ [:hand], &(push(&1, card)))
    |> GameState.card_finished()
  end

  defp push(lst, item), do: List.insert_at(lst, 0, item)

end

# Failed attempts

# defmodule CardHandler do

#   @moduledoc """
#   ```
#   defmodule ExhaustiveCards do
#     use CardHandler, exhaustive: true

#     @players [:players]
#     @current_player @players ++ [{:dynamic, :current}]

#     def handle_card(state, %{dispatch: :draw}) do
#       {state, card} = GameState.draw_card(state)


#       state
#       |> Lens.map(@current_player ++ [:hand], &(push(&1, card)))
#       |> GameState.card_finished()
#     end

#     defp push(lst, item), do: List.insert_at(lst, 0, item)
#   end

#   defmodule EmptyExhaustiveCards do
#     use CardHandler, exhaustive: true
#   end
#   ```

#   """


#   defmacro __using__(opts) do
#     exhaustive = Keyword.get(opts, :exhaustive, false)
#     quote do
#       @behaviour CardHandler

#       def handle_card(nil, _) do
#         raise MalformedStateError, nil
#       end

#       unquote do
#         if not exhaustive do
#           quote do
#             def handle_card(_, _) do
#               false
#             end
#           end
#         end
#       end
#     end
#   end

#   # state, card -> state
#   @callback handle_card(term, term) :: term
# end


# defmodule AllCards do
#   @behaviour CardHandler
#   @handlers [DefaultCards]

#   def handle_card(state, card) do
#     Enum.find_value(@handlers, false, &(apply(&1, :handle_card, [state, card])))
#   end
# end

# defmodule ExhaustiveCards do
#   use CardHandler, exhaustive: true

# end

# defmodule EmptyExhaustiveCards do
#   use CardHandler, exhaustive: true
# end

# defmodule Card.RegisterCards do
#   defmacro __before_compile__(env) do
#     cards = Module.get_attribute(env.module, :cards)
#     IO.inspect(cards)
#     quote do
      
#     end
#   end
# end

# defmodule Card do
#   Module.register_attribute(__MODULE__, :card, accumulate: true)

#   defmacro __using__(opts) do
#     name = Keyword.get(opts, :name, "Unnamed Card")
#     tag = Keyword.get(opts, :tag, __MODULE__)

#     Module.put_attribute(Card, :card, {tag, __MODULE__})

#     quote do
#       @behaviour Card
#       @impl
#       def name(), do: unquote do: name
#       @impl
#       def tag, do: unquote  do: tag
#     end
#   end

#   # state, card -> state
#   @callback apply(term, term) :: term
#   @callback name() :: String.t()
#   @callback tag() :: term


#   @before_compile Card.RegisterCards

# end

# defmodule DrawCard do
#   use Card, name: "Draw", tag: :draw

#   def apply(state, _) do
#     state
#   end
# end
