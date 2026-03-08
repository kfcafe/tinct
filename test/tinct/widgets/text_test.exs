defmodule Tinct.Widgets.TextTest do
  use ExUnit.Case, async: true

  alias Tinct.{Style, View}
  alias Tinct.Test, as: T
  alias Tinct.Widgets.Text

  doctest Tinct.Widgets.Text

  # --- Component: init ---

  describe "init/1" do
    test "initializes with default values" do
      model = Text.init([])
      assert model.content == ""
      assert model.style == %Style{}
      assert model.wrap == :wrap
      assert model.align == :left
    end

    test "accepts custom content" do
      model = Text.init(content: "Hello")
      assert model.content == "Hello"
    end

    test "accepts custom style" do
      style = Style.new(fg: :red, bold: true)
      model = Text.init(style: style)
      assert model.style == style
    end

    test "accepts custom wrap mode" do
      model = Text.init(wrap: :truncate)
      assert model.wrap == :truncate
    end

    test "accepts custom alignment" do
      model = Text.init(align: :center)
      assert model.align == :center
    end
  end

  # --- Component: update ---

  describe "update/2" do
    test "set_content updates the content" do
      model = Text.init(content: "old")
      updated = Text.update(model, {:set_content, "new"})
      assert updated.content == "new"
    end

    test "ignores unknown messages" do
      model = Text.init(content: "hello")
      assert Text.update(model, :unknown) == model
    end
  end

  # --- Component: view ---

  describe "view/1" do
    test "simple text renders correctly" do
      state = T.render(Text, content: "Hello, world!")
      assert T.contains?(state, "Hello, world!")
    end

    test "multi-line text splits into lines" do
      state = T.render(Text, content: "line 1\nline 2")
      assert T.line(state, 0) == "line 1"
      assert T.line(state, 1) == "line 2"
    end

    test "re-wraps content when rendered at a narrower size" do
      wide = T.render(Text, [content: "one two three four"], size: {40, 4})
      assert T.line(wide, 0) == "one two three four"

      narrow = T.render(Text, [content: "one two three four"], size: {8, 4})
      assert T.line(narrow, 0) == "one two"
      assert T.line(narrow, 1) == "three"
      assert T.line(narrow, 2) == "four"
    end

    test "empty text renders as empty" do
      state = T.render(Text, content: "")
      assert T.line(state, 0) == ""
    end

    test "view returns a View struct" do
      model = Text.init(content: "test")
      view = Text.view(model)
      assert %View{} = view
    end

    test "styled text creates elements with the given style" do
      style = Style.new(fg: :red, bold: true)
      model = Text.init(content: "styled", style: style)
      view = Text.view(model)
      assert view.content.style == style
    end
  end

  # --- render_text/3: wrapping ---

  describe "render_text/3 wrapping" do
    test "short text fits in one line" do
      assert Text.render_text("hello", 10) == ["hello"]
    end

    test "long text wraps at word boundaries" do
      assert Text.render_text("hello world", 8) == ["hello", "world"]
    end

    test "wraps multiple words across lines" do
      assert Text.render_text("one two three four", 10) == ["one two", "three four"]
    end

    test "breaks long words that exceed width" do
      assert Text.render_text("superlongword", 5) == ["super", "longw", "ord"]
    end

    test "handles empty string" do
      assert Text.render_text("", 10) == [""]
    end

    test "handles width of zero" do
      assert Text.render_text("hello", 0) == []
    end

    test "multi-line content preserves line breaks" do
      assert Text.render_text("line one\nline two", 20) == ["line one", "line two"]
    end

    test "multi-line content wraps within each line" do
      assert Text.render_text("hello world\nfoo bar baz", 8) == [
               "hello",
               "world",
               "foo bar",
               "baz"
             ]
    end

    test "preserves empty lines in multi-line content" do
      assert Text.render_text("hello\n\nworld", 10) == ["hello", "", "world"]
    end
  end

  # --- render_text/3: truncation ---

  describe "render_text/3 truncation" do
    test "truncate_end adds ellipsis at end" do
      assert Text.render_text("hello world", 8, wrap: :truncate) == ["hello w…"]
    end

    test "truncate is an alias for truncate_end" do
      assert Text.render_text("hello world", 8, wrap: :truncate) ==
               Text.render_text("hello world", 8, wrap: :truncate_end)
    end

    test "truncate_start adds ellipsis at start" do
      assert Text.render_text("hello world", 8, wrap: :truncate_start) == ["…o world"]
    end

    test "truncate_middle adds ellipsis in middle" do
      # left_len = div(7, 2) = 3, right_len = 7 - 3 = 4
      assert Text.render_text("hello world", 8, wrap: :truncate_middle) == ["hel…orld"]
    end

    test "no truncation when text fits" do
      assert Text.render_text("hello", 10, wrap: :truncate) == ["hello"]
      assert Text.render_text("hello", 10, wrap: :truncate_start) == ["hello"]
      assert Text.render_text("hello", 10, wrap: :truncate_middle) == ["hello"]
    end

    test "truncation with multi-line truncates each line" do
      assert Text.render_text("hello world\nfoo bar baz", 8, wrap: :truncate) == [
               "hello w…",
               "foo bar…"
             ]
    end

    test "truncate to width 1 shows only ellipsis" do
      assert Text.render_text("hello", 1, wrap: :truncate) == ["…"]
      assert Text.render_text("hello", 1, wrap: :truncate_start) == ["…"]
      assert Text.render_text("hello", 1, wrap: :truncate_middle) == ["…"]
    end
  end

  # --- render_text/3: alignment ---

  describe "render_text/3 alignment" do
    test "left alignment is default (no padding)" do
      assert Text.render_text("hi", 10, align: :left) == ["hi"]
    end

    test "center alignment adds left padding" do
      # padding = 8, left_pad = 4
      assert Text.render_text("hi", 10, align: :center) == ["    hi"]
    end

    test "right alignment adds full left padding" do
      # padding = 8
      assert Text.render_text("hi", 10, align: :right) == ["        hi"]
    end

    test "alignment with text that fills width adds no padding" do
      assert Text.render_text("1234567890", 10, align: :center) == ["1234567890"]
      assert Text.render_text("1234567890", 10, align: :right) == ["1234567890"]
    end

    test "alignment works with multi-line text" do
      assert Text.render_text("hi\nbye", 10, align: :center) == ["    hi", "   bye"]
    end
  end
end
