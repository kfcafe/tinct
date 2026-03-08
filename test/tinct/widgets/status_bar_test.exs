defmodule Tinct.Widgets.StatusBarTest do
  use ExUnit.Case, async: true

  alias Tinct.Test, as: T
  alias Tinct.Widgets.StatusBar

  doctest Tinct.Widgets.StatusBar

  describe "rendering" do
    test "single section renders full width" do
      state =
        T.render(
          StatusBar,
          [sections: [{"main", [align: :left]}]],
          size: {10, 3}
        )

      bar_row = 2

      assert T.line(state, bar_row) == "main"
      assert T.cell_at(state, 0, bar_row).char == "m"
      assert T.cell_at(state, 3, bar_row).char == "n"
      assert T.cell_at(state, 9, bar_row).char == " "

      for col <- 0..9 do
        assert T.cell_at(state, col, bar_row).bg == :bright_black
      end
    end

    test "left + right sections position correctly" do
      state =
        T.render(
          StatusBar,
          [sections: [{"L", [align: :left]}, {"R", [align: :right]}]],
          size: {10, 2}
        )

      bar_row = 1

      assert T.cell_at(state, 0, bar_row).char == "L"
      assert T.cell_at(state, 9, bar_row).char == "R"

      for col <- 1..8 do
        assert T.cell_at(state, col, bar_row).char == " "
      end
    end

    test "center section centers" do
      state =
        T.render(
          StatusBar,
          [sections: [{"C", [align: :center]}]],
          size: {9, 2}
        )

      bar_row = 1

      assert T.cell_at(state, 4, bar_row).char == "C"
      assert T.cell_at(state, 0, bar_row).char == " "
      assert T.cell_at(state, 8, bar_row).char == " "
    end

    test "center section centers between left and right groups" do
      state =
        T.render(
          StatusBar,
          [
            sections: [
              {"L", [align: :left]},
              {"C", [align: :center]},
              {"RR", [align: :right]}
            ]
          ],
          size: {10, 2}
        )

      bar_row = 1

      # width 10, left=1, right=2 => remaining=7, center=1 => (7-1)/2 = 3
      # center should start at col 1 + 3 = 4
      assert T.cell_at(state, 4, bar_row).char == "C"
      assert T.cell_at(state, 0, bar_row).char == "L"
      assert T.cell_at(state, 8, bar_row).char == "R"
      assert T.cell_at(state, 9, bar_row).char == "R"
    end

    test "long content truncates" do
      state =
        T.render(
          StatusBar,
          [sections: [{"ABCDEFGHIJK", [align: :left]}]],
          size: {5, 1}
        )

      assert T.line(state, 0) == "ABCDE"
    end

    test "style applies as background" do
      state =
        T.render(
          StatusBar,
          [
            sections: [{"x", [align: :left]}],
            style: Tinct.Style.new(bg: :blue, fg: :white)
          ],
          size: {6, 2}
        )

      bar_row = 1

      for col <- 0..5 do
        assert T.cell_at(state, col, bar_row).bg == :blue
      end
    end
  end

  describe "public API" do
    test "set_section/3 updates an in-range section" do
      model = StatusBar.init(sections: [{"a", [align: :left]}])
      model = StatusBar.set_section(model, 0, {"b", [align: :right]})
      assert model.sections == [{"b", [align: :right]}]
    end

    test "set_section/3 ignores out-of-range index" do
      model = StatusBar.init(sections: [{"a", [align: :left]}])
      assert StatusBar.set_section(model, 1, {"b", [align: :left]}) == model
    end

    test "set_sections/2 replaces all sections" do
      model = StatusBar.init(sections: [{"a", [align: :left]}])
      model = StatusBar.set_sections(model, [{"x", [align: :center]}])
      assert model.sections == [{"x", [align: :center]}]
    end
  end
end
