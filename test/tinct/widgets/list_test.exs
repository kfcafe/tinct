defmodule Tinct.Widgets.ListTest do
  use ExUnit.Case, async: true

  alias Tinct.Event
  alias Tinct.Test, as: T
  alias Tinct.Widgets.List, as: ListWidget
  doctest Tinct.Widgets.List

  @fruits ["apple", "banana", "cherry", "date", "elderberry"]

  # --- init ---

  describe "init/1" do
    test "defaults to empty list" do
      model = ListWidget.init([])
      assert model.items == []
      assert model.selected == 0
      assert model.offset == 0
    end

    test "initializes with items" do
      model = ListWidget.init(items: @fruits)
      assert model.items == @fruits
      assert model.selected == 0
    end

    test "initializes with selected index" do
      model = ListWidget.init(items: @fruits, selected: 2)
      assert model.selected == 2
    end

    test "clamps selected index to valid range" do
      model = ListWidget.init(items: @fruits, selected: 100)
      assert model.selected == 4
    end

    test "sets height" do
      model = ListWidget.init(items: @fruits, height: 3)
      assert model.height == 3
    end

    test "sets on_select callback tag" do
      model = ListWidget.init(items: @fruits, on_select: :picked)
      assert model.on_select == :picked
    end
  end

  # --- Rendering ---

  describe "view/1" do
    test "renders items in the visible viewport" do
      state = T.render(ListWidget, items: @fruits, height: 3, size: {20, 5})
      assert T.contains?(state, "apple")
      assert T.contains?(state, "banana")
      assert T.contains?(state, "cherry")
      refute T.contains?(state, "date")
    end

    test "renders empty list without crashing" do
      state = T.render(ListWidget, items: [], size: {20, 5})
      assert %Tinct.Test.State{} = state
    end

    test "renders {label, value} tuple items by label" do
      items = [{"Apple", :apple}, {"Banana", :banana}]
      state = T.render(ListWidget, items: items, size: {20, 5})
      assert T.contains?(state, "Apple")
      assert T.contains?(state, "Banana")
    end
  end

  # --- Key handling: Down / j ---

  describe "down/j navigation" do
    test "down arrow moves selection down" do
      state = T.render(ListWidget, items: @fruits, height: 5)
      assert state.model.selected == 0

      state = T.send_key(state, :down)
      assert state.model.selected == 1

      state = T.send_key(state, :down)
      assert state.model.selected == 2
    end

    test "j key moves selection down" do
      state = T.render(ListWidget, items: @fruits, height: 5)
      state = T.send_key(state, "j")
      assert state.model.selected == 1
    end

    test "down stops at last item" do
      state = T.render(ListWidget, items: ["a", "b"], height: 5)
      state = T.send_key(state, :down)
      assert state.model.selected == 1

      state = T.send_key(state, :down)
      assert state.model.selected == 1
    end
  end

  # --- Key handling: Up / k ---

  describe "up/k navigation" do
    test "up arrow moves selection up" do
      state = T.render(ListWidget, items: @fruits, height: 5, selected: 2)
      assert state.model.selected == 2

      state = T.send_key(state, :up)
      assert state.model.selected == 1
    end

    test "k key moves selection up" do
      state = T.render(ListWidget, items: @fruits, height: 5, selected: 2)
      state = T.send_key(state, "k")
      assert state.model.selected == 1
    end

    test "up stops at first item" do
      state = T.render(ListWidget, items: @fruits, height: 5)
      state = T.send_key(state, :up)
      assert state.model.selected == 0
    end
  end

  # --- Mouse wheel navigation ---

  describe "mouse wheel navigation" do
    test "wheel down moves selection down" do
      state = T.render(ListWidget, items: @fruits, height: 5)

      state =
        T.send_event(state, %Event.Mouse{type: :wheel, button: :wheel_down, x: 0, y: 0})

      assert state.model.selected == 1
    end

    test "wheel up moves selection up" do
      state = T.render(ListWidget, items: @fruits, height: 5, selected: 2)

      state = T.send_event(state, %Event.Mouse{type: :wheel, button: :wheel_up, x: 0, y: 0})

      assert state.model.selected == 1
    end
  end

  # --- Key handling: Home/End/g/G ---

  describe "home/end/g/G navigation" do
    test "home jumps to first item" do
      state = T.render(ListWidget, items: @fruits, height: 5, selected: 3)
      state = T.send_key(state, :home)
      assert state.model.selected == 0
    end

    test "g jumps to first item" do
      state = T.render(ListWidget, items: @fruits, height: 5, selected: 3)
      state = T.send_key(state, "g")
      assert state.model.selected == 0
    end

    test "end jumps to last item" do
      state = T.render(ListWidget, items: @fruits, height: 5)
      state = T.send_key(state, :end)
      assert state.model.selected == 4
    end

    test "G jumps to last item" do
      state = T.render(ListWidget, items: @fruits, height: 5)
      state = T.send_key(state, "G")
      assert state.model.selected == 4
    end
  end

  # --- Scrolling ---

  describe "scrolling" do
    test "scrolls down when selection moves below viewport" do
      state = T.render(ListWidget, items: @fruits, height: 3)
      # Initially shows items 0-2, offset 0
      assert state.model.offset == 0

      # Move to item 3 (past viewport of 3)
      state = state |> T.send_key(:down) |> T.send_key(:down) |> T.send_key(:down)
      assert state.model.selected == 3
      assert state.model.offset == 1
    end

    test "scrolls up when selection moves above viewport" do
      # Start scrolled down: selected=4 in a height-3 viewport
      state = T.render(ListWidget, items: @fruits, height: 3, selected: 4)
      # offset should adjust to show item 4
      assert state.model.selected == 4
      assert state.model.offset == 2

      # Now move up past the viewport top
      state = state |> T.send_key(:up) |> T.send_key(:up) |> T.send_key(:up)
      assert state.model.selected == 1
      assert state.model.offset == 1
    end

    test "home scrolls back to top" do
      state = T.render(ListWidget, items: @fruits, height: 3, selected: 4)
      assert state.model.offset == 2

      state = T.send_key(state, :home)
      assert state.model.selected == 0
      assert state.model.offset == 0
    end

    test "end scrolls to bottom" do
      state = T.render(ListWidget, items: @fruits, height: 3)
      state = T.send_key(state, :end)
      assert state.model.selected == 4
      assert state.model.offset == 2
    end
  end

  # --- Page Up / Page Down ---

  describe "page up/down" do
    test "page down jumps by viewport height" do
      items = Enum.map(1..20, &"item #{&1}")
      state = T.render(ListWidget, items: items, height: 5)
      assert state.model.selected == 0

      state = T.send_key(state, :page_down)
      assert state.model.selected == 5
    end

    test "page down clamps to last item" do
      state = T.render(ListWidget, items: @fruits, height: 3)
      state = T.send_key(state, :page_down)
      assert state.model.selected == 3

      state = T.send_key(state, :page_down)
      assert state.model.selected == 4
    end

    test "page up jumps by viewport height" do
      items = Enum.map(1..20, &"item #{&1}")
      state = T.render(ListWidget, items: items, height: 5, selected: 10)
      state = T.send_key(state, :page_up)
      assert state.model.selected == 5
    end

    test "page up clamps to first item" do
      state = T.render(ListWidget, items: @fruits, height: 3, selected: 1)
      state = T.send_key(state, :page_up)
      assert state.model.selected == 0
    end
  end

  # --- Enter / selection callback ---

  describe "enter selection" do
    test "enter emits {on_select, item} when configured" do
      state = T.render(ListWidget, items: @fruits, on_select: :picked, height: 5)
      state = T.send_key(state, :down)

      {_state, cmd} = T.send_key_raw(state, :enter)
      assert cmd == {:picked, "banana"}
    end

    test "enter emits tuple item when items are tuples" do
      items = [{"Apple", :apple}, {"Banana", :banana}]
      state = T.render(ListWidget, items: items, on_select: :picked, height: 5)
      state = T.send_key(state, :down)

      {_state, cmd} = T.send_key_raw(state, :enter)
      assert cmd == {:picked, {"Banana", :banana}}
    end

    test "enter does nothing without on_select" do
      state = T.render(ListWidget, items: @fruits, height: 5)
      {_state, cmd} = T.send_key_raw(state, :enter)
      assert cmd == nil
    end

    test "enter on empty list does nothing" do
      state = T.render(ListWidget, items: [], on_select: :picked, height: 5)
      {_state, cmd} = T.send_key_raw(state, :enter)
      assert cmd == nil
    end
  end

  # --- Empty list ---

  describe "empty list" do
    test "navigation keys don't crash on empty list" do
      state = T.render(ListWidget, items: [])

      state = T.send_key(state, :down)
      assert state.model.selected == 0

      state = T.send_key(state, :up)
      assert state.model.selected == 0

      state = T.send_key(state, :home)
      assert state.model.selected == 0

      state = T.send_key(state, :end)
      assert state.model.selected == 0

      state = T.send_key(state, :page_up)
      assert state.model.selected == 0

      state = T.send_key(state, :page_down)
      assert state.model.selected == 0
    end
  end

  # --- Items update ---

  describe "set_items/2" do
    test "replaces items" do
      model = ListWidget.init(items: @fruits)
      model = ListWidget.set_items(model, ["x", "y"])
      assert model.items == ["x", "y"]
    end

    test "clamps selected when items shrink" do
      model = ListWidget.init(items: @fruits, selected: 4)
      model = ListWidget.set_items(model, ["x", "y"])
      assert model.selected == 1
    end

    test "handles update to empty list" do
      model = ListWidget.init(items: @fruits, selected: 2)
      model = ListWidget.set_items(model, [])
      assert model.selected == 0
      assert model.items == []
    end

    test "set_items message works via update" do
      state = T.render(ListWidget, items: @fruits, selected: 4, height: 5)
      state = T.send_event(state, {:set_items, ["x", "y", "z"]})
      assert state.model.items == ["x", "y", "z"]
      assert state.model.selected == 2
    end
  end

  # --- Public API ---

  describe "select/2" do
    test "selects an item by index" do
      model = ListWidget.init(items: @fruits, height: 3)
      model = ListWidget.select(model, 3)
      assert model.selected == 3
    end

    test "clamps out-of-range index" do
      model = ListWidget.init(items: @fruits, height: 3)
      model = ListWidget.select(model, 100)
      assert model.selected == 4
    end

    test "adjusts scroll to show selected item" do
      model = ListWidget.init(items: @fruits, height: 3)
      model = ListWidget.select(model, 4)
      assert model.offset == 2
    end
  end

  describe "selected_item/1" do
    test "returns the selected item" do
      model = ListWidget.init(items: @fruits, selected: 2)
      assert ListWidget.selected_item(model) == "cherry"
    end

    test "returns nil for empty list" do
      model = ListWidget.init(items: [])
      assert ListWidget.selected_item(model) == nil
    end

    test "returns tuple item when items are tuples" do
      items = [{"Apple", :apple}, {"Banana", :banana}]
      model = ListWidget.init(items: items, selected: 1)
      assert ListWidget.selected_item(model) == {"Banana", :banana}
    end
  end

  describe "item_label/1" do
    test "returns string items as-is" do
      assert ListWidget.item_label("hello") == "hello"
    end

    test "returns label from {label, value} tuple" do
      assert ListWidget.item_label({"Hello", :world}) == "Hello"
    end
  end

  # --- Unknown events ---

  describe "unknown events" do
    test "ignores unknown key events" do
      state = T.render(ListWidget, items: @fruits, height: 5)
      state = T.send_key(state, "x")
      assert state.model.selected == 0
    end

    test "ignores non-key events" do
      state = T.render(ListWidget, items: @fruits, height: 5)
      state = T.send_event(state, :random_message)
      assert state.model.selected == 0
    end
  end
end
