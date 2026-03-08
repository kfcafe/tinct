defmodule Tinct.UITest do
  use ExUnit.Case, async: true

  import Tinct.UI

  describe "text/1" do
    test "creates text element with content" do
      el = text("hello")
      assert %Tinct.Element{type: :text} = el
      assert el.attrs.content == "hello"
    end

    test "creates text with default style" do
      el = text("hello")
      assert el.style == %Tinct.Style{}
    end
  end

  describe "text/2" do
    test "creates text element with style options" do
      el = text("hello", fg: :red, bold: true)
      assert el.style.fg == :red
      assert el.style.bold == true
    end

    test "maps color: to fg:" do
      el = text("hello", color: :red)
      assert el.style.fg == :red
    end

    test "maps background: to bg:" do
      el = text("hello", background: :blue)
      assert el.style.bg == :blue
    end

    test "passes through standard style keys" do
      el = text("hello", bold: true, italic: true)
      assert el.style.bold == true
      assert el.style.italic == true
    end
  end

  describe "column/1" do
    test "collects children from do block" do
      el =
        column do
          text("A")
          text("B")
        end

      assert %Tinct.Element{type: :column} = el
      assert length(el.children) == 2
      assert Enum.at(el.children, 0).attrs.content == "A"
      assert Enum.at(el.children, 1).attrs.content == "B"
    end

    test "accepts style opts" do
      el =
        column padding: 1 do
          text("hello")
        end

      assert el.style.padding_top == 1
      assert el.style.padding_right == 1
      assert el.style.padding_bottom == 1
      assert el.style.padding_left == 1
      assert length(el.children) == 1
    end

    test "handles single child" do
      el =
        column do
          text("only")
        end

      assert length(el.children) == 1
      assert Enum.at(el.children, 0).attrs.content == "only"
    end
  end

  describe "row/1" do
    test "collects children from do block" do
      el =
        row do
          text("left")
          text("right")
        end

      assert %Tinct.Element{type: :row} = el
      assert length(el.children) == 2
    end

    test "accepts style opts" do
      el =
        row padding: 2 do
          text("hello")
        end

      assert el.style.padding_top == 2
    end
  end

  describe "box/1" do
    test "collects children from do block" do
      el =
        box do
          text("inside")
        end

      assert %Tinct.Element{type: :box} = el
      assert length(el.children) == 1
    end

    test "accepts style opts" do
      el =
        box padding: 1 do
          text("padded")
        end

      assert el.style.padding_top == 1
    end
  end

  describe "nesting" do
    test "column containing rows containing text" do
      el =
        column do
          text("header")

          row do
            text("A")
            text("B")
          end

          row do
            text("C")
            text("D")
          end
        end

      assert el.type == :column
      assert length(el.children) == 3

      header = Enum.at(el.children, 0)
      assert header.type == :text
      assert header.attrs.content == "header"

      row1 = Enum.at(el.children, 1)
      assert row1.type == :row
      assert length(row1.children) == 2
      assert Enum.at(row1.children, 0).attrs.content == "A"
      assert Enum.at(row1.children, 1).attrs.content == "B"

      row2 = Enum.at(el.children, 2)
      assert row2.type == :row
      assert length(row2.children) == 2
    end

    test "deeply nested structure" do
      el =
        column do
          box padding: 1 do
            row do
              text("deep")
            end
          end
        end

      assert el.type == :column
      box_el = Enum.at(el.children, 0)
      assert box_el.type == :box
      row_el = Enum.at(box_el.children, 0)
      assert row_el.type == :row
      text_el = Enum.at(row_el.children, 0)
      assert text_el.attrs.content == "deep"
    end
  end

  describe "view/1" do
    test "creates a View struct with single child" do
      v =
        view do
          text("hello")
        end

      assert %Tinct.View{} = v
      assert v.content.type == :text
      assert v.content.attrs.content == "hello"
    end

    test "wraps multiple children in a column" do
      v =
        view do
          text("A")
          text("B")
        end

      assert v.content.type == :column
      assert length(v.content.children) == 2
    end

    test "accepts view opts" do
      v =
        view alt_screen: false do
          text("inline")
        end

      assert v.alt_screen == false
      assert v.content.attrs.content == "inline"
    end

    test "defaults to alt_screen: true" do
      v =
        view do
          text("hello")
        end

      assert v.alt_screen == true
    end
  end

  describe "spacer/0" do
    test "creates a flex-grow element" do
      el = spacer()
      assert %Tinct.Element{type: :box} = el
      assert el.style.flex_grow == 1
      assert el.children == []
    end
  end

  describe "style sugar" do
    test "color: maps to fg:" do
      el = text("hello", color: :green)
      assert el.style.fg == :green
    end

    test "background: maps to bg:" do
      el = text("hello", background: :yellow)
      assert el.style.bg == :yellow
    end

    test "padding: 1 expands to all sides via Style" do
      el =
        column padding: 1 do
          text("hello")
        end

      assert el.style.padding_top == 1
      assert el.style.padding_right == 1
      assert el.style.padding_bottom == 1
      assert el.style.padding_left == 1
    end

    test "style sugar works in containers" do
      el =
        column color: :red do
          text("hello")
        end

      assert el.style.fg == :red
    end
  end

  describe "multiple children" do
    test "all children in a block are captured" do
      el =
        column do
          text("one")
          text("two")
          text("three")
          text("four")
        end

      assert length(el.children) == 4
      contents = Enum.map(el.children, & &1.attrs.content)
      assert contents == ["one", "two", "three", "four"]
    end
  end

  describe "keyword do-form macros" do
    test "column/1 supports do: keyword form" do
      el = column(do: text("keyword column"))
      assert el.type == :column
      assert [child] = el.children
      assert child.attrs.content == "keyword column"
    end

    test "column/1 supports explicit keyword-list argument" do
      el = column(do: text("keyword list column"), color: :cyan)
      assert el.type == :column
      assert el.style.fg == :cyan
      assert [child] = el.children
      assert child.attrs.content == "keyword list column"
    end

    test "row/1 supports do: keyword form" do
      el = row(do: text("keyword row"))
      assert el.type == :row
      assert [child] = el.children
      assert child.attrs.content == "keyword row"
    end

    test "row/1 supports explicit keyword-list argument" do
      el = row(do: text("keyword list row"), background: :black)
      assert el.type == :row
      assert el.style.bg == :black
      assert [child] = el.children
      assert child.attrs.content == "keyword list row"
    end

    test "box/1 supports do: keyword form" do
      el = box(do: text("keyword box"))
      assert el.type == :box
      assert [child] = el.children
      assert child.attrs.content == "keyword box"
    end

    test "box/1 supports explicit keyword-list argument" do
      el = box(do: text("keyword list box"), padding: 1)
      assert el.type == :box
      assert el.style.padding_top == 1
      assert [child] = el.children
      assert child.attrs.content == "keyword list box"
    end

    test "border/1 supports do: keyword form" do
      el = border(do: text("inside border"))
      assert el.type == :column
      assert [child] = el.children
      assert child.attrs.content == "inside border"
    end

    test "border/1 supports explicit keyword-list argument" do
      el = border(do: text("keyword list border"), title: "T")
      assert el.type == :column
      assert el.attrs.title == "T"
      assert [child] = el.children
      assert child.attrs.content == "keyword list border"
    end

    test "view/1 with opts and multiple children wraps in a column" do
      v =
        view(
          alt_screen: false,
          do:
            (
              text("one")
              text("two")
            )
        )

      assert v.alt_screen == false
      assert v.content.type == :column
      assert Enum.map(v.content.children, & &1.attrs.content) == ["one", "two"]
    end

    test "view/1 handles nil blocks as empty content" do
      v = view(do: nil)
      assert v.content.type == :column
      assert v.content.children == []
    end
  end
end
