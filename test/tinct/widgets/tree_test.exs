defmodule Tinct.Widgets.TreeTest do
  use ExUnit.Case, async: true

  alias Tinct.Test, as: T
  alias Tinct.Widgets.Tree

  doctest Tinct.Widgets.Tree

  @simple_root %{
    label: "project",
    children: [
      %{
        label: "src/",
        children: [
          %{label: "app.ex", children: []},
          %{label: "router.ex", children: []}
        ]
      },
      %{label: "mix.exs", children: []}
    ]
  }

  @deep_root %{
    label: "a",
    children: [
      %{
        label: "b",
        children: [
          %{
            label: "c",
            children: [
              %{
                label: "d",
                children: [
                  %{label: "e", children: [%{label: "f", children: []}]}
                ]
              }
            ]
          }
        ]
      }
    ]
  }

  # --- init ---

  describe "init/1" do
    test "defaults to empty root" do
      model = Tree.init([])
      assert model.root == %{label: "", children: []}
      assert model.selected == 0
      assert model.offset == 0
    end

    test "initializes with root node" do
      model = Tree.init(root: @simple_root)
      assert model.root.label == "project"
      assert model.selected == 0
    end

    test "root is expanded by default" do
      model = Tree.init(root: @simple_root)
      assert MapSet.member?(model.expanded, [0])
    end

    test "sets height" do
      model = Tree.init(root: @simple_root, height: 5)
      assert model.height == 5
    end

    test "sets on_select callback tag" do
      model = Tree.init(root: @simple_root, on_select: :picked)
      assert model.on_select == :picked
    end
  end

  # --- Rendering ---

  describe "view/1" do
    test "renders root and expanded children" do
      state = T.render(Tree, root: @simple_root, height: 10, size: {40, 10})
      assert T.contains?(state, "project")
      assert T.contains?(state, "src/")
      assert T.contains?(state, "mix.exs")
    end

    test "renders expand/collapse indicators" do
      state = T.render(Tree, root: @simple_root, height: 10, size: {40, 10})
      # Root is expanded
      assert T.contains?(state, "▼ project")
      # src/ is collapsed (not expanded by default, only root is)
      assert T.contains?(state, "▶ src/")
      # mix.exs is a leaf — no indicator, just indent
      assert T.contains?(state, "mix.exs")
    end

    test "renders correct indentation" do
      state = T.render(Tree, root: @simple_root, height: 10, size: {40, 10})
      # Expand src/ via keyboard
      state = T.send_key(state, :down)
      state = T.send_key(state, :right)

      # Root at depth 0: "▼ project" (no indent)
      assert T.line(state, 0) == "▼ project"
      # src/ at depth 1: 2 spaces indent + "▼ src/"
      assert T.line(state, 1) == "  ▼ src/"
      # app.ex at depth 2: leaf indent = 2*2 + 2 = 6 spaces + "app.ex"
      assert T.line(state, 2) == "      app.ex"
      # router.ex at depth 2: same leaf indent
      assert T.line(state, 3) == "      router.ex"
      # mix.exs at depth 1: leaf indent = 1*2 + 2 = 4 spaces + "mix.exs"
      assert T.line(state, 4) == "    mix.exs"
    end

    test "collapsed children are not rendered" do
      state = T.render(Tree, root: @simple_root, height: 10, size: {40, 10})
      # src/ is collapsed, so app.ex and router.ex should not appear
      refute T.contains?(state, "app.ex")
      refute T.contains?(state, "router.ex")
    end

    test "renders empty tree without crashing" do
      state = T.render(Tree, root: %{label: "", children: []}, size: {40, 10})
      assert %T.State{} = state
    end
  end

  # --- visible_nodes ---

  describe "visible_nodes/1" do
    test "returns root and expanded children" do
      model = Tree.init(root: @simple_root)
      nodes = Tree.visible_nodes(model)
      labels = Enum.map(nodes, fn {node, _d, _p} -> node.label end)
      # Root expanded, children not expanded
      assert labels == ["project", "src/", "mix.exs"]
    end

    test "returns empty list for empty root" do
      model = Tree.init([])
      assert Tree.visible_nodes(model) == []
    end

    test "includes grandchildren when parent expanded" do
      model = Tree.init(root: @simple_root)
      model = Tree.expand(model, [0, 0])
      nodes = Tree.visible_nodes(model)
      labels = Enum.map(nodes, fn {node, _d, _p} -> node.label end)
      assert labels == ["project", "src/", "app.ex", "router.ex", "mix.exs"]
    end
  end

  # --- Down/j navigation ---

  describe "down/j navigation" do
    test "down arrow moves selection down" do
      state = T.render(Tree, root: @simple_root, height: 10)
      assert state.model.selected == 0

      state = T.send_key(state, :down)
      assert state.model.selected == 1

      state = T.send_key(state, :down)
      assert state.model.selected == 2
    end

    test "j key moves selection down" do
      state = T.render(Tree, root: @simple_root, height: 10)
      state = T.send_key(state, "j")
      assert state.model.selected == 1
    end

    test "down stops at last visible item" do
      state = T.render(Tree, root: @simple_root, height: 10)
      # 3 visible: project, src/, mix.exs
      state = state |> T.send_key(:down) |> T.send_key(:down) |> T.send_key(:down)
      assert state.model.selected == 2
    end
  end

  # --- Up/k navigation ---

  describe "up/k navigation" do
    test "up arrow moves selection up" do
      state = T.render(Tree, root: @simple_root, height: 10)
      state = state |> T.send_key(:down) |> T.send_key(:down)
      assert state.model.selected == 2

      state = T.send_key(state, :up)
      assert state.model.selected == 1
    end

    test "k key moves selection up" do
      state = T.render(Tree, root: @simple_root, height: 10)
      state = T.send_key(state, :down)
      state = T.send_key(state, "k")
      assert state.model.selected == 0
    end

    test "up stops at first item" do
      state = T.render(Tree, root: @simple_root, height: 10)
      state = T.send_key(state, :up)
      assert state.model.selected == 0
    end
  end

  # --- Home/End navigation ---

  describe "home/end navigation" do
    test "home jumps to first item" do
      state = T.render(Tree, root: @simple_root, height: 10)
      state = state |> T.send_key(:down) |> T.send_key(:down)
      state = T.send_key(state, :home)
      assert state.model.selected == 0
    end

    test "end jumps to last visible item" do
      state = T.render(Tree, root: @simple_root, height: 10)
      state = T.send_key(state, :end)
      # 3 visible items: project(0), src/(1), mix.exs(2)
      assert state.model.selected == 2
    end
  end

  # --- Expand/collapse ---

  describe "expand/collapse" do
    test "right arrow expands collapsed node with children" do
      state = T.render(Tree, root: @simple_root, height: 10, size: {40, 10})
      # Move to src/ (index 1)
      state = T.send_key(state, :down)
      assert state.model.selected == 1

      # Expand src/
      state = T.send_key(state, :right)
      assert T.contains?(state, "app.ex")
      assert T.contains?(state, "router.ex")
    end

    test "enter expands collapsed node with children" do
      state = T.render(Tree, root: @simple_root, height: 10, size: {40, 10})
      state = T.send_key(state, :down)
      state = T.send_key(state, :enter)
      assert T.contains?(state, "app.ex")
    end

    test "left arrow collapses expanded node" do
      state = T.render(Tree, root: @simple_root, height: 10, size: {40, 10})
      # Expand src/ first
      state = T.send_key(state, :down)
      state = T.send_key(state, :right)
      assert T.contains?(state, "app.ex")

      # Collapse src/
      state = T.send_key(state, :left)
      refute T.contains?(state, "app.ex")
    end

    test "left arrow on leaf moves to parent" do
      state = T.render(Tree, root: @simple_root, height: 10)
      # Expand src/
      state = T.send_key(state, :down)
      state = T.send_key(state, :right)
      # Move to app.ex (index 2)
      state = T.send_key(state, :down)
      assert state.model.selected == 2

      # Left on leaf goes to parent (src/ at index 1)
      state = T.send_key(state, :left)
      assert state.model.selected == 1
    end

    test "space toggles expand/collapse" do
      state = T.render(Tree, root: @simple_root, height: 10, size: {40, 10})
      state = T.send_key(state, :down)

      # Expand
      state = T.send_key(state, " ")
      assert T.contains?(state, "app.ex")

      # Collapse
      state = T.send_key(state, " ")
      refute T.contains?(state, "app.ex")
    end

    test "right arrow on leaf does nothing" do
      state = T.render(Tree, root: @simple_root, height: 10)
      # Move to mix.exs (index 2, a leaf)
      state = state |> T.send_key(:down) |> T.send_key(:down)
      before = state.model

      state = T.send_key(state, :right)
      assert state.model.selected == before.selected
    end

    test "space on leaf does nothing" do
      state = T.render(Tree, root: @simple_root, height: 10)
      state = state |> T.send_key(:down) |> T.send_key(:down)
      before_expanded = state.model.expanded

      state = T.send_key(state, " ")
      assert state.model.expanded == before_expanded
    end
  end

  # --- Selection navigates only visible nodes ---

  describe "selection navigates only visible nodes" do
    test "down skips collapsed children" do
      state = T.render(Tree, root: @simple_root, height: 10)
      # project(0), src/(1 - collapsed), mix.exs(2)
      state = T.send_key(state, :down)
      {node, _, _} = Tree.selected_node(state.model)
      assert node.label == "src/"

      state = T.send_key(state, :down)
      {node, _, _} = Tree.selected_node(state.model)
      assert node.label == "mix.exs"
    end

    test "collapsing moves selection if it was on a hidden child" do
      state = T.render(Tree, root: @simple_root, height: 10)
      # Expand src/
      state = T.send_key(state, :down)
      state = T.send_key(state, :right)
      # Now: project(0), src/(1), app.ex(2), router.ex(3), mix.exs(4)

      # Navigate to router.ex
      state = state |> T.send_key(:down) |> T.send_key(:down)
      assert state.model.selected == 3
      {node, _, _} = Tree.selected_node(state.model)
      assert node.label == "router.ex"

      # Collapse root — only project remains visible
      state = T.send_key(state, :home)
      state = T.send_key(state, :left)
      # After collapse, selected should be clamped to 0 (only root visible)
      assert state.model.selected == 0
    end
  end

  # --- Scrolling ---

  describe "scrolling" do
    test "scrolls down when selection moves below viewport" do
      # Small viewport of 2 rows, 3 visible items
      state = T.render(Tree, root: @simple_root, height: 2)
      assert state.model.offset == 0

      state = state |> T.send_key(:down) |> T.send_key(:down)
      assert state.model.selected == 2
      assert state.model.offset == 1
    end

    test "scrolls up when selection moves above viewport" do
      state = T.render(Tree, root: @simple_root, height: 2)
      # Go to end
      state = T.send_key(state, :end)
      assert state.model.offset == 1

      # Go back to top
      state = T.send_key(state, :home)
      assert state.model.offset == 0
    end

    test "scrolls with expanded content exceeding viewport" do
      state = T.render(Tree, root: @simple_root, height: 3)
      # Expand src/ — now 5 items visible, viewport 3
      state = T.send_key(state, :down)
      state = T.send_key(state, :right)

      # Navigate to end
      state = T.send_key(state, :end)
      assert state.model.selected == 4
      assert state.model.offset > 0
    end
  end

  # --- on_select callback ---

  describe "on_select callback" do
    test "enter on already-expanded node fires on_select" do
      state = T.render(Tree, root: @simple_root, on_select: :picked, height: 10)
      # Root is already expanded, so Enter should fire callback
      {_state, cmd} = T.send_key_raw(state, :enter)
      assert {:picked, node} = cmd
      assert node.label == "project"
    end

    test "enter on leaf fires on_select" do
      state = T.render(Tree, root: @simple_root, on_select: :picked, height: 10)
      # Move to mix.exs (leaf)
      state = state |> T.send_key(:down) |> T.send_key(:down)
      {_state, cmd} = T.send_key_raw(state, :enter)
      assert {:picked, node} = cmd
      assert node.label == "mix.exs"
    end

    test "enter on collapsed node expands instead of firing callback" do
      state = T.render(Tree, root: @simple_root, on_select: :picked, height: 10)
      # Move to src/ (collapsed)
      state = T.send_key(state, :down)
      {state, cmd} = T.send_key_raw(state, :enter)
      # Should expand, not fire callback
      assert cmd == nil
      assert T.contains?(state, "app.ex")
    end

    test "enter without on_select does nothing" do
      state = T.render(Tree, root: @simple_root, height: 10)
      {_state, cmd} = T.send_key_raw(state, :enter)
      assert cmd == nil
    end
  end

  # --- Deeply nested trees ---

  describe "deeply nested trees (5+ levels)" do
    test "renders 5+ levels of depth correctly" do
      # Expand all levels
      model = Tree.init(root: @deep_root)
      model = Tree.expand(model, [0, 0])
      model = Tree.expand(model, [0, 0, 0])
      model = Tree.expand(model, [0, 0, 0, 0])
      model = Tree.expand(model, [0, 0, 0, 0, 0])

      nodes = Tree.visible_nodes(model)
      labels = Enum.map(nodes, fn {node, _d, _p} -> node.label end)
      assert labels == ["a", "b", "c", "d", "e", "f"]
    end

    test "navigates through deeply nested visible nodes" do
      # Expand each level via keyboard: down + right at each node
      state = T.render(Tree, root: @deep_root, height: 10, size: {60, 10})

      # Root "a" is already expanded, "b" is visible at index 1
      state = T.send_key(state, :down)
      state = T.send_key(state, :right)

      # "c" is now visible at index 2
      state = T.send_key(state, :down)
      state = T.send_key(state, :right)

      # "d" at index 3
      state = T.send_key(state, :down)
      state = T.send_key(state, :right)

      # "e" at index 4
      state = T.send_key(state, :down)
      state = T.send_key(state, :right)

      # Now all 6 nodes are visible, check indentation
      assert T.line(state, 0) == "▼ a"
      assert T.line(state, 1) == "  ▼ b"
      assert T.line(state, 2) == "    ▼ c"
      assert T.line(state, 3) == "      ▼ d"
      assert T.line(state, 4) == "        ▼ e"
      assert T.line(state, 5) == "            f"
    end

    test "indentation is correct at depth 5" do
      model = Tree.init(root: @deep_root, height: 10)
      model = Tree.expand(model, [0, 0])
      model = Tree.expand(model, [0, 0, 0])
      model = Tree.expand(model, [0, 0, 0, 0])
      model = Tree.expand(model, [0, 0, 0, 0, 0])

      nodes = Tree.visible_nodes(model)
      # f is at depth 5
      {_node, depth, _path} = List.last(nodes)
      assert depth == 5
    end
  end

  # --- Empty tree ---

  describe "empty tree" do
    test "renders without crashing" do
      state = T.render(Tree, [], size: {40, 10})
      assert %T.State{} = state
    end

    test "navigation keys don't crash on empty tree" do
      state = T.render(Tree, [])

      state = T.send_key(state, :down)
      assert state.model.selected == 0

      state = T.send_key(state, :up)
      assert state.model.selected == 0

      state = T.send_key(state, :home)
      assert state.model.selected == 0

      state = T.send_key(state, :end)
      assert state.model.selected == 0

      state = T.send_key(state, :right)
      assert state.model.selected == 0

      state = T.send_key(state, :left)
      assert state.model.selected == 0

      state = T.send_key(state, " ")
      assert state.model.selected == 0
    end
  end

  # --- Unknown events ---

  describe "unknown events" do
    test "ignores unknown key events" do
      state = T.render(Tree, root: @simple_root, height: 10)
      state = T.send_key(state, "x")
      assert state.model.selected == 0
    end

    test "ignores non-key events" do
      state = T.render(Tree, root: @simple_root, height: 10)
      state = T.send_event(state, :random_message)
      assert state.model.selected == 0
    end
  end

  # --- Public API ---

  describe "expand/2" do
    test "expands a node by path" do
      model = Tree.init(root: @simple_root)
      refute MapSet.member?(model.expanded, [0, 0])

      model = Tree.expand(model, [0, 0])
      assert MapSet.member?(model.expanded, [0, 0])
    end
  end

  describe "collapse/2" do
    test "collapses a node and its descendants" do
      model = Tree.init(root: @simple_root)
      model = Tree.expand(model, [0, 0])
      assert MapSet.member?(model.expanded, [0])
      assert MapSet.member?(model.expanded, [0, 0])

      model = Tree.collapse(model, [0])
      refute MapSet.member?(model.expanded, [0])
      refute MapSet.member?(model.expanded, [0, 0])
    end
  end

  describe "selected_node/1" do
    test "returns the currently selected node" do
      model = Tree.init(root: @simple_root)
      {node, depth, _path} = Tree.selected_node(model)
      assert node.label == "project"
      assert depth == 0
    end

    test "returns nil for empty tree" do
      model = Tree.init([])
      assert Tree.selected_node(model) == nil
    end
  end
end
