defmodule Tinct.StyleTest do
  use ExUnit.Case, async: true

  alias Tinct.Buffer.Cell
  alias Tinct.Style

  doctest Tinct.Style

  describe "new/0" do
    test "creates an empty style with nil visual attributes" do
      style = Style.new()

      assert style.fg == nil
      assert style.bg == nil
      assert style.bold == nil
      assert style.italic == nil
      assert style.underline == nil
      assert style.strikethrough == nil
      assert style.dim == nil
      assert style.inverse == nil
    end

    test "creates an empty style with default layout values" do
      style = Style.new()

      assert style.padding_top == 0
      assert style.padding_right == 0
      assert style.padding_bottom == 0
      assert style.padding_left == 0
      assert style.margin_top == 0
      assert style.margin_right == 0
      assert style.margin_bottom == 0
      assert style.margin_left == 0
      assert style.flex_grow == 0
      assert style.flex_shrink == 1
      assert style.width == nil
      assert style.height == nil
      assert style.border == nil
    end
  end

  describe "new/1" do
    test "sets visual attributes from keyword list" do
      style = Style.new(fg: :red, bg: :blue, bold: true, italic: true)

      assert style.fg == :red
      assert style.bg == :blue
      assert style.bold == true
      assert style.italic == true
      assert style.underline == nil
    end

    test "sets layout properties from keyword list" do
      style = Style.new(width: 40, height: 10, flex_grow: 1, border: :single)

      assert style.width == 40
      assert style.height == 10
      assert style.flex_grow == 1
      assert style.border == :single
    end

    test "sets individual padding sides" do
      style = Style.new(padding_top: 1, padding_left: 3)

      assert style.padding_top == 1
      assert style.padding_right == 0
      assert style.padding_bottom == 0
      assert style.padding_left == 3
    end

    test "accepts RGB color tuples" do
      style = Style.new(fg: {:rgb, 255, 0, 128}, bg: {:index, 42})

      assert style.fg == {:rgb, 255, 0, 128}
      assert style.bg == {:index, 42}
    end
  end

  describe "padding shorthand" do
    test "single value expands to all four sides" do
      style = Style.new(padding: 2)

      assert style.padding_top == 2
      assert style.padding_right == 2
      assert style.padding_bottom == 2
      assert style.padding_left == 2
    end

    test "{v, h} tuple expands correctly" do
      style = Style.new(padding: {1, 3})

      assert style.padding_top == 1
      assert style.padding_right == 3
      assert style.padding_bottom == 1
      assert style.padding_left == 3
    end

    test "explicit side overrides shorthand" do
      style = Style.new(padding: 2, padding_left: 5)

      assert style.padding_top == 2
      assert style.padding_right == 2
      assert style.padding_bottom == 2
      assert style.padding_left == 5
    end
  end

  describe "margin shorthand" do
    test "single value expands to all four sides" do
      style = Style.new(margin: 1)

      assert style.margin_top == 1
      assert style.margin_right == 1
      assert style.margin_bottom == 1
      assert style.margin_left == 1
    end

    test "{v, h} tuple expands correctly" do
      style = Style.new(margin: {2, 4})

      assert style.margin_top == 2
      assert style.margin_right == 4
      assert style.margin_bottom == 2
      assert style.margin_left == 4
    end

    test "explicit side overrides shorthand" do
      style = Style.new(margin: 3, margin_top: 0)

      assert style.margin_top == 0
      assert style.margin_right == 3
      assert style.margin_bottom == 3
      assert style.margin_left == 3
    end
  end

  describe "merge/2" do
    test "non-nil values in override replace base values" do
      base = Style.new(fg: :blue, bold: true)
      override = Style.new(fg: :red)

      merged = Style.merge(base, override)

      assert merged.fg == :red
    end

    test "nil values in override do not replace base values" do
      base = Style.new(fg: :blue, bold: true)
      override = Style.new(italic: true)

      merged = Style.merge(base, override)

      assert merged.fg == :blue
      assert merged.bold == true
      assert merged.italic == true
    end

    test "merging two empty styles returns empty style" do
      assert Style.merge(Style.new(), Style.new()) == Style.new()
    end

    test "layout values always come from override" do
      base = Style.new(padding: 2, width: 40)
      override = Style.new(padding: 0, width: nil)

      merged = Style.merge(base, override)

      assert merged.padding_top == 0
      assert merged.width == nil
    end

    test "merges all visual attributes independently" do
      base = Style.new(fg: :red, bg: :blue, bold: true, dim: true)
      override = Style.new(fg: :green, underline: true)

      merged = Style.merge(base, override)

      assert merged.fg == :green
      assert merged.bg == :blue
      assert merged.bold == true
      assert merged.dim == true
      assert merged.underline == true
    end
  end

  describe "resolve/1" do
    test "fills in defaults for nil visual attributes" do
      resolved = Style.new() |> Style.resolve()

      assert resolved.fg == :default
      assert resolved.bg == :default
      assert resolved.bold == false
      assert resolved.italic == false
      assert resolved.underline == false
      assert resolved.strikethrough == false
      assert resolved.dim == false
      assert resolved.inverse == false
    end

    test "preserves explicitly set values" do
      resolved = Style.new(fg: :red, bold: true) |> Style.resolve()

      assert resolved.fg == :red
      assert resolved.bold == true
    end

    test "preserves explicitly false values" do
      resolved = Style.new(bold: false) |> Style.resolve()

      assert resolved.bold == false
    end

    test "preserves layout properties unchanged" do
      resolved = Style.new(padding: 2, width: 40) |> Style.resolve()

      assert resolved.padding_top == 2
      assert resolved.width == 40
    end
  end

  describe "to_cell_attrs/1" do
    test "returns only visual attributes" do
      style = Style.new(fg: :red, bold: true, padding: 2, width: 40)

      attrs = Style.to_cell_attrs(style)

      assert Keyword.get(attrs, :fg) == :red
      assert Keyword.get(attrs, :bold) == true
      assert Keyword.get(attrs, :bg) == nil
      refute Keyword.has_key?(attrs, :padding_top)
      refute Keyword.has_key?(attrs, :width)
    end

    test "returns all eight visual attribute keys" do
      attrs = Style.new() |> Style.to_cell_attrs()

      keys = Keyword.keys(attrs)
      assert :fg in keys
      assert :bg in keys
      assert :bold in keys
      assert :italic in keys
      assert :underline in keys
      assert :strikethrough in keys
      assert :dim in keys
      assert :inverse in keys
      assert length(keys) == 8
    end

    test "resolved style produces values compatible with Buffer.Cell" do
      attrs =
        Style.new(fg: :red, bold: true)
        |> Style.resolve()
        |> Style.to_cell_attrs()

      cell = Cell.new(attrs)

      assert cell.fg == :red
      assert cell.bg == :default
      assert cell.bold == true
      assert cell.italic == false
    end
  end
end
