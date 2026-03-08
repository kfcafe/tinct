defmodule Tinct.ElementTest do
  use ExUnit.Case, async: true

  alias Tinct.Element
  alias Tinct.Layout.Rect
  alias Tinct.Style

  # --- Rect tests ---

  describe "Rect.new/4" do
    test "creates a rect with given coordinates and dimensions" do
      rect = Rect.new(3, 7, 20, 10)
      assert rect.x == 3
      assert rect.y == 7
      assert rect.width == 20
      assert rect.height == 10
    end

    test "defaults are all zero" do
      rect = %Rect{}
      assert rect.x == 0
      assert rect.y == 0
      assert rect.width == 0
      assert rect.height == 0
    end
  end

  describe "Rect.contains?/3" do
    test "point inside the rect returns true" do
      rect = Rect.new(5, 5, 10, 10)
      assert Rect.contains?(rect, 10, 10)
    end

    test "origin point is inside (inclusive)" do
      rect = Rect.new(5, 5, 10, 10)
      assert Rect.contains?(rect, 5, 5)
    end

    test "far edge is outside (exclusive)" do
      rect = Rect.new(5, 5, 10, 10)
      refute Rect.contains?(rect, 15, 5)
      refute Rect.contains?(rect, 5, 15)
      refute Rect.contains?(rect, 15, 15)
    end

    test "point outside to the left" do
      rect = Rect.new(5, 5, 10, 10)
      refute Rect.contains?(rect, 4, 10)
    end

    test "point outside above" do
      rect = Rect.new(5, 5, 10, 10)
      refute Rect.contains?(rect, 10, 4)
    end

    test "empty rect contains nothing" do
      rect = Rect.new(5, 5, 0, 0)
      refute Rect.contains?(rect, 5, 5)
    end
  end

  describe "Rect.intersect/2" do
    test "overlapping rects return intersection" do
      a = Rect.new(0, 0, 10, 10)
      b = Rect.new(5, 5, 10, 10)
      result = Rect.intersect(a, b)
      assert result == Rect.new(5, 5, 5, 5)
    end

    test "non-overlapping rects return nil" do
      a = Rect.new(0, 0, 5, 5)
      b = Rect.new(10, 10, 5, 5)
      assert Rect.intersect(a, b) == nil
    end

    test "adjacent rects (touching edges) return nil" do
      a = Rect.new(0, 0, 5, 5)
      b = Rect.new(5, 0, 5, 5)
      assert Rect.intersect(a, b) == nil
    end

    test "one rect fully inside another" do
      outer = Rect.new(0, 0, 20, 20)
      inner = Rect.new(5, 5, 5, 5)
      assert Rect.intersect(outer, inner) == inner
    end

    test "partial horizontal overlap" do
      a = Rect.new(0, 0, 10, 5)
      b = Rect.new(3, 0, 10, 5)
      assert Rect.intersect(a, b) == Rect.new(3, 0, 7, 5)
    end

    test "intersection is commutative" do
      a = Rect.new(0, 0, 10, 10)
      b = Rect.new(5, 5, 10, 10)
      assert Rect.intersect(a, b) == Rect.intersect(b, a)
    end
  end

  describe "Rect.empty?/1" do
    test "zero width is empty" do
      assert Rect.empty?(Rect.new(0, 0, 0, 5))
    end

    test "zero height is empty" do
      assert Rect.empty?(Rect.new(0, 0, 5, 0))
    end

    test "both zero is empty" do
      assert Rect.empty?(Rect.new(3, 3, 0, 0))
    end

    test "positive dimensions is not empty" do
      refute Rect.empty?(Rect.new(0, 0, 1, 1))
    end
  end

  # --- Element builder tests ---

  describe "box/2" do
    test "creates a :box element" do
      el = Element.box()
      assert el.type == :box
      assert el.children == []
      assert el.style == %Style{}
    end

    test "applies style options" do
      el = Element.box(padding: 2)
      assert el.style.padding_top == 2
    end

    test "holds children" do
      child = Element.text("hi")
      el = Element.box([], [child])
      assert length(el.children) == 1
      assert hd(el.children).type == :text
    end
  end

  describe "row/2" do
    test "creates a :row element" do
      el = Element.row()
      assert el.type == :row
    end

    test "holds children" do
      el = Element.row([], [Element.text("a"), Element.text("b")])
      assert length(el.children) == 2
    end
  end

  describe "column/2" do
    test "creates a :column element" do
      el = Element.column()
      assert el.type == :column
    end

    test "holds children" do
      el = Element.column([], [Element.text("x")])
      assert length(el.children) == 1
    end
  end

  describe "text/1" do
    test "creates a :text element with content" do
      el = Element.text("hello")
      assert el.type == :text
      assert el.attrs.content == "hello"
      assert el.children == []
    end

    test "uses default style" do
      el = Element.text("hello")
      assert el.style == %Style{}
    end
  end

  describe "text/2" do
    test "creates a :text element with style overrides" do
      el = Element.text("hello", fg: :red, bold: true)
      assert el.type == :text
      assert el.attrs.content == "hello"
      assert el.style.fg == :red
      assert el.style.bold == true
    end

    test "preserves content and applies multiple style attrs" do
      el = Element.text("world", fg: :green, italic: true, underline: true)
      assert el.attrs.content == "world"
      assert el.style.fg == :green
      assert el.style.italic == true
      assert el.style.underline == true
    end
  end

  # --- Query function tests ---

  describe "text?/1" do
    test "returns true for text elements" do
      assert Element.text?(Element.text("hi"))
    end

    test "returns false for box elements" do
      refute Element.text?(Element.box())
    end

    test "returns false for row elements" do
      refute Element.text?(Element.row())
    end

    test "returns false for column elements" do
      refute Element.text?(Element.column())
    end
  end

  describe "container?/1" do
    test "returns true for box" do
      assert Element.container?(Element.box())
    end

    test "returns true for row" do
      assert Element.container?(Element.row())
    end

    test "returns true for column" do
      assert Element.container?(Element.column())
    end

    test "returns false for text" do
      refute Element.container?(Element.text("hi"))
    end
  end

  # --- Mutation function tests ---

  describe "add_child/2" do
    test "appends a child to empty container" do
      parent = Element.box()
      child = Element.text("new")
      updated = Element.add_child(parent, child)

      assert length(updated.children) == 1
      assert hd(updated.children).attrs.content == "new"
    end

    test "appends to existing children" do
      parent = Element.box([], [Element.text("first")])
      updated = Element.add_child(parent, Element.text("second"))

      assert length(updated.children) == 2
      contents = Enum.map(updated.children, & &1.attrs.content)
      assert contents == ["first", "second"]
    end

    test "preserves parent type and style" do
      parent = Element.row(fg: :blue)
      updated = Element.add_child(parent, Element.text("child"))

      assert updated.type == :row
      assert updated.style.fg == :blue
    end
  end

  describe "set_style/2" do
    test "merges style overrides into existing style" do
      el = Element.text("hi", fg: :blue)
      updated = Element.set_style(el, fg: :red, bold: true)

      assert updated.style.fg == :red
      assert updated.style.bold == true
    end

    test "preserves unset style fields" do
      el = Element.text("hi", fg: :blue, italic: true)
      updated = Element.set_style(el, bold: true)

      assert updated.style.fg == :blue
      assert updated.style.italic == true
      assert updated.style.bold == true
    end

    test "preserves element type and attrs" do
      el = Element.text("hi")
      updated = Element.set_style(el, fg: :red)

      assert updated.type == :text
      assert updated.attrs.content == "hi"
    end
  end

  # --- Nested tree tests ---

  describe "nested element trees" do
    test "column containing rows containing text" do
      tree =
        Element.column([], [
          Element.text("Header", fg: :green, bold: true),
          Element.row([], [
            Element.text("Left"),
            Element.text("Right")
          ]),
          Element.box([padding: 1], [
            Element.text("Footer")
          ])
        ])

      assert tree.type == :column
      assert length(tree.children) == 3

      [header, row, footer_box] = tree.children

      assert header.type == :text
      assert header.attrs.content == "Header"
      assert header.style.fg == :green

      assert row.type == :row
      assert length(row.children) == 2
      assert Enum.map(row.children, & &1.attrs.content) == ["Left", "Right"]

      assert footer_box.type == :box
      assert footer_box.style.padding_top == 1
      assert length(footer_box.children) == 1
      assert hd(footer_box.children).attrs.content == "Footer"
    end

    test "deeply nested tree" do
      tree =
        Element.column([], [
          Element.row([], [
            Element.column([], [
              Element.text("deep")
            ])
          ])
        ])

      deep_text =
        tree
        |> Map.get(:children)
        |> hd()
        |> Map.get(:children)
        |> hd()
        |> Map.get(:children)
        |> hd()

      assert deep_text.type == :text
      assert deep_text.attrs.content == "deep"
    end
  end

  # --- Doctest ---

  doctest Tinct.Layout.Rect
  doctest Tinct.Element
end
