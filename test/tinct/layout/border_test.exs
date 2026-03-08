defmodule Tinct.Layout.BorderTest do
  use ExUnit.Case, async: true

  alias Tinct.Buffer
  alias Tinct.Layout.Border
  alias Tinct.Layout.Rect

  describe "chars/1" do
    test "returns the correct character set for each style" do
      assert %Border{
               top_left: "┌",
               top: "─",
               top_right: "┐",
               left: "│",
               right: "│",
               bottom_left: "└",
               bottom: "─",
               bottom_right: "┘"
             } =
               Border.chars(:single)

      assert %Border{
               top_left: "╔",
               top: "═",
               top_right: "╗",
               left: "║",
               right: "║",
               bottom_left: "╚",
               bottom: "═",
               bottom_right: "╝"
             } =
               Border.chars(:double)

      assert %Border{
               top_left: "╭",
               top: "─",
               top_right: "╮",
               left: "│",
               right: "│",
               bottom_left: "╰",
               bottom: "─",
               bottom_right: "╯"
             } =
               Border.chars(:round)

      assert %Border{
               top_left: "┏",
               top: "━",
               top_right: "┓",
               left: "┃",
               right: "┃",
               bottom_left: "┗",
               bottom: "━",
               bottom_right: "┛"
             } =
               Border.chars(:bold)

      assert %Border{
               top_left: " ",
               top: " ",
               top_right: " ",
               left: " ",
               right: " ",
               bottom_left: " ",
               bottom: " ",
               bottom_right: " "
             } =
               Border.chars(:none)
    end
  end

  describe "render/3" do
    test "draws correct corners and edges for :single" do
      buf = Buffer.new(6, 4)
      buf = Border.render(Rect.new(0, 0, 6, 4), :single, buf)

      assert row(buf, 0) == "┌────┐"
      assert row(buf, 1) == "│    │"
      assert row(buf, 2) == "│    │"
      assert row(buf, 3) == "└────┘"
    end

    test "draws correct characters for :round, :double, :bold" do
      round = Buffer.new(4, 3)
      round = Border.render(Rect.new(0, 0, 4, 3), :round, round)

      assert Buffer.get(round, 0, 0).char == "╭"
      assert Buffer.get(round, 3, 0).char == "╮"
      assert Buffer.get(round, 0, 2).char == "╰"
      assert Buffer.get(round, 3, 2).char == "╯"

      double = Buffer.new(4, 3)
      double = Border.render(Rect.new(0, 0, 4, 3), :double, double)

      assert Buffer.get(double, 0, 0).char == "╔"
      assert Buffer.get(double, 1, 0).char == "═"
      assert Buffer.get(double, 0, 1).char == "║"

      bold = Buffer.new(4, 3)
      bold = Border.render(Rect.new(0, 0, 4, 3), :bold, bold)

      assert Buffer.get(bold, 0, 0).char == "┏"
      assert Buffer.get(bold, 1, 0).char == "━"
      assert Buffer.get(bold, 0, 1).char == "┃"
    end
  end

  describe "inner_rect/2" do
    test "shrinks by 1 cell on each side for visible borders" do
      assert Border.inner_rect(Rect.new(0, 0, 10, 5), :single) == Rect.new(1, 1, 8, 3)
    end

    test "returns same rect for :none" do
      assert Border.inner_rect(Rect.new(0, 0, 10, 5), :none) == Rect.new(0, 0, 10, 5)
    end
  end

  describe "merge_border_chars/2" do
    test "merges horizontal + vertical into intersections" do
      assert Border.merge_border_chars("─", "│") == "┼"
      assert Border.merge_border_chars("─", "┬") == "┬"
      assert Border.merge_border_chars("│", "┬") == "┼"
      assert Border.merge_border_chars("─", "│") == "┼"

      assert Border.merge_border_chars("┐", "┌") == "┬"
      assert Border.merge_border_chars("┘", "└") == "┴"
      assert Border.merge_border_chars("└", "┌") == "├"
      assert Border.merge_border_chars("┘", "┐") == "┤"
    end
  end

  describe "auto-connecting borders via render/3" do
    test "side-by-side borders merge into top/bottom tees" do
      buf = Buffer.new(10, 4)

      buf = Border.render(Rect.new(0, 0, 5, 4), :single, buf)
      buf = Border.render(Rect.new(4, 0, 6, 4), :single, buf)

      assert row(buf, 0) == "┌───┬────┐"
      assert row(buf, 3) == "└───┴────┘"
      assert Buffer.get(buf, 4, 1).char == "│"
      assert Buffer.get(buf, 4, 2).char == "│"
    end

    test "stacked borders merge into left/right tees" do
      buf = Buffer.new(6, 6)

      buf = Border.render(Rect.new(0, 0, 6, 3), :single, buf)
      buf = Border.render(Rect.new(0, 2, 6, 4), :single, buf)

      assert row(buf, 2) == "├────┤"
    end

    test "crossing borders produce a full intersection" do
      buf = Buffer.new(5, 5)

      buf = Border.render(Rect.new(2, 0, 3, 5), :single, buf)
      buf = Border.render(Rect.new(0, 2, 5, 3), :single, buf)

      assert Buffer.get(buf, 2, 2).char == "┼"
    end
  end

  describe "render/4 title support" do
    test "renders a title in the top border" do
      buf = Buffer.new(20, 3)
      buf = Border.render(Rect.new(0, 0, 20, 3), :single, buf, title: "Title")

      assert Buffer.get(buf, 0, 0).char == "┌"
      assert Buffer.get(buf, 1, 0).char == " "

      # "┌ Title ─"
      assert Buffer.get(buf, 2, 0).char == "T"
      assert Buffer.get(buf, 6, 0).char == "e"
      assert Buffer.get(buf, 7, 0).char == " "
      assert Buffer.get(buf, 8, 0).char == "─"
      assert Buffer.get(buf, 19, 0).char == "┐"
    end

    test "truncates long titles to border width - 4" do
      buf = Buffer.new(10, 3)
      buf = Border.render(Rect.new(0, 0, 10, 3), :single, buf, title: "0123456789")

      assert Buffer.get(buf, 1, 0).char == " "

      # 10 - 4 = 6 chars ("012345")
      assert Buffer.get(buf, 2, 0).char == "0"
      assert Buffer.get(buf, 7, 0).char == "5"
      assert Buffer.get(buf, 8, 0).char == " "

      # Ensure the right corner isn't overwritten
      assert Buffer.get(buf, 9, 0).char == "┐"
    end
  end

  defp row(%Buffer{} = buffer, row) do
    0..(buffer.width - 1)//1
    |> Enum.map_join("", fn col -> Buffer.get(buffer, col, row).char end)
  end
end
