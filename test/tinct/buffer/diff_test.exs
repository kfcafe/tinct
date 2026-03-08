defmodule Tinct.Buffer.DiffTest do
  use ExUnit.Case, async: true

  alias Tinct.Buffer
  alias Tinct.Buffer.Cell
  alias Tinct.Buffer.Diff

  doctest Diff

  describe "diff/2" do
    test "identical empty buffers produce empty output" do
      buf = Buffer.new(0, 0)
      assert Diff.diff(buf, buf) == []
    end

    test "identical buffers produce empty output" do
      buf = Buffer.new(10, 5)
      assert Diff.diff(buf, buf) == []
    end

    test "identical non-empty buffers produce empty output" do
      buf =
        Buffer.new(10, 5)
        |> Buffer.put_string(0, 0, "Hello")

      assert Diff.diff(buf, buf) == []
    end

    test "single cell change produces correct move_to, style, and char" do
      prev = Buffer.new(10, 5)
      new = Buffer.put(prev, 3, 2, Cell.new(char: "X", fg: :red))

      result = IO.iodata_to_binary(Diff.diff(prev, new))

      # move_to(3, 2) → \e[3;4H (ANSI is 1-indexed)
      assert result =~ "\e[3;4H"
      assert result =~ "X"
      # red foreground SGR code
      assert result =~ "31"
    end

    test "adjacent changed cells on same row produce one move_to" do
      prev = Buffer.new(10, 1)
      new = Buffer.put_string(prev, 2, 0, "ABC")

      result = IO.iodata_to_binary(Diff.diff(prev, new))

      move_count = Regex.scan(~r/\e\[\d+;\d+H/, result) |> length()
      assert move_count == 1
      assert result =~ "ABC"
    end

    test "non-adjacent changed cells produce separate move_tos" do
      prev = Buffer.new(10, 1)

      new =
        prev
        |> Buffer.put(1, 0, Cell.new(char: "X"))
        |> Buffer.put(5, 0, Cell.new(char: "Y"))

      result = IO.iodata_to_binary(Diff.diff(prev, new))

      move_count = Regex.scan(~r/\e\[\d+;\d+H/, result) |> length()
      assert move_count == 2
      assert result =~ "X"
      assert result =~ "Y"
    end

    test "style changes mid-run emit new SGR" do
      prev = Buffer.new(10, 1)

      new =
        prev
        |> Buffer.put(0, 0, Cell.new(char: "A", fg: :red))
        |> Buffer.put(1, 0, Cell.new(char: "B", fg: :blue))

      result = IO.iodata_to_binary(Diff.diff(prev, new))

      # red (31) and blue (34)
      assert result =~ "31"
      assert result =~ "34"
      assert result =~ "A"
      assert result =~ "B"
    end

    test "same style on adjacent cells emits SGR once" do
      prev = Buffer.new(10, 1)

      new =
        prev
        |> Buffer.put(0, 0, Cell.new(char: "A", fg: :red))
        |> Buffer.put(1, 0, Cell.new(char: "B", fg: :red))

      result = IO.iodata_to_binary(Diff.diff(prev, new))

      # Only one SGR containing red (31m), not two
      sgr_count = Regex.scan(~r/31m/, result) |> length()
      assert sgr_count == 1
    end

    test "different-sized buffers produce full_render output" do
      prev = Buffer.new(5, 3)

      new =
        Buffer.new(10, 5)
        |> Buffer.put_string(0, 0, "Hello")

      diff_result = IO.iodata_to_binary(Diff.diff(prev, new))
      full_result = IO.iodata_to_binary(Diff.full_render(new))

      assert diff_result == full_result
    end

    test "handles multi-byte characters" do
      prev = Buffer.new(10, 1)
      new = Buffer.put(prev, 0, 0, Cell.new(char: "🎉"))

      result = IO.iodata_to_binary(Diff.diff(prev, new))
      assert result =~ "🎉"
    end

    test "resets style at end when last changed cell is styled" do
      prev = Buffer.new(5, 1)

      new =
        prev
        |> Buffer.put(4, 0, Cell.new(char: "Z", fg: :green))

      result = IO.iodata_to_binary(Diff.diff(prev, new))
      assert String.ends_with?(result, "\e[0m")
    end

    test "changed cells on different rows each get move_to" do
      prev = Buffer.new(10, 3)

      new =
        prev
        |> Buffer.put(0, 0, Cell.new(char: "A"))
        |> Buffer.put(0, 2, Cell.new(char: "B"))

      result = IO.iodata_to_binary(Diff.diff(prev, new))

      # move_to(0, 0) = \e[1;1H and move_to(0, 2) = \e[3;1H
      assert result =~ "\e[1;1H"
      assert result =~ "\e[3;1H"
    end

    test "bold and italic attributes are emitted in SGR" do
      prev = Buffer.new(10, 1)
      new = Buffer.put(prev, 0, 0, Cell.new(char: "X", bold: true, italic: true))

      result = IO.iodata_to_binary(Diff.diff(prev, new))

      # bold = SGR 1, italic = SGR 3
      assert result =~ "1"
      assert result =~ "3"
    end
  end

  describe "full_render/1" do
    test "empty buffer produces empty output" do
      buf = Buffer.new(0, 0)
      assert Diff.full_render(buf) == []
    end

    test "renders every cell character" do
      buf =
        Buffer.new(3, 2)
        |> Buffer.put_string(0, 0, "ABC")
        |> Buffer.put_string(0, 1, "DEF")

      result = IO.iodata_to_binary(Diff.full_render(buf))

      for char <- ~w(A B C D E F) do
        assert result =~ char
      end
    end

    test "emits move_to for each row" do
      buf = Buffer.new(3, 3)
      result = IO.iodata_to_binary(Diff.full_render(buf))

      assert result =~ "\e[1;1H"
      assert result =~ "\e[2;1H"
      assert result =~ "\e[3;1H"
    end

    test "styled cells include correct SGR sequences" do
      buf =
        Buffer.new(3, 1)
        |> Buffer.put(0, 0, Cell.new(char: "X", bold: true, fg: :red))

      result = IO.iodata_to_binary(Diff.full_render(buf))

      assert result =~ "X"
      # bold (1) and red fg (31) present in the SGR
      assert result =~ "31"
    end

    test "resets style at end when last cell is styled" do
      buf =
        Buffer.new(3, 1)
        |> Buffer.put(0, 0, Cell.new(char: "A", fg: :red))
        |> Buffer.put(1, 0, Cell.new(char: "B", fg: :red))
        |> Buffer.put(2, 0, Cell.new(char: "C", fg: :red))

      result = IO.iodata_to_binary(Diff.full_render(buf))
      assert String.ends_with?(result, "\e[0m")
    end

    test "does not double-reset when last cell has default style" do
      buf = Buffer.new(3, 1)
      result = IO.iodata_to_binary(Diff.full_render(buf))

      # Default-styled cells emit a single reset at the start, not a trailing one
      refute String.ends_with?(result, "\e[0m\e[0m")
    end

    test "coalesces styles across consecutive same-styled cells" do
      buf =
        Buffer.new(3, 1)
        |> Buffer.put(0, 0, Cell.new(char: "A", fg: :green))
        |> Buffer.put(1, 0, Cell.new(char: "B", fg: :green))
        |> Buffer.put(2, 0, Cell.new(char: "C", fg: :green))

      result = IO.iodata_to_binary(Diff.full_render(buf))

      # Only one green SGR (32m), not three
      sgr_count = Regex.scan(~r/32m/, result) |> length()
      assert sgr_count == 1
    end
  end
end
