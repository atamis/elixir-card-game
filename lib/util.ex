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
end
