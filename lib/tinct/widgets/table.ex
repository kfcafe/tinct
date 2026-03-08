defmodule Tinct.Widgets.Table do
  @moduledoc """
  A data table widget with columns, selection, and scrolling.

  Implements the `Tinct.Component` behaviour. Displays a tabular data view
  with configurable columns, keyboard navigation, scroll tracking, and
  optional selection callbacks.

  ## Init Options

    * `:columns` — list of column maps, each with `:header`, `:width`, and `:key`
    * `:rows` — list of maps or keyword lists representing row data
    * `:selected` — initial selected row index (default `nil`)
    * `:height` — visible data rows in viewport (default `10`)
    * `:selectable` — enable row selection (default `true`)
    * `:show_header` — show header row and separator (default `true`)
    * `:sort_by` — column key to sort by (default `nil`)
    * `:sort_dir` — sort direction, `:asc` or `:desc` (default `:asc`)
    * `:on_select` — atom tag emitted as `{tag, row}` when Enter is pressed (default `nil`)
    * `:style` — a `Tinct.Style.t()` for unselected rows (default `Style.new()`)
    * `:selected_style` — a `Tinct.Style.t()` for the selected row
      (default `Style.new(bg: :blue, fg: :white)`)

  ## Column Definition

  Each column is a map with:

    * `:header` — column header text (string)
    * `:width` — `:auto` (fit content) or a positive integer (fixed width)
    * `:key` — atom key to extract cell value from row data

  When `:width` is `:auto`, the column width is the maximum of the header
  length and the longest cell value in that column.

  When `:width` is a fixed integer, cell values longer than the width are
  truncated.

  ## Rendering

  The table renders with box-drawing characters:

  ```
   Name         │ Size    │ Modified
  ──────────────┼─────────┼──────────────
   README.md    │ 2.4 KB  │ 2024-01-15
   src/main.rs  │ 8.1 KB  │ 2024-01-14
  ```

  ## Key Bindings

    * Up — move selection up
    * Down — move selection down
    * Enter — emit `{on_select, row}`
    * Home — jump to first row
    * End — jump to last row

  ## Examples

      columns = [
        %{header: "Name", width: :auto, key: :name},
        %{header: "Size", width: 8, key: :size}
      ]
      rows = [
        %{name: "README.md", size: "2.4 KB"},
        %{name: "src/main.rs", size: "8.1 KB"}
      ]
      state = Tinct.Test.render(Tinct.Widgets.Table, columns: columns, rows: rows)
      assert Tinct.Test.contains?(state, "README.md")
  """

  use Tinct.Component

  alias Tinct.{Element, Event, Style, View}

  defmodule Model do
    @moduledoc """
    State struct for the Table widget.
    """

    @type t :: %__MODULE__{
            columns: [map()],
            rows: [map() | keyword()],
            selected: non_neg_integer() | nil,
            offset: non_neg_integer(),
            sort_by: atom() | nil,
            sort_dir: :asc | :desc,
            selectable: boolean(),
            show_header: boolean(),
            on_select: atom() | nil,
            height: pos_integer(),
            style: Style.t(),
            selected_style: Style.t()
          }

    defstruct columns: [],
              rows: [],
              selected: nil,
              offset: 0,
              sort_by: nil,
              sort_dir: :asc,
              selectable: true,
              show_header: true,
              on_select: nil,
              height: 10,
              style: %Style{},
              selected_style: %Style{}
  end

  # --- Component callbacks ---

  @impl Tinct.Component
  def init(opts) do
    %Model{
      columns: Keyword.get(opts, :columns, []),
      rows: Keyword.get(opts, :rows, []),
      selected: Keyword.get(opts, :selected, nil),
      offset: 0,
      sort_by: Keyword.get(opts, :sort_by, nil),
      sort_dir: Keyword.get(opts, :sort_dir, :asc),
      selectable: Keyword.get(opts, :selectable, true),
      show_header: Keyword.get(opts, :show_header, true),
      on_select: Keyword.get(opts, :on_select, nil),
      height: Keyword.get(opts, :height, 10),
      style: Keyword.get(opts, :style, Style.new()),
      selected_style: Keyword.get(opts, :selected_style, Style.new(bg: :blue, fg: :white))
    }
    |> clamp_selected()
    |> ensure_visible()
  end

  @impl Tinct.Component
  def update(%Model{} = model, %Event.Key{type: :press} = key) do
    handle_key(model, key)
  end

  def update(%Model{rows: []} = model, %Event.Mouse{type: :wheel}), do: model
  def update(%Model{selectable: false} = model, %Event.Mouse{type: :wheel}), do: model

  def update(%Model{} = model, %Event.Mouse{type: :wheel, button: :wheel_up}) do
    move_selection(model, -1)
  end

  def update(%Model{} = model, %Event.Mouse{type: :wheel, button: :wheel_down}) do
    move_selection(model, 1)
  end

  def update(%Model{} = model, {:set_rows, rows}) when is_list(rows) do
    set_rows(model, rows)
  end

  def update(%Model{} = model, _msg), do: model

  @impl Tinct.Component
  def view(%Model{} = model) do
    content = render_table(model)
    View.new(content)
  end

  # --- Public API ---

  @doc """
  Replaces the table rows and clamps the selected index to remain valid.

  ## Examples

      iex> model = Tinct.Widgets.Table.init(columns: [%{header: "X", width: :auto, key: :x}], rows: [%{x: 1}, %{x: 2}], selected: 1)
      iex> model = Tinct.Widgets.Table.set_rows(model, [%{x: 10}])
      iex> {length(model.rows), model.selected}
      {1, 0}
  """
  @spec set_rows(Model.t(), [map() | keyword()]) :: Model.t()
  def set_rows(%Model{} = model, rows) when is_list(rows) do
    %{model | rows: rows}
    |> clamp_selected()
    |> ensure_visible()
  end

  @doc """
  Programmatically selects a row by index and ensures it is visible.

  If the table is not selectable or has no rows, selection becomes `nil`.

  ## Examples

      iex> model = Tinct.Widgets.Table.init(columns: [%{header: "X", width: :auto, key: :x}], rows: [%{x: 1}, %{x: 2}])
      iex> model = Tinct.Widgets.Table.select(model, 1)
      iex> model.selected
      1
  """
  @spec select(Model.t(), non_neg_integer()) :: Model.t()
  def select(%Model{} = model, index) when is_integer(index) and index >= 0 do
    %{model | selected: index}
    |> clamp_selected()
    |> ensure_visible()
  end

  @doc """
  Returns the currently selected row, or `nil` if no row is selected.

  ## Examples

      iex> model = Tinct.Widgets.Table.init(columns: [%{header: "X", width: :auto, key: :x}], rows: [%{x: 1}, %{x: 2}], selected: 1)
      iex> Tinct.Widgets.Table.selected_row(model)
      %{x: 2}

      iex> model = Tinct.Widgets.Table.init(columns: [], rows: [])
      iex> Tinct.Widgets.Table.selected_row(model)
      nil
  """
  @spec selected_row(Model.t()) :: map() | keyword() | nil
  def selected_row(%Model{selected: nil}), do: nil
  def selected_row(%Model{rows: rows, selected: idx}), do: Enum.at(rows, idx)

  @doc """
  Extracts the display text for a cell value from a row.

  Looks up the value by key and converts it to a string. Returns an empty
  string if the key is not present.

  ## Examples

      iex> Tinct.Widgets.Table.cell_text(%{name: "hello"}, :name)
      "hello"

      iex> Tinct.Widgets.Table.cell_text([name: "hello"], :name)
      "hello"

      iex> Tinct.Widgets.Table.cell_text(%{}, :missing)
      ""
  """
  @spec cell_text(map() | keyword(), atom()) :: String.t()
  def cell_text(row, key) when is_map(row) do
    row |> Map.get(key, "") |> to_string()
  end

  def cell_text(row, key) when is_list(row) do
    row |> Keyword.get(key, "") |> to_string()
  end

  # --- Key handling ---

  defp handle_key(%Model{rows: []} = model, _key), do: model
  defp handle_key(%Model{selectable: false} = model, _key), do: model

  defp handle_key(model, %Event.Key{key: :down, mod: []}) do
    move_selection(model, 1)
  end

  defp handle_key(model, %Event.Key{key: :up, mod: []}) do
    move_selection(model, -1)
  end

  defp handle_key(model, %Event.Key{key: :home, mod: []}) do
    %{model | selected: 0} |> ensure_visible()
  end

  defp handle_key(model, %Event.Key{key: :end, mod: []}) do
    %{model | selected: max(0, length(model.rows) - 1)} |> ensure_visible()
  end

  defp handle_key(model, %Event.Key{key: :enter, mod: []}) do
    if model.on_select && model.selected != nil do
      row = selected_row(model)
      {model, {model.on_select, row}}
    else
      model
    end
  end

  defp handle_key(model, _key), do: model

  # --- Selection movement ---

  defp move_selection(%Model{selected: nil} = model, _delta) do
    %{model | selected: 0} |> ensure_visible()
  end

  defp move_selection(%Model{rows: rows, selected: selected} = model, delta) do
    max_index = max(0, length(rows) - 1)
    new_selected = clamp(selected + delta, 0, max_index)
    %{model | selected: new_selected} |> ensure_visible()
  end

  # --- Scroll management ---

  defp ensure_visible(%Model{selected: nil} = model), do: model
  defp ensure_visible(%Model{rows: []} = model), do: %{model | offset: 0}

  defp ensure_visible(%Model{selected: selected, offset: offset, height: height} = model) do
    cond do
      selected < offset ->
        %{model | offset: selected}

      selected >= offset + height ->
        %{model | offset: selected - height + 1}

      true ->
        model
    end
  end

  # --- Rendering ---

  defp render_table(%Model{columns: []} = _model) do
    Element.text("")
  end

  defp render_table(%Model{} = model) do
    widths = calculate_widths(model.columns, model.rows)

    header_elements =
      if model.show_header do
        header_line = format_row_text(model.columns, widths, &(&1[:header] || ""))
        separator = format_separator(widths)
        [Element.text(header_line), Element.text(separator)]
      else
        []
      end

    row_elements =
      model
      |> visible_slice()
      |> Enum.map(fn {row, index} ->
        line = format_row_text(model.columns, widths, &cell_text(row, &1[:key]))

        if index == model.selected do
          Element.text(line, Style.to_cell_attrs(model.selected_style))
        else
          Element.text(line, Style.to_cell_attrs(model.style))
        end
      end)

    case header_elements ++ row_elements do
      [] -> Element.text("")
      children -> Element.column([], children)
    end
  end

  defp calculate_widths(columns, rows) do
    Enum.map(columns, &column_width(&1, rows))
  end

  defp column_width(col, rows) do
    case col[:width] do
      :auto ->
        auto_column_width(col, rows)

      width when is_integer(width) ->
        width
    end
  end

  defp auto_column_width(col, rows) do
    header_width = String.length(col[:header] || "")

    max_cell_width =
      Enum.reduce(rows, 0, fn row, acc ->
        len = row |> cell_text(col[:key]) |> String.length()
        max(len, acc)
      end)

    max(header_width, max_cell_width)
  end

  defp format_row_text(columns, widths, value_fn) do
    columns
    |> Enum.zip(widths)
    |> Enum.map_join("│", fn {col, width} ->
      text = value_fn.(col)
      padded = text |> truncate(width) |> String.pad_trailing(width)
      " #{padded} "
    end)
  end

  defp format_separator(widths) do
    Enum.map_join(widths, "┼", fn width ->
      String.duplicate("─", width + 2)
    end)
  end

  defp truncate(text, max_width) when is_binary(text) and is_integer(max_width) do
    if String.length(text) > max_width do
      String.slice(text, 0, max_width)
    else
      text
    end
  end

  defp visible_slice(%Model{rows: rows, offset: offset, height: height}) do
    rows
    |> Enum.with_index()
    |> Enum.slice(offset, height)
  end

  # --- Helpers ---

  defp clamp_selected(%Model{rows: []} = model) do
    %{model | selected: nil}
  end

  defp clamp_selected(%Model{selectable: false} = model) do
    %{model | selected: nil}
  end

  defp clamp_selected(%Model{selected: nil} = model), do: model

  defp clamp_selected(%Model{rows: rows, selected: idx} = model) do
    %{model | selected: clamp(idx, 0, length(rows) - 1)}
  end

  defp clamp(value, min_val, max_val) do
    value |> max(min_val) |> min(max_val)
  end
end
