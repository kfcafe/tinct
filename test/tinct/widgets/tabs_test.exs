defmodule Tinct.Widgets.TabsTest do
  use ExUnit.Case, async: true

  alias Tinct.{Element, Style, Test}
  alias Tinct.Widgets.Tabs

  doctest Tinct.Widgets.Tabs

  defp tabs_fixture do
    [
      {"Tab1", Element.text("Content 1")},
      {"Tab2", Element.text("Content 2")},
      {"Tab3", Element.text("Content 3")}
    ]
  end

  describe "view/1" do
    test "renders tab bar with all labels" do
      state = Test.render(Tabs, tabs: tabs_fixture(), size: {40, 5})

      line0 = Test.line(state, 0)
      assert is_binary(line0)
      assert line0 =~ "Tab1"
      assert line0 =~ "Tab2"
      assert line0 =~ "Tab3"
    end

    test "active tab is highlighted" do
      state = Test.render(Tabs, tabs: tabs_fixture(), active: 0, size: {40, 5})

      # The first tab is rendered as " Tab1 ", so the "T" should be at {1, 0}.
      active_cell = Test.cell_at(state, 1, 0)
      assert active_cell.char == "T"
      assert active_cell.fg == :cyan
      assert active_cell.bold == true

      # Tab2 should use the inactive style.
      # " Tab1 │ Tab2" => the "T" in Tab2 should be at column 8.
      inactive_cell = Test.cell_at(state, 8, 0)
      assert inactive_cell.char == "T"
      assert inactive_cell.fg == :bright_black
      assert inactive_cell.bold == false
    end

    test "content area shows active tab's content" do
      state = Test.render(Tabs, tabs: tabs_fixture(), active: 1, size: {40, 6})
      assert Test.contains?(state, "Content 2")
      refute Test.contains?(state, "Content 1")
    end
  end

  describe "key handling" do
    test "right arrow switches to next tab" do
      state = Test.render(Tabs, tabs: tabs_fixture(), active: 0)
      state = Test.send_key(state, :right)
      assert state.model.active == 1
      assert Test.contains?(state, "Content 2")
    end

    test "left arrow switches to previous tab" do
      state = Test.render(Tabs, tabs: tabs_fixture(), active: 1)
      state = Test.send_key(state, :left)
      assert state.model.active == 0
      assert Test.contains?(state, "Content 1")
    end

    test "wraps at boundaries (last -> first)" do
      state = Test.render(Tabs, tabs: tabs_fixture(), active: 2)
      state = Test.send_key(state, :right)
      assert state.model.active == 0
      assert Test.contains?(state, "Content 1")
    end

    test "wraps at boundaries (first -> last)" do
      state = Test.render(Tabs, tabs: tabs_fixture(), active: 0)
      state = Test.send_key(state, :left)
      assert state.model.active == 2
      assert Test.contains?(state, "Content 3")
    end

    test "number key jumps to correct tab" do
      state = Test.render(Tabs, tabs: tabs_fixture(), active: 0)
      state = Test.send_key(state, "3")
      assert state.model.active == 2
      assert Test.contains?(state, "Content 3")
    end

    test "tab key switches to next tab" do
      state = Test.render(Tabs, tabs: tabs_fixture(), active: 0)
      state = Test.send_key(state, :tab)
      assert state.model.active == 1
    end

    test "shift+tab switches to previous tab" do
      state = Test.render(Tabs, tabs: tabs_fixture(), active: 0)
      state = Test.send_key(state, :tab, [:shift])
      assert state.model.active == 2
    end

    test "on_change message emitted on tab switch" do
      state = Test.render(Tabs, tabs: tabs_fixture(), active: 0, on_change: :tab_changed)

      {_state, cmd} = Test.send_key_raw(state, :right)
      assert cmd == {:tab_changed, 1}
    end

    test "does not emit on_change when active does not change" do
      state = Test.render(Tabs, tabs: tabs_fixture(), active: 0, on_change: :tab_changed)

      {_state, cmd} = Test.send_key_raw(state, "9")
      assert cmd == nil
    end
  end

  describe "public API" do
    test "add_tab/3 appends a tab" do
      model = Tabs.init(tabs: [])
      model = Tabs.add_tab(model, "A", Element.text("a"))
      assert length(model.tabs) == 1
    end

    test "remove_tab/2 clamps active index" do
      model = Tabs.init(tabs: tabs_fixture(), active: 2)
      model = Tabs.remove_tab(model, 2)
      assert model.active == 1
    end

    test "set_active/2 clamps to valid range" do
      model = Tabs.init(tabs: tabs_fixture())
      model = Tabs.set_active(model, 99)
      assert model.active == 2
    end

    test "init/1 accepts style keyword lists" do
      model = Tabs.init(tabs: tabs_fixture(), style: [fg: :red], inactive_style: [fg: :green])
      assert %Style{} = model.style
      assert %Style{} = model.inactive_style
      assert model.style.fg == :red
      assert model.inactive_style.fg == :green
    end

    test "tab_at_x/2 maps tab bar offsets to tab indices" do
      model = Tabs.init(tabs: tabs_fixture())

      assert Tabs.tab_at_x(model, 0) == 0
      assert Tabs.tab_at_x(model, 5) == 0
      assert Tabs.tab_at_x(model, 7) == 1
      assert Tabs.tab_at_x(model, 12) == 1
      assert Tabs.tab_at_x(model, 14) == 2
      assert Tabs.tab_at_x(model, 19) == 2
    end

    test "tab_at_x/2 returns nil on separators and out-of-range positions" do
      model = Tabs.init(tabs: tabs_fixture())

      assert Tabs.tab_at_x(model, 6) == nil
      assert Tabs.tab_at_x(model, 13) == nil
      assert Tabs.tab_at_x(model, 100) == nil
      assert Tabs.tab_at_x(model, -1) == nil
    end
  end
end
