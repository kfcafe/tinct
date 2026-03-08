defmodule Tinct.HitTestTest do
  use ExUnit.Case, async: true

  alias Tinct.Event.Mouse
  alias Tinct.FocusGroup
  alias Tinct.HitTest

  doctest Tinct.HitTest

  describe "new/0" do
    test "creates an empty hit map" do
      hm = HitTest.new()
      assert hm.entries == []
      assert HitTest.size(hm) == 0
    end
  end

  describe "register/3" do
    test "adds a tagged rect" do
      hm = HitTest.new() |> HitTest.register(:panel, {0, 0, 20, 10})
      assert HitTest.size(hm) == 1
      assert hm.entries == [{:panel, {0, 0, 20, 10}}]
    end

    test "preserves registration order" do
      hm =
        HitTest.new()
        |> HitTest.register(:first, {0, 0, 10, 10})
        |> HitTest.register(:second, {5, 5, 10, 10})

      assert [{:first, _}, {:second, _}] = hm.entries
    end

    test "accepts tuple tags" do
      hm = HitTest.new() |> HitTest.register({:task, 42}, {0, 0, 10, 3})
      assert [{{{:task, 42}, _}}] = [hm.entries |> hd() |> then(&{&1})]
    end

    test "accepts string tags" do
      hm = HitTest.new() |> HitTest.register("button-ok", {0, 0, 8, 1})
      assert HitTest.resolve(hm, 0, 0) == "button-ok"
    end

    test "accepts zero-size rects" do
      hm = HitTest.new() |> HitTest.register(:empty, {5, 5, 0, 0})
      assert HitTest.size(hm) == 1
      # Zero-size rect never matches
      assert HitTest.resolve(hm, 5, 5) == nil
    end
  end

  describe "resolve/3" do
    test "returns tag when point is inside rect" do
      hm = HitTest.new() |> HitTest.register(:panel, {10, 5, 20, 15})

      # Top-left corner (inclusive)
      assert HitTest.resolve(hm, 10, 5) == :panel
      # Middle
      assert HitTest.resolve(hm, 20, 12) == :panel
      # Bottom-right corner just inside (exclusive boundary)
      assert HitTest.resolve(hm, 29, 19) == :panel
    end

    test "returns nil when point is outside rect" do
      hm = HitTest.new() |> HitTest.register(:panel, {10, 5, 20, 15})

      # Left of rect
      assert HitTest.resolve(hm, 9, 10) == nil
      # Above rect
      assert HitTest.resolve(hm, 15, 4) == nil
      # Right edge (exclusive)
      assert HitTest.resolve(hm, 30, 10) == nil
      # Bottom edge (exclusive)
      assert HitTest.resolve(hm, 15, 20) == nil
    end

    test "returns nil for empty hit map" do
      assert HitTest.resolve(HitTest.new(), 5, 5) == nil
    end

    test "nested regions resolve to deepest match" do
      hm =
        HitTest.new()
        |> HitTest.register(:outer, {0, 0, 40, 30})
        |> HitTest.register(:inner, {5, 5, 20, 15})
        |> HitTest.register(:innermost, {8, 8, 10, 5})

      # Click in innermost region
      assert HitTest.resolve(hm, 10, 10) == :innermost
      # Click in inner but not innermost
      assert HitTest.resolve(hm, 6, 6) == :inner
      # Click in outer but not inner
      assert HitTest.resolve(hm, 1, 1) == :outer
      # Click outside everything
      assert HitTest.resolve(hm, 41, 31) == nil
    end

    test "overlapping non-nested rects resolve to last registered" do
      hm =
        HitTest.new()
        |> HitTest.register(:left, {0, 0, 20, 10})
        |> HitTest.register(:right, {10, 0, 20, 10})

      # Overlap zone at x=15 — :right wins (registered later)
      assert HitTest.resolve(hm, 15, 5) == :right
      # Only :left
      assert HitTest.resolve(hm, 5, 5) == :left
      # Only :right
      assert HitTest.resolve(hm, 25, 5) == :right
    end

    test "sibling rects resolve independently" do
      hm =
        HitTest.new()
        |> HitTest.register(:sidebar, {0, 0, 20, 30})
        |> HitTest.register(:main, {20, 0, 60, 30})

      assert HitTest.resolve(hm, 10, 15) == :sidebar
      assert HitTest.resolve(hm, 40, 15) == :main
      assert HitTest.resolve(hm, 19, 0) == :sidebar
      assert HitTest.resolve(hm, 20, 0) == :main
    end

    test "boundary: top-left corner is inclusive" do
      hm = HitTest.new() |> HitTest.register(:box, {5, 3, 10, 8})
      assert HitTest.resolve(hm, 5, 3) == :box
    end

    test "boundary: bottom-right edge is exclusive" do
      hm = HitTest.new() |> HitTest.register(:box, {5, 3, 10, 8})
      # x=15 is at x+w, y=11 is at y+h — both exclusive
      assert HitTest.resolve(hm, 15, 3) == nil
      assert HitTest.resolve(hm, 5, 11) == nil
      assert HitTest.resolve(hm, 15, 11) == nil
      # Just inside
      assert HitTest.resolve(hm, 14, 10) == :box
    end
  end

  describe "handle_click/3" do
    test "resolves hit and focuses matching pane" do
      hm =
        HitTest.new()
        |> HitTest.register(:sidebar, {0, 0, 20, 30})
        |> HitTest.register(:main, {20, 0, 60, 30})

      fg = FocusGroup.new([:sidebar, :main])
      mouse = %Mouse{type: :click, button: :left, x: 40, y: 15}

      assert {:hit, :main, updated_fg} = HitTest.handle_click(hm, mouse, fg)
      assert updated_fg.active == :main
    end

    test "returns {:miss, fg} when click is outside all rects" do
      hm = HitTest.new() |> HitTest.register(:panel, {0, 0, 10, 10})
      fg = FocusGroup.new([:panel])
      mouse = %Mouse{type: :click, button: :left, x: 50, y: 50}

      assert {:miss, ^fg} = HitTest.handle_click(hm, mouse, fg)
    end

    test "focus unchanged when tag is not a pane" do
      hm =
        HitTest.new()
        |> HitTest.register(:sidebar, {0, 0, 30, 30})
        |> HitTest.register({:task, 1}, {2, 2, 26, 3})

      fg = FocusGroup.new([:sidebar, :main])
      mouse = %Mouse{type: :click, button: :left, x: 5, y: 3}

      # Resolves to {:task, 1} which isn't a pane — FocusGroup stays on :sidebar
      assert {:hit, {:task, 1}, updated_fg} = HitTest.handle_click(hm, mouse, fg)
      assert updated_fg.active == :sidebar
    end

    test "click on pane switches focus from another pane" do
      hm =
        HitTest.new()
        |> HitTest.register(:left, {0, 0, 20, 30})
        |> HitTest.register(:right, {20, 0, 20, 30})

      fg = FocusGroup.new([:left, :right])
      assert fg.active == :left

      mouse = %Mouse{type: :click, button: :left, x: 25, y: 10}
      assert {:hit, :right, fg} = HitTest.handle_click(hm, mouse, fg)
      assert fg.active == :right

      # Click back to left
      mouse = %Mouse{type: :click, button: :left, x: 5, y: 10}
      assert {:hit, :left, fg} = HitTest.handle_click(hm, mouse, fg)
      assert fg.active == :left
    end
  end

  describe "clear/1" do
    test "removes all entries" do
      hm =
        HitTest.new()
        |> HitTest.register(:a, {0, 0, 10, 10})
        |> HitTest.register(:b, {10, 0, 10, 10})
        |> HitTest.clear()

      assert hm.entries == []
      assert HitTest.size(hm) == 0
    end
  end

  describe "realistic layout scenario" do
    test "IDE-like layout with nested task items" do
      # Simulate: sidebar (0-29), main (30-79), with task items in sidebar
      hm =
        HitTest.new()
        |> HitTest.register(:sidebar, {0, 0, 30, 25})
        |> HitTest.register(:main, {30, 0, 50, 25})
        |> HitTest.register({:task, 1}, {1, 1, 28, 2})
        |> HitTest.register({:task, 2}, {1, 3, 28, 2})
        |> HitTest.register({:task, 3}, {1, 5, 28, 2})

      fg = FocusGroup.new([:sidebar, :main])

      # Click on task 2 — deepest match is {:task, 2}
      assert HitTest.resolve(hm, 15, 4) == {:task, 2}

      # Click on sidebar but below tasks — just :sidebar
      assert HitTest.resolve(hm, 15, 20) == :sidebar

      # Click on main pane — :main
      mouse = %Mouse{type: :click, button: :left, x: 50, y: 12}
      assert {:hit, :main, fg} = HitTest.handle_click(hm, mouse, fg)
      assert fg.active == :main

      # Click on task in sidebar — resolves to task, focus stays on :main
      # because {:task, 2} isn't a FocusGroup pane
      mouse = %Mouse{type: :click, button: :left, x: 15, y: 4}
      assert {:hit, {:task, 2}, fg} = HitTest.handle_click(hm, mouse, fg)
      assert fg.active == :main
    end
  end
end
