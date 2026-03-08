defmodule Tinct.Widgets.AllWidgetsSmokeTest do
  use ExUnit.Case, async: true

  alias Tinct.{Element, Event, Test}

  alias Tinct.Widgets.{
    Border,
    ProgressBar,
    ScrollView,
    Spinner,
    Static,
    StatusBar,
    Table,
    Tabs,
    Text,
    TextInput
  }

  alias Tinct.Widgets.List, as: ListWidget

  describe "render smoke coverage" do
    test "every widget renders representative content" do
      widget_cases = [
        {:text, Text, [content: "hello text"], "hello text"},
        {:text_input, TextInput, [value: "input value"], "input value"},
        {:list, ListWidget, [items: ["alpha", "beta"], selected: 1], "beta"},
        {:table, Table, [columns: table_columns(), rows: table_rows(), selected: 0], "Worker A"},
        {:tabs, Tabs, [tabs: tabs_fixture(), active: 1], "Logs panel"},
        {:progress_bar, ProgressBar, [label: "Build", progress: 0.5], "50%"},
        {:spinner, Spinner, [style: :line, label: "Loading"], "Loading"},
        {:scroll_view, ScrollView, [children: scroll_children(), width: 20, height: 3], "line 1"},
        {:static, Static, [items: ["first", "second"]], "second"},
        {:status_bar, StatusBar,
         [sections: [{"Left", [align: :left]}, {"Right", [align: :right]}]], "Left"},
        {:border, Border, [title: "Panel", children: [Element.text("inside panel")]],
         "inside panel"}
      ]

      Enum.each(widget_cases, fn {widget_name, component, opts, expected_text} ->
        state = Test.render(component, opts, size: {80, 20})

        assert Test.contains?(state, expected_text),
               "#{inspect(widget_name)} did not render #{inspect(expected_text)}"
      end)
    end
  end

  describe "interaction smoke coverage" do
    test "stateful widgets handle a basic update flow" do
      list_state = Test.render(ListWidget, items: ["one", "two", "three"], selected: 0, height: 2)
      list_state = Test.send_key(list_state, :down)
      assert list_state.model.selected == 1

      list_state =
        Test.send_event(list_state, %Event.Mouse{type: :wheel, button: :wheel_down, x: 0, y: 0})

      assert list_state.model.selected == 2

      table_state =
        Test.render(Table, columns: table_columns(), rows: table_rows(), selected: 0, height: 1)

      table_state = Test.send_key(table_state, :down)
      assert table_state.model.selected == 1

      table_state =
        Test.send_event(table_state, %Event.Mouse{type: :wheel, button: :wheel_up, x: 0, y: 0})

      assert table_state.model.selected == 0

      tabs_state = Test.render(Tabs, tabs: tabs_fixture(), active: 0)
      tabs_state = Test.send_key(tabs_state, :right)
      assert tabs_state.model.active == 1
      assert Test.contains?(tabs_state, "Logs panel")

      input_state = Test.render(TextInput, value: "ab")
      input_state = Test.send_key(input_state, :left)
      input_state = Test.send_key(input_state, "X")
      assert input_state.model.value == "aXb"

      scroll_state = Test.render(ScrollView, children: scroll_children(), width: 20, height: 3)
      scroll_state = Test.send_key(scroll_state, :page_down)
      previous_offset = scroll_state.model.offset_y
      assert previous_offset > 0

      scroll_state =
        Test.send_event(scroll_state, %Event.Mouse{type: :wheel, button: :wheel_up, x: 0, y: 0})

      assert scroll_state.model.offset_y == previous_offset - 1

      progress_model = ProgressBar.init(progress: 0.1)
      progress_model = ProgressBar.update(progress_model, {:increment, 0.5})
      assert_in_delta progress_model.progress, 0.6, 1.0e-12

      spinner_model = Spinner.init(style: :line)
      spinner_model = Spinner.handle_tick(spinner_model)
      assert spinner_model.frame == 1

      static_model = Static.init(items: [])
      static_model = Static.update(static_model, {:add_item, "done"})
      assert Static.new_items(static_model) == ["done"]

      status_model = StatusBar.init(sections: [{"left", [align: :left]}])
      status_model = StatusBar.update(status_model, {:set_section, 0, {"ready", [align: :right]}})
      assert status_model.sections == [{"ready", [align: :right]}]

      text_model = Text.init(content: "before")
      text_model = Text.update(text_model, {:set_content, "after"})
      assert text_model.content == "after"

      border_model = Border.init(title: "Box")
      assert Border.update(border_model, :noop) == border_model
    end
  end

  defp table_columns do
    [
      %{header: "Name", width: :auto, key: :name},
      %{header: "State", width: :auto, key: :state}
    ]
  end

  defp table_rows do
    [
      %{name: "Worker A", state: "ready"},
      %{name: "Worker B", state: "busy"}
    ]
  end

  defp tabs_fixture do
    [
      {"Overview", Element.text("Overview panel")},
      {"Logs", Element.text("Logs panel")}
    ]
  end

  defp scroll_children do
    Enum.map(1..8, fn index ->
      Element.text("line #{index}")
    end)
  end
end
