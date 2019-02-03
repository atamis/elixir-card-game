defmodule Lens do
  @moduledoc """
  A simple Lens library.

  This lens library is a simple wrapper around `Kernel.get_and_update_in/3` and
  related functions. By augmenting the meaning of the "path" that those functions
  take, this Lens library provides an easier and more featureful than the
  default.

  This lens library consists primarily of `view/2`, `set/3`, and `map/3` (as
  well as `get_update/3`, a flexible although difficult to use function.) All
  these functions take a data structure in their first argument, and `t:path/0`
  in their second argument.

  ## Paths

  A path is a list of keys or extras for accessing deeply nested data
  structures. The direct keys can be any valid key, and are treated "correctly"
  in context. For example, an integer can be used as the index of a list or the
  key to a map.


  ```
  iex> Lens.view([1, 2, 3], [0])
  1
  iex> Lens.view(%{0 => :test, 1 => :asdf}, [0])
  :test
  ```

  You can also elide the list if you only have 1 key.

  ```
  iex> Lens.view([1, 2, 3], 0)
  1
  ```

  You can also use atoms as keys.

  ```
  iex> Lens.view(%{test: 1}, :test)
  1
  ```

  And you can obviously access structures recursively in order.


  ```
  iex> Lens.view(%{test1: %{test2: [1, 2, 3]}}, [:test1, :test2, 2])
  3
  ```

  One of the extra features available is `{:all}`, which selects every item in
  the datastructure, but continues applying the path to all the those elemnts.

  ```
  iex> Lens.view(%{a: %{asdf: 1}, b: %{asdf: 2}, c: %{asdf: 3}}, [{:all}, :asdf])
  %{a: 1, b: 2, c: 3}
  ```

  `{:all}` also works on maps.

  ```
  iex> Lens.view(%{a: [1, 2, 3], b: [4, 5, 6], c: [7, 8, 9]}, [{:all}, 1])
  %{a: 2, b: 5, c: 8}
  ```

  The other extra feature is `{:dynamic, <subpath>}`. When this is encountered, the
  root datastructure is consulted with the path to get the new key. That is, it is
  replaced in the path with the result of `Lens.view(struct, subpath)`, where
  `struct` is the original root structure, not where you are in the path currently.
  This lets you use keys or indexes embedded in the data structure to reference
  other parts of the data structure. For example, you can store an index into an
  array representing the current item, and then update that index with the other
  `Lens` functions.

  ```
  iex> struct = %{list: [1, 2, 3, 4, 5], index: 3}
  iex> Lens.view(struct, [:list, {:dynamic, :index}])
  4
  ```

  In this case, the result of `Lens.view(struct, :index)` replaces
  `{:dynamic, :index}` in the path, so the new path is `{:list, 3}`. This is done
  _at access time_ rather than run time, so if index changes, the dynamic path
  element is recaulcated.

  This can be done recursively.

  ```
  iex> struct = %{list: [1, 2, 3, 4, 5], index: 2, index_loc: {:dynamic, :index}}
  iex> Lens.view(struct, [:list, {:dynamic, :index_loc}])
  3
  ```

  The path element is first replaced with the value of the `:index_loc` key,
  which is another dynamic path element, which is evaluated against the same
  data structure. If you're curious what concrete path a particular path will
  evaluate to if applied to a particular data structure (without actually
  changing that data structure), you can use the `Lens.lens_path_resolve/2`
  function.

  """

  @typedoc """
  Represents a path into a data structure, with support for any number of key
  types, along with support for wildcard selection and dynamic paths. See `Lens`
  for more information.
  """
  @type path :: [any() | {:dynamic, path()} | {:all}]

  # TODO: fix :get_and_update and returning :pop

  @doc """
  Return the element identfied by the `lens`.

  ```
  iex> Lens.view(%{test: 1}, :test)
  1
  ```

  """
  def view(struct, []), do: struct
  def view(struct, lens) do
    get_in(struct, lens_path_resolve(struct, lens))
  end

  @doc """
  Return the structure modified so the element identifed by the `lens` is set
  to value.


  ```
  iex> Lens.set(%{test: 1}, :test, 2)
  %{test: 2}
  ```

  """
  def set(_, [], value), do: value
  def set(struct, lens, value) do
    update_in(struct, lens_path_resolve(struct, lens), Util.constantly(value))
  end

  @doc """
  Return the structure modified so the element identifed by the `lens` is set
  to value the result of applying that element to `fun`.


  ```
  iex> Lens.map(%{test: 3}, :test, &(1 + &1))
  %{test: 4}
  ```
  """
  def map(struct, [], fun), do: fun.(struct)
  def map(struct, lens, fun) do
    update_in(struct, lens_path_resolve(struct, lens), fun)
  end

  @doc """
  A lens that can do `view/2` and `map/3` at the same time.

  Combines view and map in the same way as `Kernel.get_and_update_in/3`, where
  `fun` returns a tuple of `{get_value, new_value}`, where the `new_value`
  replaces the old value in the element, and `get_value` is ultimately returned
  to the user when `get_update/3` returns `{get_value, new_structure}`


  ```
  iex> fun = fn x -> {x, x + 1} end
  iex> Lens.get_update(%{test: 3}, :test, fun)
  {3, %{test: 4}}
  ```
  """
  def get_update(struct, lens, fun) do
    get_and_update_in(struct, lens_path_resolve(struct, lens), fun)
  end

  @doc """
  Evaluate an abstract path.

  Evaluate an abstract and potentially dynamic path against a particular
  data structure to get a concrete path. This is used internally by the lens
  functions, and returns a path suitable for handing to
  `Kernel.get_and_update_in/3` and related functions.

  This can be used to "cache" a dynamic path for reuse, but care should be taken
  to invalidate the cache at appropriate times.


  ```
  iex> Lens.lens_path_resolve(%{test: 3}, :test)
  [:test]
  ```

  It also resolves dynamic path elements

  ```
  iex> Lens.lens_path_resolve(%{test: :extra}, {:dynamic, :test})
  [:extra]
  iex> Lens.lens_path_resolve(%{asdf: :extra, test: {:dynamic, :asdf}}, {:dynamic, :test})
  [:extra]
  ```
  """
  def lens_path_resolve(struct, lens) when not is_list(lens), do: lens_path_resolve(struct, [lens])

  def lens_path_resolve(struct, lens) do
    Enum.map(lens, &(resolve_item(struct, &1)))
  end

  defp resolve_item(_, {:all}) do
    all_access()
  end

  defp resolve_item(struct, {:dynamic, sublens}) do
    resolve_item(struct, view(struct, sublens))
  end

  defp resolve_item(_, item) when is_number(item) do
    number_access(item)
  end

  defp resolve_item(_, item) when is_atom(item) do
    item
  end

  @doc false
  def number_access(n) do
    fn action, data, next ->
      case {action, data, next} do
        {action, data, next} when is_list(data) -> Access.at(n).(action, data, next)
        {action, data, next} when is_tuple(data) -> Access.elem(n).(action, data, next)
        {action, data, next} when is_map(data) -> Access.key(n, nil).(action, data, next)
      end
    end
  end

  @doc false
  def all_access() do
    fn action, data, next ->
      #require IEx; IEx.pry

      case {action, data, next} do
        {action, data, next} when is_list(data) -> Access.all().(action, data, next)
        {:get, data, next} -> data |> Enum.map(fn {key, value} -> {key, next.(value)} end) |> Enum.into(%{})
        {:get_and_update, data, next} ->
            combined = data
            |> Enum.map(fn {key, value} ->
              {get, update} = next.(value)
              {{key, get}, {key, update}}
            end)
              |> Enum.into(%{})

            get_map = combined |> Enum.map(&(elem(&1, 0))) |> Enum.into(%{})
            updated_map = combined |> Enum.map(&(elem(&1, 1))) |> Enum.into(%{})
            {get_map, updated_map}
      end
    end
  end
end


