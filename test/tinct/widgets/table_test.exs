defmodule Tinct.Widgets.TableTest do
  use ExUnit.Case, async: true

  alias Tinct.Event
  alias Tinct.Test, as: T
  alias Tinct.Widgets.Table

  doctest Tinct.Widgets.Table

  @columns [
    %{header: "Name", width: :auto, key: :name},
    %{header: "Size", width: :auto, key: :size}
  ]

  @rows [
    %{name: "README.md", size: "2.4 KB"},
    %{name: "src/main.rs", size: "8.1 KB"},
    %{name: "Cargo.toml", size: "1.2 KB"}
  ]

  # --- init ---

  describe "init/1" do
    test "defaults to empty columns and rows" do
      model = Table.init([])
      assert model.columns == []
      assert model.rows == []
      assert model.selected == nil
      assert model.offset == 0
    end

    test "initializes with columns and rows" do
      model = Table.init(columns: @columns, rows: @rows)
      assert model.columns == @columns
      assert model.rows == @rows
    end

    test "respects initial selected index" do
      model = Table.init(columns: @columns, rows: @rows, selected: 1)
      assert model.selected == 1
    end

    test "clamps selected index to valid range" do
      model = Table.init(columns: @columns, rows: @rows, selected: 100)
      assert model.selected == 2
    end

    test "selected is nil for empty rows even if provided" do
      model = Table.init(columns: @columns, rows: [], selected: 5)
      assert model.selected == nil
    end

    test "selected is nil when not selectable" do
      model = Table.init(columns: @columns, rows: @rows, selectable: false, selected: 1)
      assert model.selected == nil
    end

    test "sets on_select callback tag" do
      model = Table.init(columns: @columns, rows: @rows, on_select: :picked)
      assert model.on_select == :picked
    end

    test "sets height" do
      model = Table.init(columns: @columns, rows: @rows, height: 5)
      assert model.height == 5
    end
  end

  # --- Rendering: header and rows ---

  describe "rendering header and rows" do
    test "renders column headers" do
      state = T.render(Table, columns: @columns, rows: @rows, size: {60, 10})
      assert T.contains?(state, "Name")
      assert T.contains?(state, "Size")
    end

    test "renders row data" do
      state = T.render(Table, columns: @columns, rows: @rows, size: {60, 10})
      assert T.contains?(state, "README.md")
      assert T.contains?(state, "src/main.rs")
      assert T.contains?(state, "Cargo.toml")
      assert T.contains?(state, "2.4 KB")
      assert T.contains?(state, "8.1 KB")
    end

    test "renders column dividers" do
      state = T.render(Table, columns: @columns, rows: @rows, size: {60, 10})
      assert T.contains?(state, "│")
    end

    test "renders separator row with box-drawing characters" do
      state = T.render(Table, columns: @columns, rows: @rows, size: {60, 10})
      assert T.contains?(state, "─")
      assert T.contains?(state, "┼")
    end

    test "empty table renders header only" do
      state = T.render(Table, columns: @columns, rows: [], size: {60, 10})
      assert T.contains?(state, "Name")
      assert T.contains?(state, "Size")
      assert T.contains?(state, "─")
      refute T.contains?(state, "README.md")
    end

    test "header is on line 0, separator on line 1, data starts on line 2" do
      state = T.render(Table, columns: @columns, rows: @rows, size: {60, 10})
      header_line = T.line(state, 0)
      separator_line = T.line(state, 1)
      first_data_line = T.line(state, 2)

      assert header_line =~ "Name"
      assert header_line =~ "│"
      assert separator_line =~ "─"
      assert separator_line =~ "┼"
      assert first_data_line =~ "README.md"
    end

    test "hides header when show_header is false" do
      state =
        T.render(Table,
          columns: @columns,
          rows: @rows,
          show_header: false,
          size: {60, 10}
        )

      first_line = T.line(state, 0)
      assert first_line =~ "README.md"
      refute T.contains?(state, "┼")
    end

    test "renders with no columns as empty" do
      state = T.render(Table, columns: [], rows: @rows, size: {60, 10})
      assert %Tinct.Test.State{} = state
    end

    test "handles keyword list rows" do
      rows = [[name: "file.txt", size: "1 KB"], [name: "other.txt", size: "2 KB"]]
      state = T.render(Table, columns: @columns, rows: rows, size: {60, 10})
      assert T.contains?(state, "file.txt")
      assert T.contains?(state, "other.txt")
    end

    test "handles missing keys in rows gracefully" do
      columns = [%{header: "Name", width: :auto, key: :name}]
      rows = [%{other: "value"}]
      state = T.render(Table, columns: columns, rows: rows, size: {60, 10})
      assert T.contains?(state, "Name")
    end
  end

  # --- Column width ---

  describe "column width" do
    test "auto width uses max of header and content width" do
      columns = [%{header: "X", width: :auto, key: :val}]
      rows = [%{val: "hello"}, %{val: "hi"}]
      state = T.render(Table, columns: columns, rows: rows, size: {40, 10})

      # Auto width = max("X"=1, "hello"=5, "hi"=2) = 5
      # Header "X" should be padded to 5 chars
      header_line = T.line(state, 0)
      # " X     " — X followed by spaces to fill width 5
      assert header_line =~ "X"
      assert T.contains?(state, "hello")
    end

    test "auto width from header when header is wider than content" do
      columns = [%{header: "Very Long Header", width: :auto, key: :val}]
      rows = [%{val: "hi"}]
      state = T.render(Table, columns: columns, rows: rows, size: {40, 10})

      assert T.contains?(state, "Very Long Header")
      assert T.contains?(state, "hi")
    end

    test "fixed column width truncates long content" do
      columns = [%{header: "Name", width: 4, key: :name}]
      rows = [%{name: "very long name"}]
      state = T.render(Table, columns: columns, rows: rows, size: {40, 10})

      assert T.contains?(state, "very")
      refute T.contains?(state, "very long")
    end

    test "fixed column width also truncates header" do
      columns = [%{header: "Long Header", width: 4, key: :name}]
      rows = [%{name: "hi"}]
      state = T.render(Table, columns: columns, rows: rows, size: {40, 10})

      assert T.contains?(state, "Long")
      refute T.contains?(state, "Long Header")
    end
  end

  # --- Selection highlight ---

  describe "selection highlight" do
    test "selected row has different style than unselected" do
      state =
        T.render(Table,
          columns: @columns,
          rows: @rows,
          selected: 0,
          size: {60, 10}
        )

      # Row 0 is selected → rendered on line 2 (after header + separator)
      selected_cell = T.cell_at(state, 1, 2)
      # Unselected row → line 3
      unselected_cell = T.cell_at(state, 1, 3)

      assert selected_cell.bg == :blue
      assert selected_cell.fg == :white
      assert unselected_cell.bg != :blue
    end
  end

  # --- Key handling: Down ---

  describe "down navigation" do
    test "down arrow selects first row when selected is nil" do
      state = T.render(Table, columns: @columns, rows: @rows, height: 5)
      assert state.model.selected == nil

      state = T.send_key(state, :down)
      assert state.model.selected == 0
    end

    test "down arrow moves selection down" do
      state = T.render(Table, columns: @columns, rows: @rows, height: 5, selected: 0)
      state = T.send_key(state, :down)
      assert state.model.selected == 1

      state = T.send_key(state, :down)
      assert state.model.selected == 2
    end

    test "down stops at last row" do
      state = T.render(Table, columns: @columns, rows: @rows, height: 5, selected: 2)
      state = T.send_key(state, :down)
      assert state.model.selected == 2
    end
  end

  # --- Key handling: Up ---

  describe "up navigation" do
    test "up arrow selects first row when selected is nil" do
      state = T.render(Table, columns: @columns, rows: @rows, height: 5)
      assert state.model.selected == nil

      state = T.send_key(state, :up)
      assert state.model.selected == 0
    end

    test "up arrow moves selection up" do
      state = T.render(Table, columns: @columns, rows: @rows, height: 5, selected: 2)
      state = T.send_key(state, :up)
      assert state.model.selected == 1
    end

    test "up stops at first row" do
      state = T.render(Table, columns: @columns, rows: @rows, height: 5, selected: 0)
      state = T.send_key(state, :up)
      assert state.model.selected == 0
    end
  end

  # --- Mouse wheel navigation ---

  describe "mouse wheel navigation" do
    test "wheel down moves selection down" do
      state = T.render(Table, columns: @columns, rows: @rows, selected: 0)

      state =
        T.send_event(state, %Event.Mouse{type: :wheel, button: :wheel_down, x: 0, y: 0})

      assert state.model.selected == 1
    end

    test "wheel up moves selection up" do
      state = T.render(Table, columns: @columns, rows: @rows, selected: 2)
      state = T.send_event(state, %Event.Mouse{type: :wheel, button: :wheel_up, x: 0, y: 0})
      assert state.model.selected == 1
    end

    test "wheel events are ignored when table is not selectable" do
      state = T.render(Table, columns: @columns, rows: @rows, selectable: false)
      state = T.send_event(state, %Event.Mouse{type: :wheel, button: :wheel_down, x: 0, y: 0})
      assert state.model.selected == nil
    end
  end

  # --- Key handling: Home/End ---

  describe "home/end navigation" do
    test "home jumps to first row" do
      state = T.render(Table, columns: @columns, rows: @rows, height: 5, selected: 2)
      state = T.send_key(state, :home)
      assert state.model.selected == 0
    end

    test "end jumps to last row" do
      state = T.render(Table, columns: @columns, rows: @rows, height: 5, selected: 0)
      state = T.send_key(state, :end)
      assert state.model.selected == 2
    end
  end

  # --- Scrolling ---

  describe "scrolling" do
    test "scrolls down when selection moves below viewport" do
      rows = Enum.map(1..10, &%{name: "file_#{&1}", size: "#{&1} KB"})

      state =
        T.render(Table, columns: @columns, rows: rows, height: 3, selected: 0)

      assert state.model.offset == 0

      state = state |> T.send_key(:down) |> T.send_key(:down) |> T.send_key(:down)
      assert state.model.selected == 3
      assert state.model.offset == 1
    end

    test "scrolls up when selection moves above viewport" do
      rows = Enum.map(1..10, &%{name: "file_#{&1}", size: "#{&1} KB"})

      state =
        T.render(Table, columns: @columns, rows: rows, height: 3, selected: 5)

      state = state |> T.send_key(:up) |> T.send_key(:up) |> T.send_key(:up)
      assert state.model.selected == 2
      assert state.model.offset == 2
    end

    test "home scrolls back to top" do
      rows = Enum.map(1..10, &%{name: "file_#{&1}", size: "#{&1} KB"})

      state =
        T.render(Table, columns: @columns, rows: rows, height: 3, selected: 8)

      assert state.model.offset > 0

      state = T.send_key(state, :home)
      assert state.model.selected == 0
      assert state.model.offset == 0
    end

    test "end scrolls to bottom" do
      rows = Enum.map(1..10, &%{name: "file_#{&1}", size: "#{&1} KB"})

      state =
        T.render(Table, columns: @columns, rows: rows, height: 3, selected: 0)

      state = T.send_key(state, :end)
      assert state.model.selected == 9
      assert state.model.offset == 7
    end
  end

  # --- Enter / selection callback ---

  describe "enter selection" do
    test "enter emits {on_select, row} when configured" do
      state =
        T.render(Table,
          columns: @columns,
          rows: @rows,
          on_select: :picked,
          selected: 1
        )

      {_state, cmd} = T.send_key_raw(state, :enter)
      assert cmd == {:picked, %{name: "src/main.rs", size: "8.1 KB"}}
    end

    test "enter does nothing without on_select" do
      state = T.render(Table, columns: @columns, rows: @rows, selected: 1)
      {_state, cmd} = T.send_key_raw(state, :enter)
      assert cmd == nil
    end

    test "enter does nothing when selected is nil" do
      state = T.render(Table, columns: @columns, rows: @rows, on_select: :picked)
      assert state.model.selected == nil

      {_state, cmd} = T.send_key_raw(state, :enter)
      assert cmd == nil
    end

    test "enter on empty table does nothing" do
      state = T.render(Table, columns: @columns, rows: [], on_select: :picked)
      {_state, cmd} = T.send_key_raw(state, :enter)
      assert cmd == nil
    end
  end

  # --- Empty table ---

  describe "empty table" do
    test "navigation keys don't crash on empty table" do
      state = T.render(Table, columns: @columns, rows: [])
      assert state.model.selected == nil

      state = T.send_key(state, :down)
      assert state.model.selected == nil

      state = T.send_key(state, :up)
      assert state.model.selected == nil

      state = T.send_key(state, :home)
      assert state.model.selected == nil

      state = T.send_key(state, :end)
      assert state.model.selected == nil
    end
  end

  # --- Rows update ---

  describe "set_rows/2" do
    test "replaces rows" do
      model = Table.init(columns: @columns, rows: @rows)
      new_rows = [%{name: "x", size: "1 KB"}]
      model = Table.set_rows(model, new_rows)
      assert model.rows == new_rows
    end

    test "clamps selected when rows shrink" do
      model = Table.init(columns: @columns, rows: @rows, selected: 2)
      model = Table.set_rows(model, [%{name: "x", size: "1 KB"}])
      assert model.selected == 0
    end

    test "sets selected to nil when rows become empty" do
      model = Table.init(columns: @columns, rows: @rows, selected: 1)
      model = Table.set_rows(model, [])
      assert model.selected == nil
    end

    test "set_rows message works via update" do
      state = T.render(Table, columns: @columns, rows: @rows, selected: 2, height: 5)
      new_rows = [%{name: "x", size: "1 KB"}, %{name: "y", size: "2 KB"}]
      state = T.send_event(state, {:set_rows, new_rows})
      assert state.model.rows == new_rows
      assert state.model.selected == 1
    end
  end

  # --- Public API ---

  describe "select/2" do
    test "selects a row by index" do
      model = Table.init(columns: @columns, rows: @rows)
      model = Table.select(model, 2)
      assert model.selected == 2
    end

    test "clamps out-of-range index" do
      model = Table.init(columns: @columns, rows: @rows)
      model = Table.select(model, 99)
      assert model.selected == 2
    end

    test "returns nil selection when table is not selectable" do
      model = Table.init(columns: @columns, rows: @rows, selectable: false)
      model = Table.select(model, 1)
      assert model.selected == nil
    end
  end

  describe "selected_row/1" do
    test "returns the selected row" do
      model = Table.init(columns: @columns, rows: @rows, selected: 1)
      assert Table.selected_row(model) == %{name: "src/main.rs", size: "8.1 KB"}
    end

    test "returns nil when selected is nil" do
      model = Table.init(columns: @columns, rows: @rows)
      assert Table.selected_row(model) == nil
    end

    test "returns nil for empty rows" do
      model = Table.init(columns: @columns, rows: [])
      assert Table.selected_row(model) == nil
    end
  end

  describe "cell_text/2" do
    test "extracts string value from map row" do
      assert Table.cell_text(%{name: "hello"}, :name) == "hello"
    end

    test "extracts value from keyword list row" do
      assert Table.cell_text([name: "hello"], :name) == "hello"
    end

    test "converts non-string values to string" do
      assert Table.cell_text(%{count: 42}, :count) == "42"
    end

    test "returns empty string for missing key" do
      assert Table.cell_text(%{}, :missing) == ""
    end
  end

  # --- Unknown events ---

  describe "unknown events" do
    test "ignores unknown key events" do
      state = T.render(Table, columns: @columns, rows: @rows, height: 5, selected: 0)
      state = T.send_key(state, "x")
      assert state.model.selected == 0
    end

    test "ignores non-key events" do
      state = T.render(Table, columns: @columns, rows: @rows, height: 5, selected: 0)
      state = T.send_event(state, :random_message)
      assert state.model.selected == 0
    end
  end
end
