defmodule Tinct.Widgets.ScrollViewTest do
  use ExUnit.Case, async: true

  alias Tinct.Element
  alias Tinct.Event
  alias Tinct.Test, as: T
  alias Tinct.Widgets.ScrollView

  doctest Tinct.Widgets.ScrollView

  defp lines(n) when is_integer(n) and n >= 0 do
    Enum.map(1..n, fn i -> Element.text("Line #{i}") end)
  end

  describe "view/1" do
    test "content fits in viewport: no scrolling needed, no scrollbar" do
      state = T.render(ScrollView, children: lines(3), width: 10, height: 3, size: {10, 3})

      assert T.line(state, 0) =~ ~r/^Line 1/
      assert T.line(state, 1) =~ ~r/^Line 2/
      assert T.line(state, 2) =~ ~r/^Line 3/

      # Right edge should not be the scrollbar track/thumb.
      refute T.cell_at(state, 9, 0).char in ["│", "█"]

      state = T.send_key(state, :down)
      assert state.model.offset_y == 0
    end

    test "content taller than viewport: scrollbar appears" do
      state = T.render(ScrollView, children: lines(6), width: 10, height: 3, size: {10, 3})

      assert T.cell_at(state, 9, 0).char == "█"
      assert T.cell_at(state, 9, 1).char in ["│", "█"]
      assert T.cell_at(state, 9, 2).char in ["│", "█"]
    end

    test "scroll down shifts content up" do
      state = T.render(ScrollView, children: lines(6), width: 10, height: 3, size: {10, 3})
      assert T.line(state, 0) =~ ~r/^Line 1/

      state = T.send_key(state, :down)
      assert state.model.offset_y == 1
      assert T.line(state, 0) =~ ~r/^Line 2/

      state = T.send_event(state, %Event.Mouse{type: :wheel, button: :wheel_down, x: 0, y: 0})
      assert state.model.offset_y == 2
      assert T.line(state, 0) =~ ~r/^Line 3/
    end

    test "scroll up shifts content down" do
      state = T.render(ScrollView, children: lines(6), width: 10, height: 3, size: {10, 3})

      state = state |> T.send_key(:down) |> T.send_key(:down)
      assert state.model.offset_y == 2

      state = T.send_key(state, :up)
      assert state.model.offset_y == 1
      assert T.line(state, 0) =~ ~r/^Line 2/

      state = T.send_event(state, %Event.Mouse{type: :wheel, button: :wheel_up, x: 0, y: 0})
      assert state.model.offset_y == 0
      assert T.line(state, 0) =~ ~r/^Line 1/
    end

    test "scroll bounds: can't scroll past content edges" do
      state = T.render(ScrollView, children: lines(6), width: 10, height: 3, size: {10, 3})

      # max_y = 6 - 3 = 3
      state =
        state
        |> T.send_key(:down)
        |> T.send_key(:down)
        |> T.send_key(:down)
        |> T.send_key(:down)
        |> T.send_key(:down)

      assert state.model.offset_y == 3

      state = T.send_key(state, :down)
      assert state.model.offset_y == 3

      state =
        state
        |> T.send_key(:up)
        |> T.send_key(:up)
        |> T.send_key(:up)
        |> T.send_key(:up)

      assert state.model.offset_y == 0

      state = T.send_key(state, :up)
      assert state.model.offset_y == 0
    end
  end

  describe "public API" do
    test "scroll_to_top/1 and scroll_to_bottom/1 work" do
      model = ScrollView.init(children: lines(6), width: 10, height: 3)

      model = ScrollView.scroll_to_bottom(model)
      assert model.offset_y == 3

      model = ScrollView.scroll_to_top(model)
      assert model.offset_y == 0
    end

    test "scroll_to/2 clamps offsets, including horizontal" do
      model =
        ScrollView.init(
          children: [Element.text("abcdef")],
          width: 3,
          height: 1,
          show_scrollbar: false
        )

      model = ScrollView.scroll_to(model, {2, 0})
      assert model.offset_x == 2

      view = ScrollView.view(model)
      assert T.render_view(view, {3, 1}) == "cde"

      # Max x = 6 - 3 = 3, so 999 clamps to 3.
      model = ScrollView.scroll_to(model, {999, 0})
      assert model.offset_x == 3
    end
  end

  describe "page up/down" do
    test "page down jumps by viewport height and clamps" do
      state = T.render(ScrollView, children: lines(10), width: 10, height: 3, size: {10, 3})
      assert state.model.offset_y == 0

      state = T.send_key(state, :page_down)
      assert state.model.offset_y == 3

      state = T.send_key(state, :page_down)
      assert state.model.offset_y == 6

      # max_y = 10 - 3 = 7
      state = T.send_key(state, :page_down)
      assert state.model.offset_y == 7

      state = T.send_key(state, :page_down)
      assert state.model.offset_y == 7
    end

    test "page up jumps by viewport height and clamps" do
      state = T.render(ScrollView, children: lines(10), width: 10, height: 3, size: {10, 3})
      state = state |> T.send_key(:page_down) |> T.send_key(:page_down)
      assert state.model.offset_y == 6

      state = T.send_key(state, :page_up)
      assert state.model.offset_y == 3

      state = T.send_key(state, :page_up)
      assert state.model.offset_y == 0

      state = T.send_key(state, :page_up)
      assert state.model.offset_y == 0
    end
  end
end
