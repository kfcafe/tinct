defmodule Tinct.Layout.FlexTest do
  use ExUnit.Case, async: true

  alias Tinct.Element
  alias Tinct.Layout.Flex
  alias Tinct.Layout.Rect

  import Tinct.Element, only: [column: 2, row: 2, text: 1, box: 2]

  # Helper: find the rect for a given element in the result list
  defp rect_for(results, %Element{} = target) do
    {_el, rect} = Enum.find(results, fn {el, _rect} -> el == target end)
    rect
  end

  # Helper: find the rect for the first text element with given content
  defp text_rect(results, content) do
    {_el, rect} =
      Enum.find(results, fn
        {%Element{type: :text, attrs: %{content: c}}, _rect} -> c == content
        _ -> false
      end)

    rect
  end

  describe "single text child" do
    test "in column gets full width and height 1" do
      el = column([], [text("hello")])
      rect = Rect.new(0, 0, 10, 5)
      results = Flex.resolve(el, rect)

      child_rect = text_rect(results, "hello")
      assert child_rect == Rect.new(0, 0, 10, 1)
    end

    test "text element alone fills its rect" do
      el = text("hi")
      rect = Rect.new(3, 4, 8, 2)
      [{^el, result}] = Flex.resolve(el, rect)
      assert result == rect
    end
  end

  describe "two children in column" do
    test "stacked vertically" do
      el = column([], [text("first"), text("second")])
      rect = Rect.new(0, 0, 10, 5)
      results = Flex.resolve(el, rect)

      first = text_rect(results, "first")
      second = text_rect(results, "second")

      assert first == Rect.new(0, 0, 10, 1)
      assert second == Rect.new(0, 1, 10, 1)
    end
  end

  describe "two children in row" do
    test "side by side" do
      el = row([], [text("ab"), text("cd")])
      rect = Rect.new(0, 0, 10, 5)
      results = Flex.resolve(el, rect)

      first = text_rect(results, "ab")
      second = text_rect(results, "cd")

      assert first == Rect.new(0, 0, 2, 5)
      assert second == Rect.new(2, 0, 2, 5)
    end
  end

  describe "flex_grow" do
    test "child with grow 1 takes remaining space" do
      growing = box([flex_grow: 1], [])
      el = row([], [text("ab"), growing])
      rect = Rect.new(0, 0, 10, 5)
      results = Flex.resolve(el, rect)

      text_r = text_rect(results, "ab")
      grow_r = rect_for(results, growing)

      assert text_r == Rect.new(0, 0, 2, 5)
      assert grow_r == Rect.new(2, 0, 8, 5)
    end

    test "two children with grow 1 and 2 split space proportionally" do
      a = box([flex_grow: 1], [])
      b = box([flex_grow: 2], [])
      el = row([], [a, b])
      rect = Rect.new(0, 0, 9, 5)
      results = Flex.resolve(el, rect)

      a_rect = rect_for(results, a)
      b_rect = rect_for(results, b)

      # 9 / 3 = 3 per grow unit: a gets 3, b gets 6
      assert a_rect == Rect.new(0, 0, 3, 5)
      assert b_rect == Rect.new(3, 0, 6, 5)
    end
  end

  describe "gap" do
    test "children have gap between them" do
      el = row([gap: 2], [text("a"), text("b")])
      rect = Rect.new(0, 0, 10, 5)
      results = Flex.resolve(el, rect)

      a_rect = text_rect(results, "a")
      b_rect = text_rect(results, "b")

      assert a_rect == Rect.new(0, 0, 1, 5)
      # 1 (width of "a") + 2 (gap) = 3
      assert b_rect == Rect.new(3, 0, 1, 5)
    end
  end

  describe "fixed width child" do
    test "respects explicit width" do
      fixed = box([width: 5], [])
      el = row([], [text("ab"), fixed])
      rect = Rect.new(0, 0, 10, 5)
      results = Flex.resolve(el, rect)

      text_r = text_rect(results, "ab")
      fixed_r = rect_for(results, fixed)

      assert text_r == Rect.new(0, 0, 2, 5)
      assert fixed_r == Rect.new(2, 0, 5, 5)
    end
  end

  describe "justify_content" do
    test ":center positions children in the middle" do
      el = row([justify_content: :center], [text("ab")])
      rect = Rect.new(0, 0, 10, 5)
      results = Flex.resolve(el, rect)

      child = text_rect(results, "ab")
      # Free space = 10 - 2 = 8, offset = 4
      assert child == Rect.new(4, 0, 2, 5)
    end

    test ":space_between distributes evenly" do
      el = row([justify_content: :space_between], [text("a"), text("b"), text("c")])
      rect = Rect.new(0, 0, 10, 5)
      results = Flex.resolve(el, rect)

      a_rect = text_rect(results, "a")
      b_rect = text_rect(results, "b")
      c_rect = text_rect(results, "c")

      # Total used = 3 (1+1+1), free = 7, 2 gaps → 3 extra per gap, remainder 1 to first gap
      assert a_rect.x == 0
      assert b_rect.x == 5
      assert c_rect.x == 9
    end
  end

  describe "align_items" do
    test ":center centers on cross axis" do
      el = row([align_items: :center], [text("ab")])
      rect = Rect.new(0, 0, 10, 10)
      results = Flex.resolve(el, rect)

      child = text_rect(results, "ab")
      # Cross size = 10, text height = 1, offset = div(9, 2) = 4
      assert child == Rect.new(0, 4, 2, 1)
    end

    test ":end aligns to end of cross axis" do
      el = row([align_items: :end], [text("ab")])
      rect = Rect.new(0, 0, 10, 10)
      results = Flex.resolve(el, rect)

      child = text_rect(results, "ab")
      assert child == Rect.new(0, 9, 2, 1)
    end
  end

  describe "nested layout" do
    test "column containing a row" do
      inner_row = row([], [text("a"), text("b")])
      el = column([], [text("header"), inner_row])
      rect = Rect.new(0, 0, 10, 5)
      results = Flex.resolve(el, rect)

      header = text_rect(results, "header")
      assert header == Rect.new(0, 0, 10, 1)

      # Row gets base height 0 in column (no explicit height, not text)
      row_rect = rect_for(results, inner_row)
      assert row_rect.y == 1
      assert row_rect.width == 10

      # Children inside the row are positioned horizontally
      a_rect = text_rect(results, "a")
      b_rect = text_rect(results, "b")
      assert a_rect.y == row_rect.y
      assert b_rect.y == row_rect.y
      assert a_rect.x == 0
      assert b_rect.x == 1
    end

    test "column with flex_grow row fills remaining space" do
      inner_row = row([flex_grow: 1], [text("a"), text("b")])
      el = column([], [text("header"), inner_row])
      rect = Rect.new(0, 0, 10, 5)
      results = Flex.resolve(el, rect)

      row_rect = rect_for(results, inner_row)
      # header takes 1 row, row gets 4
      assert row_rect == Rect.new(0, 1, 10, 4)

      a_rect = text_rect(results, "a")
      b_rect = text_rect(results, "b")
      assert a_rect == Rect.new(0, 1, 1, 4)
      assert b_rect == Rect.new(1, 1, 1, 4)
    end
  end

  describe "padding" do
    test "reduces available space correctly" do
      el = column([padding: 2], [text("hi")])
      rect = Rect.new(0, 0, 10, 10)
      results = Flex.resolve(el, rect)

      # Container still gets the full rect
      container_rect = rect_for(results, el)
      assert container_rect == rect

      # Text gets the content area (reduced by padding)
      child = text_rect(results, "hi")
      assert child.x == 2
      assert child.y == 2
      assert child.width == 6
      assert child.height == 1
    end
  end

  describe "remainder distribution" do
    test "10 cols / 3 children → 4, 3, 3" do
      # Use different fg colors so elements are distinguishable by ==
      a = box([flex_grow: 1, fg: :red], [])
      b = box([flex_grow: 1, fg: :green], [])
      c = box([flex_grow: 1, fg: :blue], [])
      el = row([], [a, b, c])
      rect = Rect.new(0, 0, 10, 5)
      results = Flex.resolve(el, rect)

      a_rect = rect_for(results, a)
      b_rect = rect_for(results, b)
      c_rect = rect_for(results, c)

      assert a_rect.width == 4
      assert b_rect.width == 3
      assert c_rect.width == 3

      # Positions: 0, 4, 7
      assert a_rect.x == 0
      assert b_rect.x == 4
      assert c_rect.x == 7
    end

    test "no space is lost" do
      a = box([flex_grow: 1, fg: :red], [])
      b = box([flex_grow: 1, fg: :green], [])
      c = box([flex_grow: 1, fg: :blue], [])
      el = row([], [a, b, c])
      rect = Rect.new(0, 0, 10, 5)
      results = Flex.resolve(el, rect)

      a_rect = rect_for(results, a)
      b_rect = rect_for(results, b)
      c_rect = rect_for(results, c)

      assert a_rect.width + b_rect.width + c_rect.width == 10
    end
  end

  describe "empty container" do
    test "returns only the container itself" do
      el = column([], [])
      rect = Rect.new(0, 0, 10, 5)
      results = Flex.resolve(el, rect)

      assert results == [{el, rect}]
    end
  end

  doctest Tinct.Layout.Flex
end
