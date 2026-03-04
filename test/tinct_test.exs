defmodule TinctTest do
  use ExUnit.Case
  doctest Tinct

  test "greets the world" do
    assert Tinct.hello() == :world
  end
end
