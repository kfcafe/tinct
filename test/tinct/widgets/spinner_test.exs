defmodule Tinct.Widgets.SpinnerTest do
  use ExUnit.Case, async: true

  alias Tinct.Test, as: T
  alias Tinct.Widgets.Spinner

  doctest Tinct.Widgets.Spinner

  describe "view/1" do
    test "initial render shows the first frame" do
      state = T.render(Spinner, [])
      assert T.line(state, 0) == "⠋"
    end

    test "label appears after the spinner character" do
      state = T.render(Spinner, label: "Loading...")
      assert T.line(state, 0) == "⠋ Loading..."
    end

    test "custom color applies to the spinner character" do
      state = T.render(Spinner, color: :red)
      assert T.cell_at(state, 0, 0).fg == :red
    end
  end

  describe "handle_tick/1" do
    test "tick advances to the next frame" do
      model = Spinner.init(style: :line)
      assert render_line(model) == "-"

      model = Spinner.handle_tick(model)
      assert render_line(model) == "\\"
    end

    test "frame wraps around at the end of the sequence" do
      model = Spinner.init(style: :line)
      last_frame_index = Spinner.frame_count(:line) - 1
      model = %{model | frame: last_frame_index}

      model = Spinner.handle_tick(model)
      assert render_line(model) == "-"
    end
  end

  describe "built-in styles" do
    test "different spinner styles have correct frame counts" do
      assert Spinner.frame_count(:dots) == 10
      assert Spinner.frame_count(:line) == 4
      assert Spinner.frame_count(:arc) == 6
      assert Spinner.frame_count(:bounce) == 4
      assert Spinner.frame_count(:dots2) == 8
      assert Spinner.frame_count(:simple) == 4
    end
  end

  defp render_line(model) do
    model
    |> Spinner.view()
    |> T.render_view({20, 1})
  end
end
