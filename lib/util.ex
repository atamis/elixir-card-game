defmodule Util do
  @moduledoc """
  Some uility functions.
  """


  @doc """
  Return an anonymous function 1-arity that evaluates to `value` regardless of input.
  """
  def constantly(value) do
    fn _ -> value end
  end

  @doc """
  Macro for 0 argument anonymous function.

  Rewrites the call to an anonymous function that takes no arugments and executes the body.
  """
  defmacro thunk(body) do
    quote do
      fn ->
        unquote body
      end
    end
  end

  @doc """
  Macro to make conditionally updating a map easier. If conditional is true, it merges
  the result of the body into the original. Otherwise, it returns the original, leaving
  the body unevaluated.
  """
  defmacro cond_put(conditional, orig, body) do
    quote generated: true, location: :keep do
      original = unquote(orig)
      if unquote(conditional) do
        new_map = unquote(body)
        case new_map do
          [do: map] -> Map.merge(original, map)
          # {key, value} -> Map.put(original, key, value)
          map -> Map.merge(original, map)
        end
      else
        original
      end
    end
  end
end
