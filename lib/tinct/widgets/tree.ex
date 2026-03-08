defmodule Tinct.Widgets.Tree do
  @moduledoc """
  A hierarchical expandable tree widget.

  Implements the `Tinct.Component` behaviour. Displays a tree of nodes with
  expand/collapse, keyboard navigation, selection callbacks, and scrolling.

  ## Init Options

    * `:root` — a tree node map with `:label` (string) and `:children` (list of nodes).
      Default: `%{label: "", children: []}`.
    * `:height` — visible viewport height in rows (default `10`)
    * `:expanded` — `MapSet` of node paths that start expanded (default: root expanded)
    * `:style` — a `Tinct.Style.t()` for unselected items (default `Style.new()`)
    * `:selected_style` — a `Tinct.Style.t()` for the selected item
      (default `Style.new(bg: :blue, fg: :white)`)
    * `:on_select` — atom tag emitted as `{tag, node}` when Enter is pressed (default `nil`)

  ## Key Bindings

    * Up / `k` — move selection up
    * Down / `j` — move selection down
    * Right / Enter — expand node (if collapsed and has children)
    * Left — collapse node, or move to parent if leaf/already collapsed
    * Space — toggle expand/collapse
    * Home — jump to first visible node
    * End — jump to last visible node

  ## Rendering

      ▼ project
        ▼ src/
            app.ex
            router.ex
        ▶ test/
          mix.exs

  - 2-space indentation per depth level
  - ▶/▼ indicators for nodes with children
  - No indicator for leaf nodes (2-space indent instead)
  - Selected item highlighted
  - Scrollable when taller than viewport

  ## Examples

      root = %{label: "project", children: [
        %{label: "src/", children: [%{label: "app.ex", children: []}]},
        %{label: "mix.exs", children: []}
      ]}
      state = Tinct.Test.render(Tinct.Widgets.Tree, root: root)
      assert Tinct.Test.contains?(state, "project")
  """

  use Tinct.Component

  alias Tinct.{Element, Event, Style, View}

  defmodule Model do
    @moduledoc """
    State struct for the Tree widget.
    """

    @type tree_node :: %{label: String.t(), children: [tree_node()]}

    @type t :: %__MODULE__{
            root: node(),
            selected: non_neg_integer(),
            offset: non_neg_integer(),
            height: pos_integer(),
            expanded: MapSet.t(),
            style: Style.t(),
            selected_style: Style.t(),
            on_select: atom() | nil
          }

    defstruct root: %{label: "", children: []},
              selected: 0,
              offset: 0,
              height: 10,
              expanded: MapSet.new(),
              style: %Style{},
              selected_style: %Style{},
              on_select: nil
  end

  # --- Component callbacks ---

  @impl Tinct.Component
  def init(opts) do
    root = Keyword.get(opts, :root, %{label: "", children: []})
    height = Keyword.get(opts, :height, 10)
    expanded = Keyword.get(opts, :expanded, MapSet.new([[0]]))

    %Model{
      root: root,
      selected: 0,
      offset: 0,
      height: height,
      expanded: expanded,
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

  def update(%Model{} = model, _msg), do: model

  @impl Tinct.Component
  def view(%Model{} = model) do
    content = render_tree(model)
    View.new(content)
  end

  # --- Public API ---

  @doc """
  Returns the list of visible (flattened) nodes as `{node, depth, path}` tuples.

  Only nodes whose ancestors are all expanded are included.

  ## Examples

      iex> root = %{label: "a", children: [%{label: "b", children: []}]}
      iex> model = Tinct.Widgets.Tree.init(root: root)
      iex> visible = Tinct.Widgets.Tree.visible_nodes(model)
      iex> Enum.map(visible, fn {node, _depth, _path} -> node.label end)
      ["a", "b"]
  """
  @spec visible_nodes(Model.t()) :: [
          {Model.tree_node(), non_neg_integer(), [non_neg_integer()]}
        ]
  def visible_nodes(%Model{root: %{label: "", children: []}}), do: []

  def visible_nodes(%Model{root: root, expanded: expanded}) do
    flatten_visible(root, 0, [0], expanded)
  end

  @doc """
  Returns the currently selected visible node, or `nil` for an empty tree.

  ## Examples

      iex> root = %{label: "a", children: [%{label: "b", children: []}]}
      iex> model = Tinct.Widgets.Tree.init(root: root)
      iex> {node, _depth, _path} = Tinct.Widgets.Tree.selected_node(model)
      iex> node.label
      "a"
  """
  @spec selected_node(Model.t()) ::
          {Model.tree_node(), non_neg_integer(), [non_neg_integer()]} | nil
  def selected_node(%Model{} = model) do
    nodes = visible_nodes(model)
    Enum.at(nodes, model.selected)
  end

  @doc """
  Expands the node at the given path.

  ## Examples

      iex> root = %{label: "a", children: [%{label: "b", children: [%{label: "c", children: []}]}]}
      iex> model = Tinct.Widgets.Tree.init(root: root)
      iex> model = Tinct.Widgets.Tree.expand(model, [0, 0])
      iex> MapSet.member?(model.expanded, [0, 0])
      true
  """
  @spec expand(Model.t(), [non_neg_integer()]) :: Model.t()
  def expand(%Model{expanded: expanded} = model, path) do
    %{model | expanded: MapSet.put(expanded, path)}
  end

  @doc """
  Collapses the node at the given path.

  ## Examples

      iex> root = %{label: "a", children: [%{label: "b", children: [%{label: "c", children: []}]}]}
      iex> model = Tinct.Widgets.Tree.init(root: root)
      iex> model = Tinct.Widgets.Tree.collapse(model, [0])
      iex> MapSet.member?(model.expanded, [0])
      false
  """
  @spec collapse(Model.t(), [non_neg_integer()]) :: Model.t()
  def collapse(%Model{expanded: expanded} = model, path) do
    # Also collapse all descendants
    new_expanded =
      Enum.reject(expanded, fn p ->
        List.starts_with?(p, path)
      end)
      |> MapSet.new()

    %{model | expanded: new_expanded}
    |> clamp_selection()
    |> ensure_visible()
  end

  # --- Key handling ---

  defp handle_key(%Model{} = model, key) do
    case visible_nodes(model) do
      [] -> model
      nodes -> do_handle_key(model, key, nodes)
    end
  end

  defp do_handle_key(model, %Event.Key{key: :up, mod: []}, _nodes) do
    move_selection(model, -1)
  end

  defp do_handle_key(model, %Event.Key{key: "k", mod: []}, _nodes) do
    move_selection(model, -1)
  end

  defp do_handle_key(model, %Event.Key{key: :down, mod: []}, _nodes) do
    move_selection(model, 1)
  end

  defp do_handle_key(model, %Event.Key{key: "j", mod: []}, _nodes) do
    move_selection(model, 1)
  end

  defp do_handle_key(model, %Event.Key{key: :home, mod: []}, _nodes) do
    %{model | selected: 0} |> ensure_visible()
  end

  defp do_handle_key(model, %Event.Key{key: :end, mod: []}, nodes) do
    %{model | selected: max(0, length(nodes) - 1)} |> ensure_visible()
  end

  # Right — expand if has children
  defp do_handle_key(model, %Event.Key{key: :right, mod: []}, nodes) do
    case Enum.at(nodes, model.selected) do
      {node, _depth, path} when node.children != [] ->
        expand(model, path)

      _ ->
        model
    end
  end

  # Enter — expand if collapsed+children, otherwise fire on_select
  defp do_handle_key(model, %Event.Key{key: :enter, mod: []}, nodes) do
    case Enum.at(nodes, model.selected) do
      {node, _depth, path} when node.children != [] ->
        if MapSet.member?(model.expanded, path) do
          fire_select(model, nodes)
        else
          expand(model, path)
        end

      _ ->
        fire_select(model, nodes)
    end
  end

  # Left — collapse if expanded, or move to parent
  defp do_handle_key(model, %Event.Key{key: :left, mod: []}, nodes) do
    case Enum.at(nodes, model.selected) do
      {node, _depth, path} ->
        if node.children != [] and MapSet.member?(model.expanded, path) do
          collapse(model, path)
        else
          move_to_parent(model, path, nodes)
        end

      _ ->
        model
    end
  end

  # Space — toggle expand/collapse
  defp do_handle_key(model, %Event.Key{key: " ", mod: []}, nodes) do
    case Enum.at(nodes, model.selected) do
      {node, _depth, path} when node.children != [] ->
        if MapSet.member?(model.expanded, path) do
          collapse(model, path)
        else
          expand(model, path)
        end

      _ ->
        model
    end
  end

  defp do_handle_key(model, _key, _nodes), do: model

  defp fire_select(%Model{on_select: nil} = model, _nodes), do: model

  defp fire_select(%Model{on_select: tag} = model, nodes) do
    case Enum.at(nodes, model.selected) do
      {node, _depth, _path} -> {model, {tag, node}}
      _ -> model
    end
  end

  # --- Selection movement ---

  defp move_selection(%Model{} = model, delta) do
    nodes = visible_nodes(model)
    max_index = max(0, length(nodes) - 1)
    new_selected = model.selected + delta
    clamped = clamp(new_selected, 0, max_index)

    %{model | selected: clamped}
    |> ensure_visible()
  end

  defp move_to_parent(%Model{} = model, path, nodes) do
    parent_path = Enum.slice(path, 0..(length(path) - 2)//1)

    if parent_path == [] do
      model
    else
      parent_index =
        Enum.find_index(nodes, fn {_node, _depth, p} -> p == parent_path end)

      if parent_index do
        %{model | selected: parent_index} |> ensure_visible()
      else
        model
      end
    end
  end

  defp clamp_selection(%Model{} = model) do
    nodes = visible_nodes(model)
    max_index = max(0, length(nodes) - 1)
    %{model | selected: clamp(model.selected, 0, max_index)}
  end

  # --- Scroll management ---

  defp ensure_visible(%Model{selected: selected, offset: offset, height: height} = model) do
    case visible_nodes(model) do
      [] ->
        %{model | offset: 0}

      _nodes ->
        cond do
          selected < offset ->
            %{model | offset: selected}

          selected >= offset + height ->
            %{model | offset: selected - height + 1}

          true ->
            model
        end
    end
  end

  # --- Tree flattening ---

  defp flatten_visible(node, depth, path, expanded) do
    self_entry = [{node, depth, path}]

    if node.children != [] and MapSet.member?(expanded, path) do
      children_entries =
        node.children
        |> Enum.with_index()
        |> Enum.flat_map(fn {child, idx} ->
          child_path = path ++ [idx]
          flatten_visible(child, depth + 1, child_path, expanded)
        end)

      self_entry ++ children_entries
    else
      self_entry
    end
  end

  # --- Rendering ---

  defp render_tree(%Model{} = model) do
    case visible_nodes(model) do
      [] ->
        Element.text("")

      nodes ->
        visible_slice =
          nodes
          |> Enum.with_index()
          |> Enum.slice(model.offset, model.height)

        children =
          Enum.map(visible_slice, fn {{node, depth, path}, flat_index} ->
            {label, indent} = format_node(node, depth, path, model.expanded)

            style_attrs = tree_node_style_attrs(model, flat_index)

            Element.box([padding_left: indent], [Element.text(label, style_attrs)])
          end)

        Element.column([], children)
    end
  end

  defp tree_node_style_attrs(%Model{} = model, flat_index) when is_integer(flat_index) do
    if flat_index == model.selected do
      Style.to_cell_attrs(model.selected_style)
    else
      Style.to_cell_attrs(model.style)
    end
  end

  @doc false
  @spec format_node(map(), non_neg_integer(), [non_neg_integer()], MapSet.t()) ::
          {String.t(), non_neg_integer()}
  def format_node(node, depth, path, expanded) do
    base_indent = depth * 2

    if node.children != [] do
      prefix = if MapSet.member?(expanded, path), do: "▼ ", else: "▶ "
      {prefix <> node.label, base_indent}
    else
      # Leaf nodes get extra indent to align with branch labels after ▼/▶
      {node.label, base_indent + 2}
    end
  end

  # --- Helpers ---

  defp clamp(value, min_val, max_val) do
    value |> max(min_val) |> min(max_val)
  end
end
