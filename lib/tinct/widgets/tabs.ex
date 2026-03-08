defmodule Tinct.Widgets.Tabs do
  @moduledoc """
  A tabbed interface widget for switching between multiple panels.

  The widget renders a tab bar at the top and shows the active tab's content
  below it.

  ## Init options

    * `:tabs` - list of `{label, content_element}` tuples (default: `[]`)
    * `:active` - active tab index (default: `0`)
    * `:style` - base style applied to the widget (default: `Style.new()`)
    * `:active_style` - style overrides for the active tab label
      (default: `Style.new(bold: true, fg: :cyan)`)
    * `:inactive_style` - style overrides for inactive tab labels
      (default: `Style.new(fg: :bright_black)`)
    * `:on_change` - atom tag emitted as `{tag, active_index}` when the active tab changes
      (default: `nil`)

  ## Key bindings

    * Left / Shift+Tab - previous tab (wraps)
    * Right / Tab - next tab (wraps)
    * Number keys 1-9 - jump to tab by index

  ## Examples

      iex> alias Tinct.{Element, Widgets.Tabs}
      iex> tabs = [{"One", Element.text("first")}, {"Two", Element.text("second")}]
      iex> model = Tabs.init(tabs: tabs, active: 1)
      iex> model.active
      1
      iex> model = Tabs.set_active(model, 0)
      iex> model.active
      0
  """

  use Tinct.Component

  alias Tinct.{Element, Event, Style, View}

  @typedoc "A single tab: label and the content element shown when active."
  @type tab :: {String.t(), Element.t()}

  defmodule Model do
    @moduledoc "State struct for the Tabs widget."

    @type t :: %__MODULE__{
            tabs: [Tinct.Widgets.Tabs.tab()],
            active: non_neg_integer(),
            style: Style.t(),
            active_style: Style.t(),
            inactive_style: Style.t(),
            on_change: atom() | nil
          }

    defstruct tabs: [],
              active: 0,
              style: %Style{},
              active_style: %Style{bold: true, fg: :cyan},
              inactive_style: %Style{fg: :bright_black},
              on_change: nil
  end

  # --- Component callbacks ---

  @doc "Initializes the tabs widget from options."
  @impl true
  @spec init(keyword()) :: Model.t()
  def init(opts) when is_list(opts) do
    tabs = opts |> Keyword.get(:tabs, []) |> normalize_tabs()

    %Model{
      tabs: tabs,
      active: opts |> Keyword.get(:active, 0) |> clamp_index(tabs),
      style: opts |> Keyword.get(:style, Style.new()) |> normalize_style(),
      active_style:
        opts |> Keyword.get(:active_style, Style.new(bold: true, fg: :cyan)) |> normalize_style(),
      inactive_style:
        opts |> Keyword.get(:inactive_style, Style.new(fg: :bright_black)) |> normalize_style(),
      on_change: Keyword.get(opts, :on_change, nil)
    }
  end

  @doc "Updates the tabs model. Key events change the active tab."
  @impl true
  @spec update(Model.t(), term()) :: Model.t() | {Model.t(), term()}
  def update(%Model{} = model, %Event.Key{type: :press} = key) do
    handle_key(model, key)
  end

  def update(%Model{} = model, {:add_tab, label, %Element{} = content}) do
    new_model = add_tab(model, label, content)
    maybe_emit_on_change(new_model, model)
  end

  def update(%Model{} = model, {:remove_tab, index}) when is_integer(index) and index >= 0 do
    new_model = remove_tab(model, index)
    maybe_emit_on_change(new_model, model)
  end

  def update(%Model{} = model, {:set_active, index}) when is_integer(index) and index >= 0 do
    new_model = set_active(model, index)
    maybe_emit_on_change(new_model, model)
  end

  def update(%Model{} = model, _msg), do: model

  @doc "Renders the tab bar and the active tab content."
  @impl true
  @spec view(Model.t()) :: View.t()
  def view(%Model{} = model) do
    View.new(render(model))
  end

  # --- Public API ---

  @doc """
  Adds a tab to the end of the tab list.

  This function does not emit `on_change` messages; emission is handled by `update/2`.

  ## Examples

      iex> alias Tinct.{Element, Widgets.Tabs}
      iex> model = Tabs.init([])
      iex> model = Tabs.add_tab(model, "A", Element.text("a"))
      iex> length(model.tabs)
      1
  """
  @spec add_tab(Model.t(), String.t(), Element.t()) :: Model.t()
  def add_tab(%Model{} = model, label, %Element{} = content) do
    tabs = model.tabs ++ [{to_string(label), content}]

    # If this is the first tab, active should remain 0.
    %{model | tabs: tabs, active: clamp_index(model.active, tabs)}
  end

  @doc """
  Removes a tab by index.

  If `index` is out of range, returns the model unchanged.

  This function does not emit `on_change` messages; emission is handled by `update/2`.
  """
  @spec remove_tab(Model.t(), non_neg_integer()) :: Model.t()
  def remove_tab(%Model{} = model, index) when is_integer(index) and index >= 0 do
    if index < length(model.tabs) do
      new_tabs = List.delete_at(model.tabs, index)
      new_active = adjust_active_after_remove(model.active, index, new_tabs)
      %{model | tabs: new_tabs, active: new_active}
    else
      model
    end
  end

  @doc """
  Sets the active tab by index.

  Index is clamped into the valid range.

  This function does not emit `on_change` messages; emission is handled by `update/2`.
  """
  @spec set_active(Model.t(), non_neg_integer()) :: Model.t()
  def set_active(%Model{} = model, index) when is_integer(index) and index >= 0 do
    %{model | active: clamp_index(index, model.tabs)}
  end

  @doc """
  Returns the tab index at a horizontal offset on the tab bar, or `nil`.

  `x` is zero-based within the rendered tab bar row (before any outer container
  offsets are applied).

  This is useful for mouse click hit-testing in composed layouts.
  """
  @spec tab_at_x(Model.t(), integer()) :: non_neg_integer() | nil
  def tab_at_x(%Model{} = model, x) when is_integer(x) and x >= 0 do
    do_tab_at_x(model.tabs, x, 0, 0)
  end

  def tab_at_x(%Model{}, _x), do: nil

  # --- Key handling ---

  defp handle_key(%Model{tabs: []} = model, _key), do: model

  # Left arrow / Shift+Tab - previous tab
  defp handle_key(%Model{} = model, %Event.Key{key: :left, mod: []}) do
    switch_active(model, prev_index(model))
  end

  defp handle_key(%Model{} = model, %Event.Key{key: :tab, mod: [:shift]}) do
    switch_active(model, prev_index(model))
  end

  # Right arrow / Tab - next tab
  defp handle_key(%Model{} = model, %Event.Key{key: :right, mod: []}) do
    switch_active(model, next_index(model))
  end

  defp handle_key(%Model{} = model, %Event.Key{key: :tab, mod: []}) do
    switch_active(model, next_index(model))
  end

  # Number keys 1-9 - jump to tab index
  defp handle_key(%Model{} = model, %Event.Key{key: key, mod: []}) when is_binary(key) do
    case Integer.parse(key) do
      {n, ""} when n >= 1 and n <= 9 ->
        jump_to(model, n - 1)

      _ ->
        model
    end
  end

  defp handle_key(%Model{} = model, _key), do: model

  defp jump_to(%Model{} = model, index) do
    if index < length(model.tabs) do
      switch_active(model, index)
    else
      model
    end
  end

  defp switch_active(%Model{} = model, index) do
    new_model = %{model | active: index}
    maybe_emit_on_change(new_model, model)
  end

  defp prev_index(%Model{active: active, tabs: tabs}) do
    len = length(tabs)
    rem(active - 1 + len, len)
  end

  defp next_index(%Model{active: active, tabs: tabs}) do
    len = length(tabs)
    rem(active + 1, len)
  end

  # --- Rendering ---

  defp render(%Model{} = model) do
    bar = render_tab_bar(model)
    divider = render_divider(model)
    content = render_content(model)

    Element.column([], [bar, divider, content])
  end

  defp render_tab_bar(%Model{} = model) do
    children =
      model.tabs
      |> Enum.with_index()
      |> Enum.flat_map(fn {{label, _content}, index} ->
        tab = render_tab_label(model, label, index)

        if index < length(model.tabs) - 1 do
          [tab, render_separator(model)]
        else
          [tab]
        end
      end)

    Element.row([height: 1], children)
  end

  defp render_tab_label(%Model{} = model, label, index) when is_binary(label) do
    variant_style = if index == model.active, do: model.active_style, else: model.inactive_style
    style = Style.merge(model.style, variant_style)

    text_preserve(" " <> label <> " ", style)
  end

  defp render_separator(%Model{} = model) do
    text_preserve("│", model.style)
  end

  defp render_divider(%Model{} = model) do
    content = divider_string(model)
    text_preserve(content, Style.merge(model.style, Style.new(height: 1)))
  end

  defp divider_string(%Model{tabs: tabs} = model) do
    tabs
    |> Enum.with_index()
    |> Enum.map_join("┴", fn {{label, _}, index} ->
      segment_len = String.length(" " <> label <> " ")
      char = if index == model.active, do: " ", else: "─"
      String.duplicate(char, segment_len)
    end)
  end

  defp render_content(%Model{tabs: []}), do: Element.box([flex_grow: 1], [Element.text("")])

  defp render_content(%Model{} = model) do
    {_label, content} = Enum.at(model.tabs, model.active)
    Element.box([flex_grow: 1], [content])
  end

  defp text_preserve(content, %Style{} = style) when is_binary(content) do
    %Element{
      type: :text,
      style: style,
      children: [],
      attrs: %{content: content, preserve_whitespace: true}
    }
  end

  defp do_tab_at_x([], _x, _offset, _index), do: nil

  defp do_tab_at_x([{label, _content} | rest], x, offset, index) do
    width = tab_label_width(label)

    cond do
      x >= offset and x < offset + width ->
        index

      rest == [] ->
        nil

      true ->
        do_tab_at_x(rest, x, offset + width + 1, index + 1)
    end
  end

  defp tab_label_width(label) when is_binary(label), do: String.length(label) + 2

  # --- Normalization / helpers ---

  defp normalize_tabs(tabs) when is_list(tabs) do
    Enum.flat_map(tabs, fn
      {label, %Element{} = content} -> [{to_string(label), content}]
      _other -> []
    end)
  end

  defp normalize_style(%Style{} = style), do: style
  defp normalize_style(opts) when is_list(opts), do: Style.new(opts)
  defp normalize_style(_), do: Style.new()

  defp clamp_index(_index, []), do: 0

  defp clamp_index(index, tabs) when is_integer(index) do
    index |> max(0) |> min(length(tabs) - 1)
  end

  defp adjust_active_after_remove(active, removed_index, new_tabs) do
    cond do
      new_tabs == [] ->
        0

      removed_index < active ->
        clamp_index(active - 1, new_tabs)

      removed_index == active ->
        clamp_index(active, new_tabs)

      true ->
        clamp_index(active, new_tabs)
    end
  end

  defp maybe_emit_on_change(%Model{} = new_model, %Model{} = old_model) do
    if new_model.on_change && new_model.active != old_model.active do
      {new_model, {new_model.on_change, new_model.active}}
    else
      new_model
    end
  end
end
