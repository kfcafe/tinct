defmodule Tinct.CommandTest do
  use ExUnit.Case, async: true

  alias Tinct.Command

  doctest Tinct.Command

  describe "async/2" do
    test "returns {:async, fun, tag} tuple" do
      fun = fn -> :ok end
      assert {:async, ^fun, :my_tag} = Command.async(fun, :my_tag)
    end

    test "the captured fun is callable (0-arity)" do
      {:async, fun, _tag} = Command.async(fn -> 42 end, :answer)
      assert fun.() == 42
    end

    test "tag can be an atom" do
      assert {:async, _fun, :fetch} = Command.async(fn -> nil end, :fetch)
    end

    test "tag can be a tuple" do
      tag = {:http, :get, "/users"}
      assert {:async, _fun, ^tag} = Command.async(fn -> nil end, tag)
    end

    test "tag can be a string" do
      assert {:async, _fun, "request_1"} = Command.async(fn -> nil end, "request_1")
    end
  end

  describe "none/0" do
    test "returns nil" do
      assert Command.none() == nil
    end
  end

  describe "batch/1" do
    test "filters out nils" do
      assert Command.batch([nil, :quit, nil]) == {:batch, [:quit]}
    end

    test "empty list returns {:batch, []}" do
      assert Command.batch([]) == {:batch, []}
    end

    test "all nils returns {:batch, []}" do
      assert Command.batch([nil, nil]) == {:batch, []}
    end

    test "preserves order of non-nil commands" do
      cmd1 = Command.async(fn -> :a end, :first)
      cmd2 = :quit
      cmd3 = Command.async(fn -> :b end, :second)

      {:batch, commands} = Command.batch([cmd1, nil, cmd2, nil, cmd3])

      assert [^cmd1, :quit, ^cmd3] = commands
    end

    test "nested batch wraps without flattening" do
      inner = Command.batch([:quit])
      outer = Command.batch([inner, :quit])

      assert {:batch, [{:batch, [:quit]}, :quit]} = outer
    end
  end

  describe "quit/0" do
    test "returns :quit" do
      assert Command.quit() == :quit
    end
  end
end
