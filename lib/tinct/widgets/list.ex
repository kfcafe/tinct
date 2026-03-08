defmodule Tinct.Widgets.List do
  @moduledoc """
  A selectable, scrollable list widget.

  Implements the `Tinct.Component` behaviour. Displays a vertical list of items
  with keyboard navigation, scroll tracking, and optional selection callbacks.

  ## Init Options

    * `:items` — list of items, each a string or `{label, value}` tuple (default `[]`)
    * `:selected` — initial selected index (default `0`)
    * `:height` — visible viewport height in rows (default `10`)
    * `:style` — a `Tinct.Style.t()` for unselected items (default `Style.new()`)
    * `:selected_style` — a `Tinct.Style.t()` for the selected item
      (default `Style.new(bg: :blue, fg: :white)`)
    * `:on_select` — atom tag emitted as `{tag, item}` when Enter is pressed (default `nil`)

  ## Key Bindings

    * Up / `k` — move selection up
    * Down / `j` — move selection down
    * Home / `g` — jump to first item
    * End / `G` — jump to last item (shift+g)
    * Page Up — scroll up by viewport height
    * Page Down — scroll down by viewport height
    * Enter — emit `{on_select, selected_item}`

  ## Scrolling

  The viewport automatically scrolls to keep the selected item visible.
  When items change, the selected index is clamped to remain valid.

  ## Examples

      state = Tinct.Test.render(Tinct.Widgets.List, items: ["apple", "banana", "cherry"])
      assert Tinct.Test.contains?(state, "apple")

      state = Tinct.Test.send_key(state, :down)
      assert state.model.selected == 1
  """

  use Tinct.Component

  alias Tinct.{Element, Event, Style, View}

  defmodule Model do
    @moduledoc """
    State struct for the List widget.
    """

    @type item :: String.t() | {String.t(), term()}

    @type t :: %__MODULE__{
            items: [item()],
            selected: non_neg_integer(),
            offset: non_neg_integer(),
            height: pos_integer(),
            style: Style.t(),
            selected_style: Style.t(),
            on_select: atom() | nil
          }

    defstruct items: [],
              selected: 0,
              offset: 0,
              height: 10,
              style: %Style{},
              selected_style: %Style{},
              on_select: nil
  end

  # --- Component callbacks ---

  @impl Tinct.Component
  def init(opts) do
    items = Keyword.get(opts, :items, [])
    selected = Keyword.get(opts, :selected, 0)
    height = Keyword.get(opts, :height, 10)

    %Model{
      items: items,
      selected: clamp_index(selected, items),
      offset: 0,
      height: height,
      style: Keyword.get(opts, :style, Style.new()),
      selected_style: Keyword.get(opts, :selected_style, Style.new(bg: :blue, fg: :white)),
      on_select: Keyword.get(opts, :on_select, nil)
    }
    |> ensure_visible()
  end

  @impl Tinct.Component
  def update(%Model{} = model, %Event.Key{type: :press} = key) do
    handle_key(model, key)
  end

  def update(%Model{} = model, %Event.Mouse{type: :wheel, button: :wheel_up}) do
    move_selection(model, -1)
  end

  def update(%Model{} = model, %Event.Mouse{type: :wheel, button: :wheel_down}) do
    move_selection(model, 1)
  end

  def update(%Model{} = model, {:set_items, items}) when is_list(items) do
    set_items(model, items)
  end

  def update(%Model{} = model, _msg), do: model

  @impl Tinct.Component
  def view(%Model{} = model) do
    content = render_list(model)
    View.new(content)
  end

  # --- Public API ---

  @doc """
  Replaces the list items and clamps the selected index to remain valid.

  ## Examples

      iex> model = Tinct.Widgets.List.init(items: ["a", "b", "c"], selected: 2)
      iex> model = Tinct.Widgets.List.set_items(model, ["x", "y"])
      iex> {model.items, model.selected}
      {["x", "y"], 1}
  """
  @spec set_items(Model.t(), [Model.item()]) :: Model.t()
  def set_items(%Model{} = model, items) when is_list(items) do
    selected = clamp_index(model.selected, items)

    %{model | items: items, selected: selected}
    |> ensure_visible()
  end

  @doc """
  Programmatically selects an item by index and ensures it is visible.

  ## Examples

      iex> model = Tinct.Widgets.List.init(items: ["a", "b", "c"])
      iex> model = Tinct.Widgets.List.select(model, 2)
      iex> model.selected
      2
  """
  @spec select(Model.t(), non_neg_integer()) :: Model.t()
  def select(%Model{} = model, index) when is_integer(index) and index >= 0 do
    %{model | selected: clamp_index(index, model.items)}
    |> ensure_visible()
  end

  @doc """
  Returns the currently selected item, or `nil` for an empty list.

  ## Examples

      iex> model = Tinct.Widgets.List.init(items: ["a", "b", "c"], selected: 1)
      iex> Tinct.Widgets.List.selected_item(model)
      "b"

      iex> model = Tinct.Widgets.List.init(items: [])
      iex> Tinct.Widgets.List.selected_item(model)
      nil
  """
  @spec selected_item(Model.t()) :: Model.item() | nil
  def selected_item(%Model{items: []}), do: nil

  def selected_item(%Model{items: items, selected: selected}) do
    Enum.at(items, selected)
  end

  @doc """
  Returns the label text for an item.

  Strings are returned as-is. For `{label, _value}` tuples, the label is returned.

  ## Examples

      iex> Tinct.Widgets.List.item_label("hello")
      "hello"

      iex> Tinct.Widgets.List.item_label({"Hello", :world})
      "Hello"
  """
  @spec item_label(Model.item()) :: String.t()
  def item_label(item) when is_binary(item), do: item
  def item_label({label, _value}) when is_binary(label), do: label

  # --- Key handling ---

  defp handle_key(%Model{items: []} = model, _key), do: model

  # Up / k — move selection up
  defp handle_key(model, %Event.Key{key: :up, mod: []}) do
    move_selection(model, -1)
  end

  defp handle_key(model, %Event.Key{key: "k", mod: []}) do
    move_selection(model, -1)
  end

  # Down / j — move selection down
  defp handle_key(model, %Event.Key{key: :down, mod: []}) do
    move_selection(model, 1)
  end

  defp handle_key(model, %Event.Key{key: "j", mod: []}) do
    move_selection(model, 1)
  end

  # Home / g — jump to first item
  defp handle_key(model, %Event.Key{key: :home, mod: []}) do
    %{model | selected: 0} |> ensure_visible()
  end

  defp handle_key(model, %Event.Key{key: "g", mod: []}) do
    %{model | selected: 0} |> ensure_visible()
  end

  # End / G (shift+g) — jump to last item
  defp handle_key(model, %Event.Key{key: :end, mod: []}) do
    %{model | selected: max(0, length(model.items) - 1)} |> ensure_visible()
  end

  defp handle_key(model, %Event.Key{key: "G", mod: []}) do
    %{model | selected: max(0, length(model.items) - 1)} |> ensure_visible()
  end

  # Page Up — scroll up by viewport height
  defp handle_key(model, %Event.Key{key: :page_up, mod: []}) do
    move_selection(model, -model.height)
  end

  # Page Down — scroll down by viewport height
  defp handle_key(model, %Event.Key{key: :page_down, mod: []}) do
    move_selection(model, model.height)
  end

  # Enter — emit selection
  defp handle_key(model, %Event.Key{key: :enter, mod: []}) do
    if model.on_select do
      item = selected_item(model)
      {model, {model.on_select, item}}
    else
      model
    end
  end

  # Unknown keys — pass through
  defp handle_key(model, _key), do: model

  # --- Selection movement ---

  defp move_selection(%Model{items: items, selected: selected} = model, delta) do
    max_index = max(0, length(items) - 1)
    new_selected = selected + delta
    clamped = clamp(new_selected, 0, max_index)

    %{model | selected: clamped}
    |> ensure_visible()
  end

  # --- Scroll management ---

  defp ensure_visible(%Model{items: []} = model), do: %{model | offset: 0}

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

  defp render_list(%Model{items: []} = _model) do
    Element.text("")
  end

  defp render_list(%Model{} = model) do
    visible_items = visible_slice(model)

    children =
      Enum.map(visible_items, fn {item, index} ->
        label = item_label(item)

        if index == model.selected do
          Element.text(label, Style.to_cell_attrs(model.selected_style))
        else
          Element.text(label, Style.to_cell_attrs(model.style))
        end
      end)

    Element.column([], children)
  end

  defp visible_slice(%Model{items: items, offset: offset, height: height}) do
    items
    |> Enum.with_index()
    |> Enum.slice(offset, height)
  end

  # --- Helpers ---

  defp clamp_index(_index, []), do: 0

  defp clamp_index(index, items) do
    clamp(index, 0, length(items) - 1)
  end

  defp clamp(value, min_val, max_val) do
    value |> max(min_val) |> min(max_val)
  end
end
