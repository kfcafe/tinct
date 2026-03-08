defmodule Tinct.ViewTest do
  use ExUnit.Case, async: true

  alias Tinct.Cursor
  alias Tinct.Element
  alias Tinct.View

  doctest Tinct.Cursor
  doctest Tinct.View

  # --- Cursor ---

  describe "Cursor.new/2" do
    test "creates a block cursor at position with defaults" do
      cursor = Cursor.new(5, 10)

      assert cursor.x == 5
      assert cursor.y == 10
      assert cursor.shape == :block
      assert cursor.blink == false
      assert cursor.color == nil
      assert cursor.visible == true
    end

    test "creates a cursor at origin" do
      cursor = Cursor.new(0, 0)

      assert cursor.x == 0
      assert cursor.y == 0
    end
  end

  describe "Cursor.new/3" do
    test "creates a cursor with custom shape" do
      cursor = Cursor.new(1, 2, shape: :bar)

      assert cursor.shape == :bar
    end

    test "creates a cursor with underline shape" do
      cursor = Cursor.new(0, 0, shape: :underline)

      assert cursor.shape == :underline
    end

    test "creates a cursor with blink enabled" do
      cursor = Cursor.new(3, 4, blink: true)

      assert cursor.blink == true
    end

    test "creates a cursor with color" do
      cursor = Cursor.new(0, 0, color: :green)

      assert cursor.color == :green
    end

    test "creates a cursor with RGB color" do
      cursor = Cursor.new(0, 0, color: {:rgb, 255, 0, 128})

      assert cursor.color == {:rgb, 255, 0, 128}
    end

    test "creates a cursor with visibility disabled" do
      cursor = Cursor.new(0, 0, visible: false)

      assert cursor.visible == false
    end

    test "creates a cursor with multiple options" do
      cursor = Cursor.new(10, 20, shape: :bar, blink: true, color: :red)

      assert cursor.x == 10
      assert cursor.y == 20
      assert cursor.shape == :bar
      assert cursor.blink == true
      assert cursor.color == :red
      assert cursor.visible == true
    end
  end

  # --- View ---

  describe "View.new/1" do
    test "creates a view from an element tree" do
      tree = Element.text("hello")
      view = View.new(tree)

      assert view.content == tree
    end

    test "has sensible defaults" do
      view = View.new(Element.text("hi"))

      assert view.alt_screen == true
      assert view.bracketed_paste == true
      assert view.cursor == nil
      assert view.mouse_mode == nil
      assert view.title == nil
      assert view.report_focus == false
      assert view.keyboard_enhancements == []
    end
  end

  describe "View.new/2" do
    test "creates a view with alt_screen disabled" do
      view = View.new(Element.text("hi"), alt_screen: false)

      assert view.alt_screen == false
    end

    test "creates a view with a title" do
      view = View.new(Element.text("hi"), title: "My App")

      assert view.title == "My App"
    end

    test "creates a view with mouse mode" do
      view = View.new(Element.text("hi"), mouse_mode: :cell_motion)

      assert view.mouse_mode == :cell_motion
    end

    test "creates a view with all_motion mouse mode" do
      view = View.new(Element.text("hi"), mouse_mode: :all_motion)

      assert view.mouse_mode == :all_motion
    end

    test "creates a view with cursor" do
      cursor = Cursor.new(5, 3, shape: :bar)
      view = View.new(Element.text("hi"), cursor: cursor)

      assert view.cursor == cursor
    end

    test "creates a view with report_focus enabled" do
      view = View.new(Element.text("hi"), report_focus: true)

      assert view.report_focus == true
    end

    test "creates a view with bracketed_paste disabled" do
      view = View.new(Element.text("hi"), bracketed_paste: false)

      assert view.bracketed_paste == false
    end

    test "creates a view with keyboard enhancements" do
      view = View.new(Element.text("hi"), keyboard_enhancements: [:disambiguate_escape_codes])

      assert view.keyboard_enhancements == [:disambiguate_escape_codes]
    end

    test "creates a view with multiple options" do
      tree = Element.text("content")

      view =
        View.new(tree,
          alt_screen: false,
          title: "Test",
          mouse_mode: :all_motion,
          report_focus: true
        )

      assert view.content == tree
      assert view.alt_screen == false
      assert view.title == "Test"
      assert view.mouse_mode == :all_motion
      assert view.report_focus == true
      # defaults preserved
      assert view.bracketed_paste == true
      assert view.keyboard_enhancements == []
    end
  end

  describe "View.set_content/2" do
    test "updates the element tree" do
      old_tree = Element.text("old")
      new_tree = Element.text("new")
      view = View.new(old_tree)

      updated = View.set_content(view, new_tree)

      assert updated.content == new_tree
    end

    test "preserves other view fields" do
      view = View.new(Element.text("old"), title: "App", alt_screen: false)

      updated = View.set_content(view, Element.text("new"))

      assert updated.title == "App"
      assert updated.alt_screen == false
    end
  end

  describe "View.set_cursor/2" do
    test "sets a cursor" do
      view = View.new(Element.text("hi"))
      cursor = Cursor.new(5, 3)

      updated = View.set_cursor(view, cursor)

      assert updated.cursor == cursor
    end

    test "hides cursor with nil" do
      cursor = Cursor.new(5, 3)
      view = View.new(Element.text("hi"), cursor: cursor)

      updated = View.set_cursor(view, nil)

      assert updated.cursor == nil
    end

    test "preserves other view fields" do
      view = View.new(Element.text("hi"), title: "App")

      updated = View.set_cursor(view, Cursor.new(0, 0))

      assert updated.title == "App"
      assert updated.content == view.content
    end
  end

  describe "View.fullscreen/1" do
    test "sets alt_screen to true" do
      view = View.new(Element.text("hi"), alt_screen: false)

      assert View.fullscreen(view).alt_screen == true
    end

    test "is a no-op when already fullscreen" do
      view = View.new(Element.text("hi"))

      assert View.fullscreen(view).alt_screen == true
    end
  end

  describe "View.inline/1" do
    test "sets alt_screen to false" do
      view = View.new(Element.text("hi"))

      assert View.inline(view).alt_screen == false
    end

    test "is a no-op when already inline" do
      view = View.new(Element.text("hi"), alt_screen: false)

      assert View.inline(view).alt_screen == false
    end
  end
end
