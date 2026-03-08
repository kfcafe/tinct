defmodule Tinct.CursorTest do
  use ExUnit.Case, async: true

  alias Tinct.Cursor

  doctest Cursor

  describe "new/2" do
    test "creates cursor at given position with default fields" do
      cursor = Cursor.new(5, 10)

      assert cursor.x == 5
      assert cursor.y == 10
      assert cursor.shape == :block
      assert cursor.blink == false
      assert cursor.color == nil
      assert cursor.visible == true
    end

    test "creates cursor at origin {0, 0}" do
      cursor = Cursor.new(0, 0)

      assert cursor.x == 0
      assert cursor.y == 0
    end

    test "creates cursor at large coordinates" do
      cursor = Cursor.new(10_000, 50_000)

      assert cursor.x == 10_000
      assert cursor.y == 50_000
    end

    test "raises on negative x" do
      assert_raise FunctionClauseError, fn -> Cursor.new(-1, 0) end
    end

    test "raises on negative y" do
      assert_raise FunctionClauseError, fn -> Cursor.new(0, -1) end
    end

    test "raises on non-integer x" do
      assert_raise FunctionClauseError, fn -> Cursor.new(1.5, 0) end
    end

    test "raises on non-integer y" do
      assert_raise FunctionClauseError, fn -> Cursor.new(0, "2") end
    end
  end

  describe "new/3" do
    test "accepts :shape option" do
      assert Cursor.new(0, 0, shape: :block).shape == :block
      assert Cursor.new(0, 0, shape: :underline).shape == :underline
      assert Cursor.new(0, 0, shape: :bar).shape == :bar
    end

    test "accepts :blink option" do
      assert Cursor.new(0, 0, blink: true).blink == true
      assert Cursor.new(0, 0, blink: false).blink == false
    end

    test "accepts :color option" do
      assert Cursor.new(0, 0, color: :red).color == :red
      assert Cursor.new(0, 0, color: nil).color == nil
    end

    test "accepts :visible option" do
      assert Cursor.new(0, 0, visible: false).visible == false
      assert Cursor.new(0, 0, visible: true).visible == true
    end

    test "defaults when options omitted" do
      cursor = Cursor.new(1, 2, [])

      assert cursor.shape == :block
      assert cursor.blink == false
      assert cursor.color == nil
      assert cursor.visible == true
    end

    test "unknown options are ignored" do
      cursor = Cursor.new(1, 1, foo: :bar, baz: 42)

      assert cursor.shape == :block
      assert cursor.blink == false
    end

    test "multiple options combined" do
      cursor = Cursor.new(3, 7, shape: :bar, blink: true, color: :green, visible: false)

      assert cursor.x == 3
      assert cursor.y == 7
      assert cursor.shape == :bar
      assert cursor.blink == true
      assert cursor.color == :green
      assert cursor.visible == false
    end

    test "raises on negative coordinates with options" do
      assert_raise FunctionClauseError, fn -> Cursor.new(-1, 0, shape: :bar) end
      assert_raise FunctionClauseError, fn -> Cursor.new(0, -1, shape: :bar) end
    end

    test "raises on non-integer coordinates with options" do
      assert_raise FunctionClauseError, fn -> Cursor.new(1.0, 0, []) end
      assert_raise FunctionClauseError, fn -> Cursor.new(0, :zero, []) end
    end
  end
end
