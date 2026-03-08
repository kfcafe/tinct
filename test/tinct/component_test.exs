defmodule Tinct.ComponentTest do
  use ExUnit.Case, async: true

  alias Tinct.Command
  alias Tinct.Component
  alias Tinct.Element
  alias Tinct.View

  doctest Tinct.Command
  doctest Tinct.Component

  # --- Test component ---

  defmodule Counter do
    @moduledoc false
    use Tinct.Component

    @impl Tinct.Component
    def init(opts), do: Keyword.get(opts, :start, 0)

    @impl Tinct.Component
    def update(count, :increment), do: count + 1
    def update(count, :decrement), do: count - 1
    def update(_count, :reset), do: {0, Command.none()}
    def update(_count, {:set, n}), do: {n, Command.none()}
    def update(count, _msg), do: count

    @impl Tinct.Component
    def view(count) do
      View.new(Element.text("Count: #{count}"))
    end
  end

  defmodule WithSubscriptions do
    @moduledoc false
    use Tinct.Component

    @impl Tinct.Component
    def init(_opts), do: %{ticking: true}

    @impl Tinct.Component
    def update(model, _msg), do: model

    @impl Tinct.Component
    def view(_model), do: View.new(Element.text("tick"))

    @impl Tinct.Component
    def subscriptions(%{ticking: true}), do: [:tick_every_second]
    def subscriptions(_model), do: []

    @impl Tinct.Component
    def handle_tick(model), do: model
  end

  # --- use Tinct.Component ---

  describe "use Tinct.Component" do
    test "module compiles and is recognized as a component" do
      assert Counter.__tinct_component__() == true
    end

    test "default subscriptions/1 returns empty list" do
      assert Counter.subscriptions(:any_model) == []
    end

    test "default handle_tick/1 returns model unchanged" do
      model = %{count: 5}
      assert Counter.handle_tick(model) == model
    end

    test "optional callbacks can be overridden" do
      assert WithSubscriptions.subscriptions(%{ticking: true}) == [:tick_every_second]
      assert WithSubscriptions.subscriptions(%{ticking: false}) == []
    end
  end

  # --- Counter component ---

  describe "Counter component" do
    test "init/1 initializes from options" do
      assert Counter.init(start: 10) == 10
    end

    test "init/1 defaults to 0" do
      assert Counter.init([]) == 0
    end

    test "update/2 handles increment" do
      assert Counter.update(0, :increment) == 1
      assert Counter.update(5, :increment) == 6
    end

    test "update/2 handles decrement" do
      assert Counter.update(5, :decrement) == 4
      assert Counter.update(0, :decrement) == -1
    end

    test "update/2 can return {model, command}" do
      assert Counter.update(5, :reset) == {0, nil}
      assert Counter.update(5, {:set, 42}) == {42, nil}
    end

    test "update/2 ignores unknown messages" do
      assert Counter.update(5, :unknown) == 5
    end

    test "view/1 returns a View struct" do
      view = Counter.view(3)
      assert %View{} = view
      assert view.content.attrs.content == "Count: 3"
    end
  end

  # --- Command ---

  describe "Command.async/2" do
    test "creates an async command tuple" do
      fun = fn -> :result end
      cmd = Command.async(fun, :reply)

      assert {:async, ^fun, :reply} = cmd
    end

    test "accepts any term as reply_tag" do
      fun = fn -> :ok end

      assert {:async, _, {:response, 1}} = Command.async(fun, {:response, 1})
      assert {:async, _, "string_tag"} = Command.async(fun, "string_tag")
    end
  end

  describe "Command.none/0" do
    test "returns nil" do
      assert Command.none() == nil
    end
  end

  describe "Command.batch/1" do
    test "wraps commands in a batch tuple" do
      cmd = Command.batch([:quit, :quit])
      assert cmd == {:batch, [:quit, :quit]}
    end

    test "filters out nil commands" do
      cmd = Command.batch([:quit, nil, :quit, nil])
      assert cmd == {:batch, [:quit, :quit]}
    end

    test "returns empty batch when all are nil" do
      assert Command.batch([nil, nil]) == {:batch, []}
    end

    test "returns empty batch for empty list" do
      assert Command.batch([]) == {:batch, []}
    end
  end

  describe "Command.quit/0" do
    test "returns :quit" do
      assert Command.quit() == :quit
    end
  end

  # --- normalize_update_result ---

  describe "Component.normalize_update_result/1" do
    test "wraps plain model in {model, nil}" do
      assert Component.normalize_update_result(42) == {42, nil}
      assert Component.normalize_update_result(:state) == {:state, nil}
      assert Component.normalize_update_result(%{a: 1}) == {%{a: 1}, nil}
    end

    test "passes through {model, command} tuples" do
      assert Component.normalize_update_result({42, :quit}) == {42, :quit}
      assert Component.normalize_update_result({%{}, nil}) == {%{}, nil}
    end

    test "passes through {model, batch command}" do
      cmd = Command.batch([:quit])
      assert Component.normalize_update_result({:model, cmd}) == {:model, cmd}
    end

    test "wraps lists as plain models (not tuples)" do
      assert Component.normalize_update_result([1, 2, 3]) == {[1, 2, 3], nil}
    end
  end
end
