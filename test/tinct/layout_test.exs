defmodule Tinct.LayoutTest do
  use ExUnit.Case, async: true

  alias Tinct.{Buffer, Element, Layout, Theme}

  describe "render/2 with text elements" do
    test "simple text renders at correct position" do
      el = Element.text("Hi")
      buf = Layout.render(el, {10, 3})

      assert Buffer.get(buf, 0, 0).char == "H"
      assert Buffer.get(buf, 1, 0).char == "i"
      assert Buffer.get(buf, 2, 0).char == " "
    end

    test "text with default theme via render/2" do
      el = Element.text("ok")
      buf = Layout.render(el, {5, 1})

      assert Buffer.get(buf, 0, 0).char == "o"
      assert Buffer.get(buf, 1, 0).char == "k"
    end
  end

  describe "resolve/2" do
    test "returns positioned rectangles for tagged elements" do
      tree =
        Element.column([], [
          %Element{type: :box, style: Tinct.Style.new(), attrs: %{panel_id: :a}},
          %Element{type: :box, style: Tinct.Style.new(), attrs: %{panel_id: :b}}
        ])

      resolved = Layout.resolve(tree, {20, 10})

      rects =
        resolved
        |> Enum.reduce(%{}, fn {el, rect}, acc ->
          case Map.get(el.attrs, :panel_id) do
            nil -> acc
            id -> Map.put(acc, id, rect)
          end
        end)

      assert Map.has_key?(rects, :a)
      assert Map.has_key?(rects, :b)
      assert rects.a.width > 0
      assert rects.b.width > 0
    end
  end

  describe "render/3 with column layout" do
    test "second text appears below first" do
      el =
        Element.column([], [
          Element.text("hello"),
          Element.text("world")
        ])

      buf = Layout.render(el, {20, 10})

      # First text at row 0
      assert Buffer.get(buf, 0, 0).char == "h"
      assert Buffer.get(buf, 4, 0).char == "o"

      # Second text at row 1
      assert Buffer.get(buf, 0, 1).char == "w"
      assert Buffer.get(buf, 4, 1).char == "d"
    end
  end

  describe "render/3 with row layout" do
    test "second text appears to the right" do
      el =
        Element.row([], [
          Element.text("ab"),
          Element.text("cd")
        ])

      buf = Layout.render(el, {20, 5})

      # "ab" starts at column 0
      assert Buffer.get(buf, 0, 0).char == "a"
      assert Buffer.get(buf, 1, 0).char == "b"

      # "cd" starts at column 2 (after "ab")
      assert Buffer.get(buf, 2, 0).char == "c"
      assert Buffer.get(buf, 3, 0).char == "d"
    end
  end

  describe "render/3 with borders" do
    test "bordered element has border characters and content inside" do
      el =
        Element.box([border: :single, flex_grow: 1], [
          Element.text("X")
        ])

      buf = Layout.render(el, {6, 4})

      # Corners
      assert Buffer.get(buf, 0, 0).char == "┌"
      assert Buffer.get(buf, 5, 0).char == "┐"
      assert Buffer.get(buf, 0, 3).char == "└"
      assert Buffer.get(buf, 5, 3).char == "┘"

      # Top edge
      assert Buffer.get(buf, 1, 0).char == "─"

      # Left edge
      assert Buffer.get(buf, 0, 1).char == "│"

      # Content inside border (positioned by flex with padding)
      assert Buffer.get(buf, 1, 1).char == "X"
    end

    test "round border style renders correct characters" do
      el = Element.box([border: :round], [])
      buf = Layout.render(el, {4, 3})

      assert Buffer.get(buf, 0, 0).char == "╭"
      assert Buffer.get(buf, 3, 0).char == "╮"
      assert Buffer.get(buf, 0, 2).char == "╰"
      assert Buffer.get(buf, 3, 2).char == "╯"
    end
  end

  describe "render/3 with nested layout" do
    test "column with bordered row inside" do
      el =
        Element.column([], [
          Element.text("title"),
          Element.row([border: :single, flex_grow: 1], [
            Element.text("a"),
            Element.text("b")
          ])
        ])

      buf = Layout.render(el, {20, 6})

      # Title at row 0
      assert Buffer.get(buf, 0, 0).char == "t"

      # Bordered row starts at row 1 (text takes row 0)
      # Top-left corner of bordered row
      assert Buffer.get(buf, 0, 1).char == "┌"
      # Content inside the border
      assert Buffer.get(buf, 1, 2).char == "a"
      assert Buffer.get(buf, 2, 2).char == "b"
    end
  end

  describe "text wrapping" do
    test "long text wraps at word boundaries" do
      el = Element.text("hello world")
      buf = Layout.render(el, {7, 5})

      # "hello" on first line
      assert Buffer.get(buf, 0, 0).char == "h"
      assert Buffer.get(buf, 4, 0).char == "o"

      # "world" on second line
      assert Buffer.get(buf, 0, 1).char == "w"
      assert Buffer.get(buf, 4, 1).char == "d"
    end

    test "word longer than width is broken" do
      el = Element.text("abcdef")
      buf = Layout.render(el, {3, 5})

      # "abc" on first line
      assert Buffer.get(buf, 0, 0).char == "a"
      assert Buffer.get(buf, 2, 0).char == "c"

      # "def" on second line
      assert Buffer.get(buf, 0, 1).char == "d"
      assert Buffer.get(buf, 2, 1).char == "f"
    end
  end

  describe "text truncation" do
    test "text beyond rect height is not rendered" do
      # Three wrapped lines, but only 2 rows of height
      el = Element.text("aa bb cc")

      # In a column, text gets height 1 by default (base_size for text in column = 1)
      # Use a direct render at small dimensions instead
      buf = Layout.render(el, {3, 2})

      # "aa" on row 0
      assert Buffer.get(buf, 0, 0).char == "a"
      assert Buffer.get(buf, 1, 0).char == "a"

      # "bb" on row 1
      assert Buffer.get(buf, 0, 1).char == "b"
      assert Buffer.get(buf, 1, 1).char == "b"

      # "cc" would be row 2 but it doesn't exist — buffer only has 2 rows
      # Buffer.get returns a default cell for out-of-bounds
      assert Buffer.get(buf, 0, 2).char == " "
    end
  end

  describe "style application" do
    test "colored text has correct cell styles" do
      el = Element.text("hi", fg: :red, bold: true)
      buf = Layout.render(el, {10, 1})

      cell = Buffer.get(buf, 0, 0)
      assert cell.char == "h"
      assert cell.fg == :red
      assert cell.bold == true

      cell = Buffer.get(buf, 1, 0)
      assert cell.char == "i"
      assert cell.fg == :red
      assert cell.bold == true
    end

    test "resolved style fills defaults for unset attributes" do
      el = Element.text("x", fg: :blue)
      buf = Layout.render(el, {5, 1})

      cell = Buffer.get(buf, 0, 0)
      assert cell.fg == :blue
      assert cell.bg == :default
      assert cell.bold == false
      assert cell.italic == false
    end
  end

  describe "render/3 with explicit theme" do
    test "render with custom theme compiles and runs" do
      theme = Theme.new(:custom, %{heading: Tinct.Style.new(fg: :cyan, bold: true)})
      el = Element.text("test")
      buf = Layout.render(el, {10, 1}, theme)

      assert Buffer.get(buf, 0, 0).char == "t"
    end
  end

  describe "render/2 with rich text elements" do
    test "renders spans sequentially with per-span styling" do
      el = Element.rich([{"hi", [fg: :red, bold: true]}, {"!", []}])
      buf = Layout.render(el, {10, 1})

      h = Buffer.get(buf, 0, 0)
      assert h.char == "h"
      assert h.fg == :red
      assert h.bold == true

      i = Buffer.get(buf, 1, 0)
      assert i.char == "i"
      assert i.fg == :red
      assert i.bold == true

      exclam = Buffer.get(buf, 2, 0)
      assert exclam.char == "!"
      assert exclam.fg == :default
    end

    test "truncates rich text to the available width" do
      el = Element.rich([{"hello", []}])
      buf = Layout.render(el, {3, 1})

      assert Buffer.get(buf, 0, 0).char == "h"
      assert Buffer.get(buf, 1, 0).char == "e"
      assert Buffer.get(buf, 2, 0).char == "l"
    end

    test "rich text renders safely when width is zero" do
      el = Element.rich([{"x", []}])
      buf = Layout.render(el, {0, 1})

      assert buf.width == 0
      assert buf.height == 1
    end

    test "rich text renders safely when height is zero" do
      el = Element.rich([{"x", []}])
      buf = Layout.render(el, {5, 0})

      assert buf.width == 5
      assert buf.height == 0
    end
  end

  describe "wrap_text/2" do
    test "empty string returns single empty line" do
      assert Layout.wrap_text("", 10) == [""]
    end

    test "short text stays on one line" do
      assert Layout.wrap_text("hello", 10) == ["hello"]
    end

    test "wraps at word boundaries" do
      assert Layout.wrap_text("hello world", 7) == ["hello", "world"]
    end

    test "width zero returns empty list" do
      assert Layout.wrap_text("hello", 0) == []
    end

    test "multiple words fit on one line" do
      assert Layout.wrap_text("a b c", 10) == ["a b c"]
    end

    test "breaks long words at width" do
      assert Layout.wrap_text("abcdef", 3) == ["abc", "def"]
    end
  end
end
