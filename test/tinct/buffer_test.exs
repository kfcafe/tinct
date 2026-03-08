defmodule Tinct.BufferTest do
  use ExUnit.Case, async: true

  alias Tinct.Buffer
  alias Tinct.Buffer.Cell

  doctest Buffer

  describe "new/2" do
    test "creates a buffer with the given dimensions" do
      buf = Buffer.new(80, 24)
      assert buf.width == 80
      assert buf.height == 24
    end

    test "fills all cells with defaults" do
      buf = Buffer.new(3, 2)

      for col <- 0..2, row <- 0..1 do
        cell = Buffer.get(buf, col, row)
        assert cell.char == " "
        assert cell.fg == :default
        assert cell.bg == :default
      end
    end

    test "creates an empty buffer with zero dimensions" do
      buf = Buffer.new(0, 0)
      assert buf.width == 0
      assert buf.height == 0
      assert buf.cells == %{}
    end

    test "creates a 1x1 buffer" do
      buf = Buffer.new(1, 1)
      assert buf.width == 1
      assert buf.height == 1
      assert map_size(buf.cells) == 1
    end

    test "creates correct number of cells" do
      buf = Buffer.new(10, 5)
      assert map_size(buf.cells) == 50
    end
  end

  describe "get/3" do
    test "returns the cell at the given position" do
      buf = Buffer.new(10, 5)
      cell = Buffer.get(buf, 0, 0)
      assert %Cell{} = cell
      assert cell.char == " "
    end

    test "returns default cell for out-of-bounds column" do
      buf = Buffer.new(10, 5)
      cell = Buffer.get(buf, 100, 0)
      assert cell == Cell.new()
    end

    test "returns default cell for out-of-bounds row" do
      buf = Buffer.new(10, 5)
      cell = Buffer.get(buf, 0, 100)
      assert cell == Cell.new()
    end

    test "returns default cell for negative coordinates" do
      buf = Buffer.new(10, 5)
      assert Buffer.get(buf, -1, 0) == Cell.new()
      assert Buffer.get(buf, 0, -1) == Cell.new()
    end
  end

  describe "put/4" do
    test "sets a cell at the given position" do
      buf = Buffer.new(10, 5)
      cell = Cell.new(char: "X", fg: :red)
      buf = Buffer.put(buf, 3, 2, cell)

      result = Buffer.get(buf, 3, 2)
      assert result.char == "X"
      assert result.fg == :red
    end

    test "round-trips a cell through put and get" do
      buf = Buffer.new(10, 5)
      original = Cell.new(char: "★", fg: :cyan, bold: true, italic: true)
      buf = Buffer.put(buf, 5, 3, original)

      assert Cell.equal?(Buffer.get(buf, 5, 3), original)
    end

    test "ignores out-of-bounds put" do
      buf = Buffer.new(10, 5)
      cell = Cell.new(char: "X")

      assert Buffer.put(buf, 100, 0, cell) == buf
      assert Buffer.put(buf, 0, 100, cell) == buf
    end

    test "does not affect other cells" do
      buf = Buffer.new(3, 3)
      cell = Cell.new(char: "X")
      buf = Buffer.put(buf, 1, 1, cell)

      assert Buffer.get(buf, 0, 0).char == " "
      assert Buffer.get(buf, 1, 1).char == "X"
      assert Buffer.get(buf, 2, 2).char == " "
    end
  end

  describe "put_string/5" do
    test "writes each character to consecutive cells" do
      buf = Buffer.new(10, 1)
      buf = Buffer.put_string(buf, 0, 0, "Hello")

      assert Buffer.get(buf, 0, 0).char == "H"
      assert Buffer.get(buf, 1, 0).char == "e"
      assert Buffer.get(buf, 2, 0).char == "l"
      assert Buffer.get(buf, 3, 0).char == "l"
      assert Buffer.get(buf, 4, 0).char == "o"
    end

    test "applies style to all characters" do
      buf = Buffer.new(10, 1)
      buf = Buffer.put_string(buf, 0, 0, "Hi", fg: :green, bold: true)

      for col <- 0..1 do
        cell = Buffer.get(buf, col, 0)
        assert cell.fg == :green
        assert cell.bold == true
      end
    end

    test "truncates at buffer width" do
      buf = Buffer.new(3, 1)
      buf = Buffer.put_string(buf, 0, 0, "Hello")

      assert Buffer.get(buf, 0, 0).char == "H"
      assert Buffer.get(buf, 1, 0).char == "e"
      assert Buffer.get(buf, 2, 0).char == "l"
      # Characters beyond width are not written
    end

    test "truncates when starting mid-buffer" do
      buf = Buffer.new(5, 1)
      buf = Buffer.put_string(buf, 3, 0, "Hello")

      assert Buffer.get(buf, 3, 0).char == "H"
      assert Buffer.get(buf, 4, 0).char == "e"
      # "llo" is truncated
    end

    test "writes at a specific row" do
      buf = Buffer.new(10, 5)
      buf = Buffer.put_string(buf, 2, 3, "Test")

      assert Buffer.get(buf, 2, 3).char == "T"
      assert Buffer.get(buf, 3, 3).char == "e"
      assert Buffer.get(buf, 4, 3).char == "s"
      assert Buffer.get(buf, 5, 3).char == "t"
    end

    test "handles empty string" do
      buf = Buffer.new(10, 1)
      original = buf
      buf = Buffer.put_string(buf, 0, 0, "")

      assert buf == original
    end

    test "handles out-of-bounds row" do
      buf = Buffer.new(10, 5)
      original = buf
      buf = Buffer.put_string(buf, 0, 100, "Hello")

      assert buf == original
    end

    test "default style is no style keywords" do
      buf = Buffer.new(10, 1)
      buf = Buffer.put_string(buf, 0, 0, "A")

      cell = Buffer.get(buf, 0, 0)
      assert cell.char == "A"
      assert cell.fg == :default
      assert cell.bg == :default
      assert cell.bold == false
    end
  end

  describe "clear/1" do
    test "resets all cells to default" do
      buf = Buffer.new(5, 5)
      buf = Buffer.put_string(buf, 0, 0, "Hello", fg: :red, bold: true)
      buf = Buffer.clear(buf)

      for col <- 0..4, row <- 0..4 do
        cell = Buffer.get(buf, col, row)
        assert cell.char == " "
        assert cell.fg == :default
        assert cell.bold == false
      end
    end

    test "preserves dimensions" do
      buf = Buffer.new(10, 5)
      buf = Buffer.clear(buf)

      assert buf.width == 10
      assert buf.height == 5
    end
  end

  describe "resize/3" do
    test "preserves existing content when growing" do
      buf = Buffer.new(5, 5)
      buf = Buffer.put_string(buf, 0, 0, "AB")
      buf = Buffer.resize(buf, 10, 10)

      assert buf.width == 10
      assert buf.height == 10
      assert Buffer.get(buf, 0, 0).char == "A"
      assert Buffer.get(buf, 1, 0).char == "B"
    end

    test "fills new cells with defaults when growing" do
      buf = Buffer.new(2, 2)
      buf = Buffer.resize(buf, 4, 4)

      assert Buffer.get(buf, 3, 3).char == " "
      assert Buffer.get(buf, 3, 3).fg == :default
    end

    test "clips content when shrinking" do
      buf = Buffer.new(10, 10)
      buf = Buffer.put_string(buf, 8, 0, "XY")
      buf = Buffer.resize(buf, 5, 5)

      assert buf.width == 5
      assert buf.height == 5
      # Cell at (8, 0) no longer exists in bounds
      assert Buffer.get(buf, 8, 0) == Cell.new()
    end

    test "preserves content within new bounds when shrinking" do
      buf = Buffer.new(10, 10)
      buf = Buffer.put_string(buf, 0, 0, "Hi")
      buf = Buffer.resize(buf, 5, 5)

      assert Buffer.get(buf, 0, 0).char == "H"
      assert Buffer.get(buf, 1, 0).char == "i"
    end

    test "resize to zero clears everything" do
      buf = Buffer.new(10, 10)
      buf = Buffer.put_string(buf, 0, 0, "Hello")
      buf = Buffer.resize(buf, 0, 0)

      assert buf.width == 0
      assert buf.height == 0
      assert buf.cells == %{}
    end

    test "resize to same dimensions preserves content" do
      buf = Buffer.new(5, 5)
      buf = Buffer.put_string(buf, 0, 0, "Test")
      resized = Buffer.resize(buf, 5, 5)

      for col <- 0..4, row <- 0..4 do
        assert Cell.equal?(Buffer.get(buf, col, row), Buffer.get(resized, col, row))
      end
    end
  end

  describe "region/5" do
    test "extracts a sub-buffer" do
      buf = Buffer.new(10, 10)
      buf = Buffer.put_string(buf, 2, 3, "Hi")
      sub = Buffer.region(buf, 2, 3, 4, 1)

      assert sub.width == 4
      assert sub.height == 1
      assert Buffer.get(sub, 0, 0).char == "H"
      assert Buffer.get(sub, 1, 0).char == "i"
    end

    test "fills with defaults for out-of-source-bounds cells" do
      buf = Buffer.new(5, 5)
      sub = Buffer.region(buf, 3, 3, 5, 5)

      # (0,0) in sub maps to (3,3) in source — valid, default cell
      assert Buffer.get(sub, 0, 0).char == " "
      # (4,4) in sub maps to (7,7) in source — out of bounds, also default
      assert Buffer.get(sub, 4, 4).char == " "
    end

    test "preserves cell styles in region" do
      buf = Buffer.new(10, 10)
      buf = Buffer.put_string(buf, 5, 5, "X", fg: :red, bold: true)
      sub = Buffer.region(buf, 5, 5, 1, 1)

      cell = Buffer.get(sub, 0, 0)
      assert cell.char == "X"
      assert cell.fg == :red
      assert cell.bold == true
    end

    test "extracts zero-size region" do
      buf = Buffer.new(10, 10)
      sub = Buffer.region(buf, 0, 0, 0, 0)

      assert sub.width == 0
      assert sub.height == 0
      assert sub.cells == %{}
    end
  end
end
