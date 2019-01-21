defmodule Lens do

  # TODO: fix :get_and_update and returning :pop

  def view(struct, []), do: struct
  def view(struct, lens) do
    get_in(struct, lens_path_resolve(struct, lens))
  end

  def set(_, [], value), do: value
  def set(struct, lens, value) do
    update_in(struct, lens_path_resolve(struct, lens), constantly(value))
  end

  def map(struct, [], fun), do: fun.(struct)
  def map(struct, lens, fun) do
    update_in(struct, lens_path_resolve(struct, lens), fun)
  end

  def get_update(struct, lens, fun) do
    get_and_update_in(struct, lens_path_resolve(struct, lens), fun)
  end

  def lens_path_resolve(struct, lens) when not is_list(lens), do: lens_path_resolve(struct, [lens])

  def lens_path_resolve(struct, lens) do
    Enum.map(lens, &(resolve_item(struct, &1)))
  end

  def resolve_item(_, {:all}) do
    all_access()
  end

  def resolve_item(struct, {:dynamic, sublens}) do
    resolve_item(struct, view(struct, sublens))
  end

  def resolve_item(_, item) when is_number(item) do
    number_access(item)
  end

  def resolve_item(_, item) when is_atom(item) do
    item
  end

  def number_access(n) do
    fn action, data, next ->
      case {action, data, next} do
        {action, data, next} when is_list(data) -> Access.at(n).(action, data, next)
        {action, data, next} when is_tuple(data) -> Access.elem(n).(action, data, next)
        {action, data, next} when is_map(data) -> Access.key(n, nil).(action, data, next)
      end
    end
  end

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

  def constantly(value) do
    fn _ -> value end
  end

  #def view_internal(struct, []) do
    #struct
  #end

  #def view_internal(struct, [{:every}|tail]) when is_list(struct) do
    #Enum.map(struct, &(view_internal(&1, tail)))
  #end

  #def view_internal(struct, [{:every}|tail]) when is_map(struct) do
    #struct
    #|> Enum.map(fn {key, value} -> {key, view_internal(value, tail)} end)
    #|> Enum.into(%{})
  #end

  #def view_internal(struct, [head|tail]) when is_list(struct) do
    #view_internal(Enum.at(struct, head), tail)
  #end

  #def view_internal(struct, [head|tail]) do
    #view_internal(Access.get(struct, head), tail)
  #end
end


