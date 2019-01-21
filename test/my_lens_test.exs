defmodule MyLensTest do
  use ExUnit.Case
  doctest Lens

  import Lens


  test "view empty" do
    assert :test == view(:test, [])
  end

  test "numeric lens" do
    assert 1 == view([1, 2], [0])
    assert 2 == view([1, 2], [1])
    assert :asdf == view({1, :asdf}, [1])
    assert :asdf == view(%{0 => :test, 1 => :asdf}, [1])
  end

  test "view map key" do
    assert "test" == view(%{test: "test"}, [:test])
    assert "test" == view(%{test: "test"}, :test)
  end

  test "nested maps" do
    assert "asdf" == view(%{test: %{qwer: "asdf"}}, [:test, :qwer])
  end

  test "dynamic resoution" do
    assert 3 == view(%{list: [3, 4, 5], index: 0}, [:list, {:dynamic, [:index]}])

    assert 3 == view(%{list: [3, 4, 5], index: 0, index_lens: {:dynamic, [:index]}}, [:list, {:dynamic, [:index_lens]}])
    assert 3 == view(%{list: [3, 4, 5], index: 0, index_lens: {:dynamic, :index}}, [:list, {:dynamic, :index_lens}])
  end

  test "all" do
    assert [1, 2, 3] == view([1, 2, 3], [{:all}])
    assert [1, 2, 3] == view(%{test: [1, 2, 3]}, [:test, {:all}])
    assert %{a: 1, b: 2, c: 3} == view(%{a: %{asdf: 1}, b: %{asdf: 2}, c: %{asdf: 3}}, [{:all}, :asdf])
  end

  test "easy set" do
    assert :asdf == set(:qwer, [], :asdf)
  end

  test "map set" do
    assert %{test: 1} == set(%{test: 0}, [:test], 1)
    assert %{test: %{asdf: 1}} == set(%{test: %{asdf: 0}}, [:test, :asdf], 1)
  end

  test "numeric set" do
    assert [5, 1, 2] == set([0, 1, 2], [0], 5)
    assert {5, 1, 2} == set({0, 1, 2}, [0], 5)
    assert %{0 => :asdf, 1 => :qwer} == set(%{0 => :asdf, 1 => false}, [1], :qwer)
  end

  test "dynamic set" do
    assert %{index: :asdf, asdf: 1} == set(%{index: :asdf, asdf: false}, [{:dynamic, :index}], 1)
  end

  test "set all" do
    assert [%{asdf: false}, %{asdf: false}, %{asdf: false}] == set([%{asdf: 0}, %{asdf: 1}, %{asdf: 2}], [{:all}, :asdf], false)
    #assert {%{asdf: false}, %{asdf: false}, %{asdf: false}} == set({%{asdf: 0}, %{asdf: 1}, %{asdf: 2}}, [{:all}, :asdf], false)
    assert %{asdf: %{asdf: false}, qwer: %{asdf: false}, test: %{asdf: false}} ==
      set(%{asdf: %{asdf: 0}, qwer: %{asdf: 1}, test: %{asdf: 2}}, [{:all}, :asdf], false)
  end

  def inc(n), do: n + 1

  test "easy map" do
    assert 1 == map(0, [], &inc/1)
  end

  test "map map" do
    assert %{asdf: 1} == map(%{asdf: 0}, [:asdf], &inc/1)
    assert %{test: %{asdf: 1}} == map(%{test: %{asdf: 0}}, [:test, :asdf], &inc/1)
  end

  test "numeric map" do
    assert [1, 1, 2] == map([0, 1, 2], [0], &inc/1)
  end

  test "dynamic map" do
    assert %{index: :asdf, asdf: 1} == map(%{index: :asdf, asdf: 0}, [{:dynamic, :index}], &inc/1)
  end

  test "map all" do
    assert [1, 2, 3] == map([0, 1, 2], [{:all}], &inc/1)
    assert %{asdf: 1, qwer: 2, test: 3} == map(%{asdf: 0, qwer: 1, test: 2}, [{:all}], &inc/1)

    assert %{asdf: %{asdf: 1}, qwer: %{asdf: 2}, test: %{asdf: 3}} ==
      map(%{asdf: %{asdf: 0}, qwer: %{asdf: 1}, test: %{asdf: 2}}, [{:all}, :asdf], &inc/1)
  end
end
