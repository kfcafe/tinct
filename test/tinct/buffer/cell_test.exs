defmodule Tinct.Buffer.CellTest do
  use ExUnit.Case, async: true

  alias Tinct.Buffer.Cell

  doctest Cell

  describe "new/0" do
    test "creates a cell with default values" do
      cell = Cell.new()
      assert cell.char == " "
      assert cell.fg == :default
      assert cell.bg == :default
      assert cell.bold == false
      assert cell.italic == false
      assert cell.underline == false
      assert cell.strikethrough == false
      assert cell.dim == false
      assert cell.inverse == false
    end
  end

  describe "new/1" do
    test "creates a cell with custom character" do
      cell = Cell.new(char: "A")
      assert cell.char == "A"
    end

    test "creates a cell with custom colors" do
      cell = Cell.new(fg: :red, bg: :blue)
      assert cell.fg == :red
      assert cell.bg == :blue
    end

    test "creates a cell with RGB color tuple" do
      cell = Cell.new(fg: {255, 0, 128})
      assert cell.fg == {255, 0, 128}
    end

    test "creates a cell with multiple style flags" do
      cell = Cell.new(bold: true, italic: true, underline: true)
      assert cell.bold == true
      assert cell.italic == true
      assert cell.underline == true
      assert cell.strikethrough == false
    end

    test "creates a cell with all options set" do
      cell =
        Cell.new(
          char: "Z",
          fg: :green,
          bg: :black,
          bold: true,
          italic: true,
          underline: true,
          strikethrough: true,
          dim: true,
          inverse: true
        )

      assert cell.char == "Z"
      assert cell.fg == :green
      assert cell.bg == :black
      assert cell.bold == true
      assert cell.italic == true
      assert cell.underline == true
      assert cell.strikethrough == true
      assert cell.dim == true
      assert cell.inverse == true
    end
  end

  describe "reset/0" do
    test "returns a default cell identical to new/0" do
      assert Cell.reset() == Cell.new()
    end
  end

  describe "equal?/2" do
    test "identical cells are equal" do
      a = Cell.new(char: "A", fg: :red, bold: true)
      b = Cell.new(char: "A", fg: :red, bold: true)
      assert Cell.equal?(a, b)
    end

    test "default cells are equal" do
      assert Cell.equal?(Cell.new(), Cell.new())
    end

    test "different characters are not equal" do
      a = Cell.new(char: "A")
      b = Cell.new(char: "B")
      refute Cell.equal?(a, b)
    end

    test "different foreground colors are not equal" do
      a = Cell.new(fg: :red)
      b = Cell.new(fg: :blue)
      refute Cell.equal?(a, b)
    end

    test "different background colors are not equal" do
      a = Cell.new(bg: :red)
      b = Cell.new(bg: :blue)
      refute Cell.equal?(a, b)
    end

    test "different bold flags are not equal" do
      a = Cell.new(bold: true)
      b = Cell.new(bold: false)
      refute Cell.equal?(a, b)
    end

    test "different italic flags are not equal" do
      a = Cell.new(italic: true)
      b = Cell.new(italic: false)
      refute Cell.equal?(a, b)
    end

    test "different underline flags are not equal" do
      a = Cell.new(underline: true)
      b = Cell.new(underline: false)
      refute Cell.equal?(a, b)
    end

    test "different strikethrough flags are not equal" do
      a = Cell.new(strikethrough: true)
      b = Cell.new(strikethrough: false)
      refute Cell.equal?(a, b)
    end

    test "different dim flags are not equal" do
      a = Cell.new(dim: true)
      b = Cell.new(dim: false)
      refute Cell.equal?(a, b)
    end

    test "different inverse flags are not equal" do
      a = Cell.new(inverse: true)
      b = Cell.new(inverse: false)
      refute Cell.equal?(a, b)
    end
  end

  describe "styled/2" do
    test "applies style overrides to a cell" do
      cell = Cell.new(char: "A")
      styled = Cell.styled(cell, fg: :red, bold: true)

      assert styled.char == "A"
      assert styled.fg == :red
      assert styled.bold == true
    end

    test "preserves unmodified fields" do
      cell = Cell.new(char: "A", fg: :green, italic: true)
      styled = Cell.styled(cell, bold: true)

      assert styled.char == "A"
      assert styled.fg == :green
      assert styled.italic == true
      assert styled.bold == true
    end

    test "overrides existing values" do
      cell = Cell.new(fg: :red)
      styled = Cell.styled(cell, fg: :blue)

      assert styled.fg == :blue
    end

    test "empty overrides returns equivalent cell" do
      cell = Cell.new(char: "A", fg: :red)
      styled = Cell.styled(cell, [])

      assert Cell.equal?(cell, styled)
    end
  end
end
