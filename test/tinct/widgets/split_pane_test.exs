defmodule Tinct.Widgets.SplitPaneTest do
  use ExUnit.Case, async: true

  alias Tinct.{Element, Test}
  alias Tinct.Widgets.SplitPane

  doctest Tinct.Widgets.SplitPane

  describe "horizontal split" do
    test "renders two panes side by side with │ divider" do
      state =
        Test.render(
          SplitPane,
          [
            direction: :horizontal,
            panes: [
              {Element.text("LEFT"), ratio: 0.5},
              {Element.text("RIGHT"), ratio: 0.5}
            ]
          ],
          size: {41, 5}
        )

      assert Test.contains?(state, "LEFT")
      assert Test.contains?(state, "RIGHT")

      # 40 columns for panes (0.5 * 40 = 20 each), divider at col 20
      assert Test.cell_at(state, 20, 0).char == "│"
      assert Test.cell_at(state, 20, 4).char == "│"
    end

    test "divider fills full height" do
      state =
        Test.render(
          SplitPane,
          [
            direction: :horizontal,
            panes: [
              {Element.text("A"), ratio: 0.5},
              {Element.text("B"), ratio: 0.5}
            ]
          ],
          size: {21, 8}
        )

      # Divider at col 10, should fill all 8 rows
      for row <- 0..7 do
        assert Test.cell_at(state, 10, row).char == "│"
      end
    end
  end

  describe "vertical split" do
    test "renders two panes stacked with ─ divider" do
      state =
        Test.render(
          SplitPane,
          [
            direction: :vertical,
            panes: [
              {Element.text("TOP"), ratio: 0.5},
              {Element.text("BOTTOM"), ratio: 0.5}
            ]
          ],
          size: {20, 11}
        )

      assert Test.contains?(state, "TOP")
      assert Test.contains?(state, "BOTTOM")

      # 10 rows for panes (0.5 * 10 = 5 each), divider at row 5
      assert Test.cell_at(state, 0, 5).char == "─"
      assert Test.cell_at(state, 19, 5).char == "─"
    end

    test "divider fills full width" do
      state =
        Test.render(
          SplitPane,
          [
            direction: :vertical,
            panes: [
              {Element.text("A"), ratio: 0.5},
              {Element.text("B"), ratio: 0.5}
            ]
          ],
          size: {15, 11}
        )

      # Divider at row 5, should fill all 15 columns
      for col <- 0..14 do
        assert Test.cell_at(state, col, 5).char == "─"
      end
    end
  end

  describe "ratios" do
    test "respects 0.3/0.7 horizontal split" do
      state =
        Test.render(
          SplitPane,
          [
            direction: :horizontal,
            panes: [
              {Element.text("A"), ratio: 0.3},
              {Element.text("B"), ratio: 0.7}
            ]
          ],
          size: {41, 3}
        )

      # 40 columns for panes, 30% = 12, divider at col 12
      assert Test.cell_at(state, 12, 0).char == "│"
    end

    test "respects 0.6/0.4 vertical split" do
      state =
        Test.render(
          SplitPane,
          [
            direction: :vertical,
            panes: [
              {Element.text("A"), ratio: 0.6},
              {Element.text("B"), ratio: 0.4}
            ]
          ],
          size: {20, 11}
        )

      # 10 rows for panes, 60% = 6, divider at row 6
      assert Test.cell_at(state, 0, 6).char == "─"
    end
  end

  describe "min size constraints" do
    test "enforces min width on horizontal split" do
      state =
        Test.render(
          SplitPane,
          [
            direction: :horizontal,
            panes: [
              {Element.text("L"), ratio: 0.3, min: 10},
              {Element.text("R"), ratio: 0.7}
            ]
          ],
          size: {22, 3}
        )

      # Without min, left would get ~6 cols (0.3 * 21 ≈ 6).
      # With min: 10, left gets clamped to 10. Divider at col 10.
      assert Test.cell_at(state, 10, 0).char == "│"
    end

    test "enforces min height on vertical split" do
      state =
        Test.render(
          SplitPane,
          [
            direction: :vertical,
            panes: [
              {Element.text("T"), ratio: 0.3, min: 5},
              {Element.text("B"), ratio: 0.7}
            ]
          ],
          size: {20, 9}
        )

      # Without min, top would get ~2 rows (0.3 * 8 ≈ 2).
      # With min: 5, top gets clamped to 5. Divider at row 5.
      assert Test.cell_at(state, 0, 5).char == "─"
    end
  end

  describe "resize" do
    test "recalculates pane sizes from ratios at different sizes" do
      opts = [
        direction: :horizontal,
        panes: [
          {Element.text("A"), ratio: 0.3},
          {Element.text("B"), ratio: 0.7}
        ]
      ]

      state_small = Test.render(SplitPane, opts, size: {21, 3})
      state_large = Test.render(SplitPane, opts, size: {41, 3})

      # Small: 20 cols for panes, 30% = 6, divider at col 6
      assert Test.cell_at(state_small, 6, 0).char == "│"
      # Large: 40 cols for panes, 30% = 12, divider at col 12
      assert Test.cell_at(state_large, 12, 0).char == "│"
    end
  end

  describe "nested splits" do
    test "split inside a split renders correctly" do
      inner_split =
        SplitPane.element(
          direction: :vertical,
          panes: [
            {Element.text("TOP"), ratio: 0.5},
            {Element.text("BOT"), ratio: 0.5}
          ]
        )

      state =
        Test.render(
          SplitPane,
          [
            direction: :horizontal,
            panes: [
              {Element.text("LEFT"), ratio: 0.5},
              {inner_split, ratio: 0.5}
            ]
          ],
          size: {41, 11}
        )

      assert Test.contains?(state, "LEFT")
      assert Test.contains?(state, "TOP")
      assert Test.contains?(state, "BOT")

      # Outer vertical divider at col 20
      assert Test.cell_at(state, 20, 0).char == "│"
    end
  end

  describe "element/1" do
    test "creates a row element for horizontal split" do
      el =
        SplitPane.element(
          direction: :horizontal,
          panes: [
            {Element.text("A"), ratio: 0.5},
            {Element.text("B"), ratio: 0.5}
          ]
        )

      assert el.type == :row
    end

    test "creates a column element for vertical split" do
      el =
        SplitPane.element(
          direction: :vertical,
          panes: [
            {Element.text("A"), ratio: 0.5},
            {Element.text("B"), ratio: 0.5}
          ]
        )

      assert el.type == :column
    end
  end

  describe "init/1" do
    test "defaults to horizontal direction" do
      model = SplitPane.init([])
      assert model.direction == :horizontal
      assert model.panes == []
      assert model.divider == :single
    end

    test "accepts all options" do
      panes = [{Element.text("A"), ratio: 0.4, min: 10}]
      model = SplitPane.init(direction: :vertical, panes: panes, divider: :single)
      assert model.direction == :vertical
      assert length(model.panes) == 1
      assert hd(model.panes).ratio == 0.4
      assert hd(model.panes).min == 10
    end
  end

  describe "update/2" do
    test "returns model unchanged" do
      model = SplitPane.init(direction: :horizontal)
      assert SplitPane.update(model, :any_msg) == model
    end
  end
end
