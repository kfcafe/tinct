defmodule Tinct.TestHelpersTest do
  use ExUnit.Case, async: true

  alias Tinct.{Buffer, Command, Element, Event, View}
  alias Tinct.Test, as: T

  # --- Test component: a counter that responds to key events ---

  defmodule TestCounter do
    @moduledoc false
    use Tinct.Component

    @impl true
    def init(opts), do: Keyword.get(opts, :start, 0)

    @impl true
    def update(count, %Event.Key{key: :up}), do: count + 1
    def update(count, %Event.Key{key: :down}), do: count - 1
    def update(_count, %Event.Key{key: "q"}), do: {0, Command.quit()}
    def update(count, %Event.Key{key: "c", mod: [:ctrl]}), do: {count, Command.quit()}
    def update(count, _msg), do: count

    @impl true
    def view(count) do
      View.new(
        Element.column([], [
          Element.text("Counter"),
          Element.text("Count: #{count}"),
          Element.text("Press up/down")
        ])
      )
    end
  end

  # --- render/2 ---

  describe "render/2" do
    test "returns a State struct with rendered content" do
      state = T.render(TestCounter, [])
      assert %T.State{} = state
      assert state.component == TestCounter
      assert state.model == 0
      assert state.size == {80, 24}
    end

    test "renders component view into buffer" do
      state = T.render(TestCounter, [])
      assert T.contains?(state, "Count: 0")
      assert T.contains?(state, "Counter")
    end

    test "initializes with custom options" do
      state = T.render(TestCounter, start: 5)
      assert state.model == 5
      assert T.contains?(state, "Count: 5")
    end
  end

  # --- render/3 ---

  describe "render/3" do
    test "accepts custom size" do
      state = T.render(TestCounter, [], size: {40, 10})
      assert state.size == {40, 10}
      assert state.buffer.width == 40
      assert state.buffer.height == 10
    end

    test "renders correctly at custom size" do
      state = T.render(TestCounter, [], size: {40, 10})
      assert T.contains?(state, "Count: 0")
    end
  end

  # --- render_view/2 ---

  describe "render_view/2" do
    test "renders a view to text" do
      view = View.new(Element.text("hello world"))
      text = T.render_view(view, {80, 24})
      assert text =~ "hello world"
    end

    test "renders column layout to multiple lines" do
      view =
        View.new(
          Element.column([], [
            Element.text("line one"),
            Element.text("line two")
          ])
        )

      text = T.render_view(view, {80, 24})
      assert text =~ "line one"
      assert text =~ "line two"
    end
  end

  # --- contains?/2 ---

  describe "contains?/2" do
    test "finds text in rendered output" do
      state = T.render(TestCounter, [])
      assert T.contains?(state, "Count: 0")
      assert T.contains?(state, "Counter")
      assert T.contains?(state, "Press up/down")
    end

    test "returns false when text is absent" do
      state = T.render(TestCounter, [])
      refute T.contains?(state, "not here")
    end
  end

  # --- send_key/2 ---

  describe "send_key/2" do
    test "triggers update and re-render" do
      state = T.render(TestCounter, [])
      assert T.contains?(state, "Count: 0")

      state = T.send_key(state, :up)
      assert T.contains?(state, "Count: 1")
    end

    test "works with down arrow" do
      state = T.render(TestCounter, [])
      state = T.send_key(state, :down)
      assert T.contains?(state, "Count: -1")
    end

    test "accepts string keys" do
      state = T.render(TestCounter, [])
      state = T.send_key(state, "q")
      assert T.contains?(state, "Count: 0")
    end
  end

  # --- send_key/3 ---

  describe "send_key/3" do
    test "sends key with modifiers" do
      state = T.render(TestCounter, [])
      state = T.send_key(state, :up)
      assert state.model == 1

      # ctrl+c triggers quit command but model stays at 1
      state = T.send_key(state, "c", [:ctrl])
      assert state.model == 1
    end
  end

  # --- send_key_raw/2 ---

  describe "send_key_raw/2" do
    test "returns state and command" do
      state = T.render(TestCounter, [])
      {new_state, cmd} = T.send_key_raw(state, "q")
      assert cmd == :quit
      assert new_state.model == 0
    end

    test "returns nil command when no side effect" do
      state = T.render(TestCounter, [])
      {new_state, cmd} = T.send_key_raw(state, :up)
      assert cmd == nil
      assert new_state.model == 1
    end
  end

  # --- send_key_raw/3 ---

  describe "send_key_raw/3" do
    test "returns state and command with modifiers" do
      state = T.render(TestCounter, [])
      state = T.send_key(state, :up)

      {new_state, cmd} = T.send_key_raw(state, "c", [:ctrl])
      assert cmd == :quit
      assert new_state.model == 1
    end
  end

  # --- send_event/2 ---

  describe "send_event/2" do
    test "sends arbitrary event and re-renders" do
      state = T.render(TestCounter, [])
      state = T.send_event(state, Event.key(:up))
      assert T.contains?(state, "Count: 1")
    end
  end

  # --- line/2 ---

  describe "line/2" do
    test "extracts specific line by index" do
      state = T.render(TestCounter, [])
      assert T.line(state, 0) == "Counter"
      assert T.line(state, 1) == "Count: 0"
      assert T.line(state, 2) == "Press up/down"
    end

    test "returns nil for out-of-bounds line" do
      state = T.render(TestCounter, [], size: {80, 3})
      assert T.line(state, 100) == nil
    end

    test "returns empty string for blank lines" do
      state = T.render(TestCounter, [])
      # Lines beyond the rendered text are blank
      assert T.line(state, 23) == ""
    end
  end

  # --- cell_at/3 ---

  describe "cell_at/3" do
    test "returns cell at position" do
      state = T.render(TestCounter, [])
      cell = T.cell_at(state, 0, 0)
      assert cell.char == "C"
    end

    test "returns default cell for empty position" do
      state = T.render(TestCounter, [])
      cell = T.cell_at(state, 79, 23)
      assert cell.char == " "
    end
  end

  # --- assert_contains/2 ---

  describe "assert_contains/2" do
    test "returns :ok when text is found" do
      state = T.render(TestCounter, [])
      assert :ok == T.assert_contains(state, "Count: 0")
    end

    test "raises ExUnit.AssertionError when text is not found" do
      state = T.render(TestCounter, [])

      error =
        assert_raise ExUnit.AssertionError, fn ->
          T.assert_contains(state, "not here")
        end

      assert error.message =~ "not here"
      assert error.message =~ "Expected rendered output to contain"
    end
  end

  # --- to_text/1 ---

  describe "to_text/1" do
    test "converts state to readable string" do
      state = T.render(TestCounter, [])
      text = T.to_text(state)
      assert is_binary(text)
      assert text =~ "Counter"
      assert text =~ "Count: 0"
      assert text =~ "Press up/down"
    end
  end

  # --- to_buffer/1 ---

  describe "to_buffer/1" do
    test "returns the raw buffer" do
      state = T.render(TestCounter, [])
      buffer = T.to_buffer(state)
      assert %Buffer{} = buffer
      assert buffer.width == 80
      assert buffer.height == 24
    end
  end

  # --- Full round-trip ---

  describe "full round-trip with counter" do
    test "increment, decrement, and quit" do
      state = T.render(TestCounter, [])
      assert T.contains?(state, "Count: 0")

      state = T.send_key(state, :up)
      assert T.contains?(state, "Count: 1")

      state = T.send_key(state, :up)
      assert T.contains?(state, "Count: 2")

      state = T.send_key(state, :down)
      assert T.contains?(state, "Count: 1")

      {_state, cmd} = T.send_key_raw(state, "q")
      assert cmd == :quit
    end

    test "model updates are reflected in buffer and text" do
      state = T.render(TestCounter, start: 10)
      assert T.line(state, 1) == "Count: 10"

      state = T.send_key(state, :up)
      assert T.line(state, 1) == "Count: 11"

      text = T.to_text(state)
      assert text =~ "Count: 11"

      buffer = T.to_buffer(state)
      # "C" at column 0, row 1 (the "Count:" line)
      assert Buffer.get(buffer, 0, 1).char == "C"
    end
  end
end
