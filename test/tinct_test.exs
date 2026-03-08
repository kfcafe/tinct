defmodule TinctTest do
  use ExUnit.Case, async: true
  doctest Tinct

  test "quit/1 returns model and :quit command" do
    {model, cmd} = Tinct.quit(%{count: 1})
    assert model == %{count: 1}
    assert cmd == :quit
  end
end
