defmodule Tinct.Widgets.BorderTest do
  use ExUnit.Case, async: true

  alias Tinct.{Element, Test}
  alias Tinct.Widgets.Border

  describe "init/1" do
    test "defaults to single border with no title or color" do
      model = Border.init([])
      assert model.style == :single
      assert model.title == nil
      assert model.color == nil
      assert model.children == []
    end

    test "accepts all options" do
      children = [Element.text("hi")]

      model =
        Border.init(style: :round, title: "Hello", color: :blue, children: children)

      assert model.style == :round
      assert model.title == "Hello"
      assert model.color == :blue
      assert model.children == children
    end
  end

  describe "update/2" do
    test "returns model unchanged" do
      model = Border.init(style: :single)
      assert Border.update(model, :any_msg) == model
    end
  end

  describe "rendering border styles" do
    test "renders single border corners and edges" do
      state = Test.render(Border, [style: :single], size: {10, 5})

      assert Test.cell_at(state, 0, 0).char == "┌"
      assert Test.cell_at(state, 9, 0).char == "┐"
      assert Test.cell_at(state, 0, 4).char == "└"
      assert Test.cell_at(state, 9, 4).char == "┘"
      assert Test.cell_at(state, 1, 0).char == "─"
      assert Test.cell_at(state, 0, 1).char == "│"
    end

    test "renders double border" do
      state = Test.render(Border, [style: :double], size: {10, 5})

      assert Test.cell_at(state, 0, 0).char == "╔"
      assert Test.cell_at(state, 9, 0).char == "╗"
      assert Test.cell_at(state, 0, 4).char == "╚"
      assert Test.cell_at(state, 9, 4).char == "╝"
      assert Test.cell_at(state, 1, 0).char == "═"
      assert Test.cell_at(state, 0, 1).char == "║"
    end

    test "renders round border" do
      state = Test.render(Border, [style: :round], size: {10, 5})

      assert Test.cell_at(state, 0, 0).char == "╭"
      assert Test.cell_at(state, 9, 0).char == "╮"
      assert Test.cell_at(state, 0, 4).char == "╰"
      assert Test.cell_at(state, 9, 4).char == "╯"
    end

    test "renders bold border" do
      state = Test.render(Border, [style: :bold], size: {10, 5})

      assert Test.cell_at(state, 0, 0).char == "┏"
      assert Test.cell_at(state, 9, 0).char == "┓"
      assert Test.cell_at(state, 0, 4).char == "┗"
      assert Test.cell_at(state, 9, 4).char == "┛"
      assert Test.cell_at(state, 1, 0).char == "━"
      assert Test.cell_at(state, 0, 1).char == "┃"
    end
  end

  describe "title" do
    test "title appears in top border" do
      state = Test.render(Border, [style: :single, title: "Hello"], size: {20, 5})
      line0 = Test.line(state, 0)
      assert line0 =~ "Hello"
    end

    test "title is positioned after corner with spaces" do
      state = Test.render(Border, [style: :single, title: "Hi"], size: {20, 5})

      # Format: ┌ Hi ───...─┐
      assert Test.cell_at(state, 0, 0).char == "┌"
      assert Test.cell_at(state, 1, 0).char == " "
      assert Test.cell_at(state, 2, 0).char == "H"
      assert Test.cell_at(state, 3, 0).char == "i"
      assert Test.cell_at(state, 4, 0).char == " "
      assert Test.cell_at(state, 5, 0).char == "─"
    end

    test "title truncates when too long for width" do
      long_title = String.duplicate("A", 100)
      state = Test.render(Border, [style: :single, title: long_title], size: {10, 5})
      # Width 10, max title length = 10 - 4 = 6
      line0 = Test.line(state, 0)
      assert line0 =~ String.duplicate("A", 6)
    end

    test "title not rendered when border too narrow" do
      state = Test.render(Border, [style: :single, title: "Hi"], size: {4, 3})
      line0 = Test.line(state, 0)
      refute line0 =~ "Hi"
    end
  end

  describe "children" do
    test "children render inside border area" do
      state =
        Test.render(
          Border,
          [style: :single, children: [Element.text("Hello")]],
          size: {20, 5}
        )

      # Text renders inside the border at row 1, col 1
      assert Test.cell_at(state, 1, 1).char == "H"
      assert Test.cell_at(state, 2, 1).char == "e"
      assert Test.cell_at(state, 3, 1).char == "l"
      assert Test.cell_at(state, 4, 1).char == "l"
      assert Test.cell_at(state, 5, 1).char == "o"
    end

    test "children do not overlap border" do
      state =
        Test.render(
          Border,
          [style: :single, children: [Element.text("Hello")]],
          size: {20, 5}
        )

      # Border corners still intact
      assert Test.cell_at(state, 0, 0).char == "┌"
      assert Test.cell_at(state, 19, 0).char == "┐"

      # Top border row does not contain child text
      line0 = Test.line(state, 0)
      refute line0 =~ "Hello"
    end
  end

  describe "border color" do
    test "color applies to border corners" do
      state = Test.render(Border, [style: :single, color: :blue], size: {10, 5})

      assert Test.cell_at(state, 0, 0).fg == :blue
      assert Test.cell_at(state, 9, 0).fg == :blue
      assert Test.cell_at(state, 0, 4).fg == :blue
      assert Test.cell_at(state, 9, 4).fg == :blue
    end

    test "color applies to border edges" do
      state = Test.render(Border, [style: :single, color: :blue], size: {10, 5})

      # Top edge
      assert Test.cell_at(state, 1, 0).fg == :blue
      # Left edge
      assert Test.cell_at(state, 0, 1).fg == :blue
      # Right edge
      assert Test.cell_at(state, 9, 1).fg == :blue
      # Bottom edge
      assert Test.cell_at(state, 1, 4).fg == :blue
    end

    test "color applies to title characters" do
      state =
        Test.render(
          Border,
          [style: :single, title: "Hi", color: :red],
          size: {20, 5}
        )

      assert Test.cell_at(state, 2, 0).fg == :red
      assert Test.cell_at(state, 3, 0).fg == :red
    end
  end

  describe "empty border" do
    test "renders border without children" do
      state = Test.render(Border, [style: :single], size: {10, 3})

      assert Test.cell_at(state, 0, 0).char == "┌"
      assert Test.cell_at(state, 9, 0).char == "┐"
      assert Test.cell_at(state, 0, 2).char == "└"
      assert Test.cell_at(state, 9, 2).char == "┘"

      # Interior is empty
      assert Test.cell_at(state, 1, 1).char == " "
    end
  end

  describe "element/2" do
    test "creates a bordered column element" do
      el = Border.element([], [])
      assert el.type == :column
      assert el.style.border == :single
      assert el.children == []
    end

    test "sets border style from opts" do
      el = Border.element([style: :round], [])
      assert el.style.border == :round
    end

    test "stores title in attrs" do
      el = Border.element([title: "Hello"], [])
      assert el.attrs.title == "Hello"
    end

    test "stores color as border_color in attrs" do
      el = Border.element([color: :green], [])
      assert el.attrs.border_color == :green
    end

    test "forwards non-border style options to element style" do
      el = Border.element([width: 20, height: 5, flex_grow: 1], [])
      assert el.style.border == :single
      assert el.style.width == 20
      assert el.style.height == 5
      assert el.style.flex_grow == 1
    end

    test "supports panel id and extra attrs" do
      el = Border.element([id: :list, attrs: %{role: :panel}], [])
      assert el.attrs.panel_id == :list
      assert el.attrs.role == :panel
    end

    test "includes children" do
      children = [Element.text("a"), Element.text("b")]
      el = Border.element([], children)
      assert length(el.children) == 2
    end

    test "empty attrs when no title or color" do
      el = Border.element([], [])
      assert el.attrs == %{}
    end
  end

  describe "UI DSL integration" do
    import Tinct.UI

    test "border macro creates bordered element" do
      el =
        border do
          text("inside")
        end

      assert el.type == :column
      assert el.style.border == :single
      assert length(el.children) == 1
    end

    test "border macro with options" do
      el =
        border title: "Test", style: :round do
          text("content")
        end

      assert el.style.border == :round
      assert el.attrs.title == "Test"
    end
  end
end
