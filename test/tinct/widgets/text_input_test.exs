defmodule Tinct.Widgets.TextInputTest do
  use ExUnit.Case, async: true

  alias Tinct.Test
  alias Tinct.Widgets.TextInput

  doctest Tinct.Widgets.TextInput

  describe "init/1" do
    test "initializes with default values" do
      state = Test.render(TextInput, [])
      assert state.model.value == ""
      assert state.model.cursor_pos == 0
      assert state.model.placeholder == ""
      assert state.model.focused == false
      assert state.model.on_change == nil
      assert state.model.on_submit == nil
    end

    test "initializes with provided values" do
      state = Test.render(TextInput, value: "hello", placeholder: "type here")
      assert state.model.value == "hello"
      assert state.model.cursor_pos == 5
      assert state.model.placeholder == "type here"
    end

    test "cursor defaults to end of provided value" do
      state = Test.render(TextInput, value: "abc")
      assert state.model.cursor_pos == 3
    end

    test "cursor_pos can be overridden" do
      state = Test.render(TextInput, value: "abc", cursor_pos: 1)
      assert state.model.cursor_pos == 1
    end
  end

  describe "typing characters" do
    test "appends characters to empty input" do
      state = Test.render(TextInput, [])
      state = Test.send_key(state, "h")
      assert state.model.value == "h"
      assert state.model.cursor_pos == 1

      state = Test.send_key(state, "i")
      assert state.model.value == "hi"
      assert state.model.cursor_pos == 2
    end

    test "inserting in the middle of text works" do
      state = Test.render(TextInput, value: "hllo")
      # cursor is at end (4), move to pos 1
      state = Test.send_key(state, :home)
      state = Test.send_key(state, :right)
      assert state.model.cursor_pos == 1

      state = Test.send_key(state, "e")
      assert state.model.value == "hello"
      assert state.model.cursor_pos == 2
    end

    test "renders typed text in buffer" do
      state = Test.render(TextInput, [])
      state = Test.send_key(state, "a")
      state = Test.send_key(state, "b")
      state = Test.send_key(state, "c")
      assert Test.contains?(state, "abc")
    end
  end

  describe "backspace" do
    test "deletes character before cursor" do
      state = Test.render(TextInput, value: "hi")
      state = Test.send_key(state, :backspace)
      assert state.model.value == "h"
      assert state.model.cursor_pos == 1
    end

    test "does nothing when cursor at start" do
      state = Test.render(TextInput, value: "hi", cursor_pos: 0)
      state = Test.send_key(state, :backspace)
      assert state.model.value == "hi"
      assert state.model.cursor_pos == 0
    end

    test "deletes in the middle of text" do
      state = Test.render(TextInput, value: "abc", cursor_pos: 2)
      state = Test.send_key(state, :backspace)
      assert state.model.value == "ac"
      assert state.model.cursor_pos == 1
    end
  end

  describe "delete key" do
    test "removes character at cursor" do
      state = Test.render(TextInput, value: "hi", cursor_pos: 0)
      state = Test.send_key(state, :delete)
      assert state.model.value == "i"
      assert state.model.cursor_pos == 0
    end

    test "does nothing when cursor at end" do
      state = Test.render(TextInput, value: "hi")
      state = Test.send_key(state, :delete)
      assert state.model.value == "hi"
      assert state.model.cursor_pos == 2
    end

    test "deletes in the middle of text" do
      state = Test.render(TextInput, value: "abc", cursor_pos: 1)
      state = Test.send_key(state, :delete)
      assert state.model.value == "ac"
      assert state.model.cursor_pos == 1
    end
  end

  describe "arrow keys" do
    test "left arrow moves cursor left" do
      state = Test.render(TextInput, value: "hi")
      state = Test.send_key(state, :left)
      assert state.model.cursor_pos == 1
    end

    test "right arrow moves cursor right" do
      state = Test.render(TextInput, value: "hi", cursor_pos: 0)
      state = Test.send_key(state, :right)
      assert state.model.cursor_pos == 1
    end

    test "left arrow stops at 0" do
      state = Test.render(TextInput, value: "hi", cursor_pos: 0)
      state = Test.send_key(state, :left)
      assert state.model.cursor_pos == 0
    end

    test "right arrow stops at end of value" do
      state = Test.render(TextInput, value: "hi")
      state = Test.send_key(state, :right)
      assert state.model.cursor_pos == 2
    end
  end

  describe "home and end" do
    test "home moves cursor to start" do
      state = Test.render(TextInput, value: "hello")
      state = Test.send_key(state, :home)
      assert state.model.cursor_pos == 0
    end

    test "end moves cursor to end" do
      state = Test.render(TextInput, value: "hello", cursor_pos: 0)
      state = Test.send_key(state, :end)
      assert state.model.cursor_pos == 5
    end
  end

  describe "enter and on_submit" do
    test "triggers on_submit with current value" do
      state = Test.render(TextInput, value: "hello", on_submit: :submitted)
      {_state, cmd} = Test.send_key_raw(state, :enter)
      assert cmd == {:submitted, "hello"}
    end

    test "returns nil command when on_submit is nil" do
      state = Test.render(TextInput, value: "hello")
      {_state, cmd} = Test.send_key_raw(state, :enter)
      assert cmd == nil
    end
  end

  describe "on_change" do
    test "emits change when typing with on_change set" do
      state = Test.render(TextInput, on_change: :changed)
      {state, cmd} = Test.send_key_raw(state, "a")
      assert cmd == {:changed, "a"}
      assert state.model.value == "a"
    end

    test "emits change on backspace" do
      state = Test.render(TextInput, value: "hi", on_change: :changed)
      {_state, cmd} = Test.send_key_raw(state, :backspace)
      assert cmd == {:changed, "h"}
    end

    test "does not emit when on_change is nil" do
      state = Test.render(TextInput, [])
      {_state, cmd} = Test.send_key_raw(state, "a")
      assert cmd == nil
    end
  end

  describe "placeholder" do
    test "shows placeholder when value is empty" do
      state = Test.render(TextInput, placeholder: "Type here...")
      assert Test.contains?(state, "Type here...")
    end

    test "hides placeholder when value is present" do
      state = Test.render(TextInput, value: "hi", placeholder: "Type here...")
      refute Test.contains?(state, "Type here...")
      assert Test.contains?(state, "hi")
    end

    test "placeholder disappears after typing" do
      state = Test.render(TextInput, placeholder: "Type here...")
      assert Test.contains?(state, "Type here...")

      state = Test.send_key(state, "x")
      refute Test.contains?(state, "Type here...")
      assert Test.contains?(state, "x")
    end
  end

  describe "ctrl shortcuts" do
    test "ctrl+a moves cursor to start" do
      state = Test.render(TextInput, value: "hello")
      state = Test.send_key(state, "a", [:ctrl])
      assert state.model.cursor_pos == 0
    end

    test "ctrl+e moves cursor to end" do
      state = Test.render(TextInput, value: "hello", cursor_pos: 0)
      state = Test.send_key(state, "e", [:ctrl])
      assert state.model.cursor_pos == 5
    end
  end

  describe "cursor position tracking" do
    test "tracks correctly through mixed edits" do
      state = Test.render(TextInput, [])

      # Type "abc"
      state = Test.send_key(state, "a")
      state = Test.send_key(state, "b")
      state = Test.send_key(state, "c")
      assert state.model.cursor_pos == 3
      assert state.model.value == "abc"

      # Move left twice → cursor at 1
      state = Test.send_key(state, :left)
      state = Test.send_key(state, :left)
      assert state.model.cursor_pos == 1

      # Insert "x" at position 1
      state = Test.send_key(state, "x")
      assert state.model.value == "axbc"
      assert state.model.cursor_pos == 2

      # Backspace removes "x"
      state = Test.send_key(state, :backspace)
      assert state.model.value == "abc"
      assert state.model.cursor_pos == 1
    end
  end

  describe "view/1" do
    test "sets cursor when focused" do
      state = Test.render(TextInput, value: "hi", focused: true, cursor_pos: 1)
      assert state.view.cursor != nil
      assert state.view.cursor.x == 1
      assert state.view.cursor.y == 0
      assert state.view.cursor.shape == :bar
    end

    test "hides cursor when unfocused" do
      state = Test.render(TextInput, value: "hi", focused: false)
      assert state.view.cursor == nil
    end
  end

  describe "API functions" do
    test "set_value/2 updates value and moves cursor to end" do
      model = TextInput.init([])
      model = TextInput.set_value(model, "new value")
      assert model.value == "new value"
      assert model.cursor_pos == 9
    end

    test "clear/1 resets value and cursor" do
      model = TextInput.init(value: "hello")
      model = TextInput.clear(model)
      assert model.value == ""
      assert model.cursor_pos == 0
    end

    test "focus/1 sets focused to true" do
      model = TextInput.init([])
      model = TextInput.focus(model)
      assert model.focused == true
    end

    test "blur/1 sets focused to false" do
      model = TextInput.init(focused: true)
      model = TextInput.blur(model)
      assert model.focused == false
    end
  end

  describe "unknown messages" do
    test "ignores unknown key events" do
      state = Test.render(TextInput, value: "hi")
      state = Test.send_key(state, :f1)
      assert state.model.value == "hi"
      assert state.model.cursor_pos == 2
    end

    test "ignores non-key events" do
      state = Test.render(TextInput, value: "hi")
      state = Test.send_event(state, :some_random_message)
      assert state.model.value == "hi"
    end
  end
end
