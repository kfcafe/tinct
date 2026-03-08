defmodule Tinct.Widgets.RichTextTest do
  use ExUnit.Case, async: true

  alias Tinct.{Buffer, Element, Layout}

  describe "Element.rich/1 builder" do
    test "creates a :rich_text element with spans" do
      el = Element.rich([{"hello ", []}, {"world", [fg: :red]}])

      assert el.type == :rich_text
      assert length(el.attrs.spans) == 2
      assert el.children == []
    end

    test "creates a rich text element with 3+ differently-styled spans" do
      el =
        Element.rich([
          {"Task ", []},
          {"deploy-api", [fg: :cyan, bold: true]},
          {" failed", [fg: :red]}
        ])

      assert el.type == :rich_text
      assert length(el.attrs.spans) == 3

      [{s1, o1}, {s2, o2}, {s3, o3}] = el.attrs.spans
      assert s1 == "Task "
      assert o1 == []
      assert s2 == "deploy-api"
      assert o2 == [fg: :cyan, bold: true]
      assert s3 == " failed"
      assert o3 == [fg: :red]
    end

    test "preserves empty style lists" do
      el = Element.rich([{"plain", []}])
      [{_content, opts}] = el.attrs.spans
      assert opts == []
    end
  end

  describe "Element.rich/2 builder with element-level style" do
    test "applies layout style to the element" do
      el = Element.rich([{"hi", []}], flex_grow: 1)

      assert el.type == :rich_text
      assert el.style.flex_grow == 1
    end
  end

  describe "Element.rich_text?/1" do
    test "returns true for rich text elements" do
      assert Element.rich_text?(Element.rich([{"hi", []}]))
    end

    test "returns false for plain text elements" do
      refute Element.rich_text?(Element.text("hi"))
    end

    test "returns false for containers" do
      refute Element.rich_text?(Element.box())
    end
  end

  describe "rendering rich text to buffer" do
    test "renders each span with correct characters" do
      el = Element.rich([{"ab", []}, {"cd", []}])
      buf = Layout.render(el, {10, 1})

      assert Buffer.get(buf, 0, 0).char == "a"
      assert Buffer.get(buf, 1, 0).char == "b"
      assert Buffer.get(buf, 2, 0).char == "c"
      assert Buffer.get(buf, 3, 0).char == "d"
    end

    test "each span carries independent styles" do
      el =
        Element.rich([
          {"R", [fg: :red]},
          {"G", [fg: :green, bold: true]},
          {"B", [fg: :blue, italic: true]}
        ])

      buf = Layout.render(el, {10, 1})

      r_cell = Buffer.get(buf, 0, 0)
      assert r_cell.char == "R"
      assert r_cell.fg == :red
      assert r_cell.bold == false

      g_cell = Buffer.get(buf, 1, 0)
      assert g_cell.char == "G"
      assert g_cell.fg == :green
      assert g_cell.bold == true

      b_cell = Buffer.get(buf, 2, 0)
      assert b_cell.char == "B"
      assert b_cell.fg == :blue
      assert b_cell.italic == true
      assert b_cell.bold == false
    end

    test "renders correctly with 3+ differently-styled spans" do
      el =
        Element.rich([
          {"Task ", []},
          {"deploy-api", [fg: :cyan, bold: true]},
          {" failed", [fg: :red]}
        ])

      buf = Layout.render(el, {30, 1})

      # "Task " (5 chars) — default style
      assert Buffer.get(buf, 0, 0).char == "T"
      assert Buffer.get(buf, 4, 0).char == " "
      assert Buffer.get(buf, 0, 0).fg == :default
      assert Buffer.get(buf, 0, 0).bold == false

      # "deploy-api" (10 chars) — cyan, bold
      assert Buffer.get(buf, 5, 0).char == "d"
      assert Buffer.get(buf, 14, 0).char == "i"
      assert Buffer.get(buf, 5, 0).fg == :cyan
      assert Buffer.get(buf, 5, 0).bold == true
      assert Buffer.get(buf, 14, 0).fg == :cyan
      assert Buffer.get(buf, 14, 0).bold == true

      # " failed" (7 chars) — red
      assert Buffer.get(buf, 15, 0).char == " "
      assert Buffer.get(buf, 16, 0).char == "f"
      assert Buffer.get(buf, 21, 0).char == "d"
      assert Buffer.get(buf, 16, 0).fg == :red
      assert Buffer.get(buf, 16, 0).bold == false
    end
  end

  describe "intrinsic width calculation" do
    test "intrinsic width is sum of span grapheme lengths" do
      # "abc" (3) + "de" (2) = 5 total width
      el =
        Element.row([], [
          Element.rich([{"abc", []}, {"de", []}]),
          Element.text("X")
        ])

      buf = Layout.render(el, {20, 1})

      # Rich text starts at col 0, total width 5
      assert Buffer.get(buf, 0, 0).char == "a"
      assert Buffer.get(buf, 4, 0).char == "e"
      # "X" should start at col 5
      assert Buffer.get(buf, 5, 0).char == "X"
    end

    test "empty spans contribute zero width" do
      el =
        Element.row([], [
          Element.rich([{"", []}, {"hi", []}]),
          Element.text("!")
        ])

      buf = Layout.render(el, {20, 1})

      assert Buffer.get(buf, 0, 0).char == "h"
      assert Buffer.get(buf, 1, 0).char == "i"
      assert Buffer.get(buf, 2, 0).char == "!"
    end
  end

  describe "rich text inside containers" do
    test "works inside a column" do
      el =
        Element.column([], [
          Element.rich([{"hello", [fg: :green]}]),
          Element.text("world")
        ])

      buf = Layout.render(el, {20, 5})

      # Rich text on row 0
      assert Buffer.get(buf, 0, 0).char == "h"
      assert Buffer.get(buf, 0, 0).fg == :green

      # Plain text on row 1
      assert Buffer.get(buf, 0, 1).char == "w"
    end

    test "works inside a row" do
      el =
        Element.row([], [
          Element.text("A"),
          Element.rich([{"B", [fg: :red]}, {"C", [fg: :blue]}])
        ])

      buf = Layout.render(el, {20, 1})

      assert Buffer.get(buf, 0, 0).char == "A"
      assert Buffer.get(buf, 1, 0).char == "B"
      assert Buffer.get(buf, 1, 0).fg == :red
      assert Buffer.get(buf, 2, 0).char == "C"
      assert Buffer.get(buf, 2, 0).fg == :blue
    end

    test "works inside a box with padding" do
      el =
        Element.box([padding: 1], [
          Element.rich([{"XY", [fg: :yellow]}])
        ])

      buf = Layout.render(el, {10, 5})

      # Padding of 1 pushes content to col 1, row 1
      assert Buffer.get(buf, 1, 1).char == "X"
      assert Buffer.get(buf, 1, 1).fg == :yellow
      assert Buffer.get(buf, 2, 1).char == "Y"
      assert Buffer.get(buf, 2, 1).fg == :yellow
    end

    test "works inside a bordered container" do
      el =
        Element.box([border: :single, flex_grow: 1], [
          Element.rich([{"Z", [fg: :magenta]}])
        ])

      buf = Layout.render(el, {6, 4})

      # Border takes row 0, content at row 1, col 1
      assert Buffer.get(buf, 0, 0).char == "┌"
      assert Buffer.get(buf, 1, 1).char == "Z"
      assert Buffer.get(buf, 1, 1).fg == :magenta
    end
  end

  describe "backward compatibility" do
    test "existing text elements are unchanged" do
      el = Element.text("hello", fg: :red, bold: true)

      assert el.type == :text
      assert el.attrs.content == "hello"
      assert el.style.fg == :red
      assert el.style.bold == true
    end

    test "existing text rendering is unchanged" do
      el = Element.text("hi", fg: :blue)
      buf = Layout.render(el, {10, 1})

      assert Buffer.get(buf, 0, 0).char == "h"
      assert Buffer.get(buf, 0, 0).fg == :blue
      assert Buffer.get(buf, 1, 0).char == "i"
      assert Buffer.get(buf, 1, 0).fg == :blue
    end
  end

  describe "edge cases" do
    test "truncates spans that exceed rect width" do
      el = Element.rich([{"abcdef", []}])
      buf = Layout.render(el, {3, 1})

      assert Buffer.get(buf, 0, 0).char == "a"
      assert Buffer.get(buf, 1, 0).char == "b"
      assert Buffer.get(buf, 2, 0).char == "c"
      # Should not overflow
    end

    test "single empty span list creates valid element" do
      el = Element.rich([])
      assert el.type == :rich_text
      assert el.attrs.spans == []
    end

    test "renders empty spans without crashing" do
      el = Element.rich([])
      buf = Layout.render(el, {10, 1})

      # All cells should be default spaces
      assert Buffer.get(buf, 0, 0).char == " "
    end
  end
end
