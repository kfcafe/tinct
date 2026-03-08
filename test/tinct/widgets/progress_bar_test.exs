defmodule Tinct.Widgets.ProgressBarTest do
  use ExUnit.Case, async: true

  alias Tinct.Test, as: T
  alias Tinct.Widgets.ProgressBar

  doctest Tinct.Widgets.ProgressBar

  describe "view/1 rendering" do
    test "0% progress renders all empty chars" do
      state = T.render(ProgressBar, progress: 0.0, width: 10, show_percentage: false)
      assert T.line(state, 0) == String.duplicate("░", 10)
    end

    test "100% progress renders all filled chars" do
      state = T.render(ProgressBar, progress: 1.0, width: 10, show_percentage: false)
      assert T.line(state, 0) == String.duplicate("█", 10)
    end

    test "50% progress renders half filled and half empty" do
      state = T.render(ProgressBar, progress: 0.5, width: 10, show_percentage: false)
      assert T.line(state, 0) == "" <> String.duplicate("█", 5) <> String.duplicate("░", 5)
    end

    test "percentage label shows the correct value" do
      # Total width includes the bar (10), the gap (1), and the percent text (3).
      state = T.render(ProgressBar, progress: 0.5, width: 14)

      assert T.line(state, 0) ==
               "" <> String.duplicate("█", 5) <> String.duplicate("░", 5) <> " 50%"
    end

    test "custom label appears before the bar" do
      # Total width: label (7) + gap + bar (10) + gap + percent (3) = 22
      state = T.render(ProgressBar, progress: 0.5, width: 22, label: "Loading")

      assert T.line(state, 0) ==
               "Loading " <> String.duplicate("█", 5) <> String.duplicate("░", 5) <> " 50%"
    end

    test "custom fill characters work" do
      state =
        T.render(ProgressBar,
          progress: 0.2,
          width: 10,
          show_percentage: false,
          filled_char: "=",
          empty_char: "-"
        )

      assert T.line(state, 0) == String.duplicate("=", 2) <> String.duplicate("-", 8)
    end
  end

  describe "set_progress/2" do
    test "clamps progress to 0.0..1.0" do
      model = ProgressBar.init([])

      model = ProgressBar.set_progress(model, -1.0)
      assert model.progress == 0.0

      model = ProgressBar.set_progress(model, 2.0)
      assert model.progress == 1.0
    end
  end

  describe "increment/2" do
    test "adds to progress and clamps" do
      model = ProgressBar.init(progress: 0.9)
      model = ProgressBar.increment(model, 0.5)
      assert model.progress == 1.0

      model = ProgressBar.increment(model, -2.0)
      assert model.progress == 0.0
    end
  end
end
