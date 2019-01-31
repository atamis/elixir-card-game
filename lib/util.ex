defmodule Util do
  defmacro thunk(body) do
    quote do
      fn ->
        unquote body
      end
    end
  end
end
