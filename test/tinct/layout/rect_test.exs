defmodule Tinct.Layout.RectTest do
  use ExUnit.Case, async: true

  alias Tinct.Layout.Rect

  doctest Rect

  describe "new/4" do
    test "creates a rect with the given position and dimensions" do
      rect = Rect.new(3, 7, 20, 10)

      assert rect.x == 3
      assert rect.y == 7
      assert rect.width == 20
      assert rect.height == 10
    end

    test "zero dimensions are valid" do
      rect = Rect.new(5, 5, 0, 0)

      assert rect.x == 5
      assert rect.y == 5
      assert rect.width == 0
      assert rect.height == 0
    end
  end

  describe "contains?/3" do
    test "point inside the rect returns true" do
      rect = Rect.new(10, 10, 20, 20)

      assert Rect.contains?(rect, 15, 15)
    end

    test "point on the origin edge returns true (inclusive)" do
      rect = Rect.new(5, 5, 10, 10)

      assert Rect.contains?(rect, 5, 5)
      assert Rect.contains?(rect, 5, 10)
      assert Rect.contains?(rect, 10, 5)
    end

    test "point on the far edge returns false (exclusive)" do
      rect = Rect.new(5, 5, 10, 10)

      # x + width = 15, y + height = 15
      refute Rect.contains?(rect, 15, 5)
      refute Rect.contains?(rect, 5, 15)
      refute Rect.contains?(rect, 15, 15)
    end

    test "point outside the rect returns false" do
      rect = Rect.new(10, 10, 5, 5)

      refute Rect.contains?(rect, 0, 0)
      refute Rect.contains?(rect, 20, 20)
      refute Rect.contains?(rect, 10, 20)
    end

    test "zero-size rect contains nothing" do
      rect = Rect.new(5, 5, 0, 0)

      refute Rect.contains?(rect, 5, 5)
      refute Rect.contains?(rect, 0, 0)
    end

    test "negative point coordinates return false" do
      rect = Rect.new(0, 0, 10, 10)

      refute Rect.contains?(rect, -1, 5)
      refute Rect.contains?(rect, 5, -1)
      refute Rect.contains?(rect, -1, -1)
    end
  end

  describe "intersect/2" do
    test "overlapping rects return the intersection" do
      a = Rect.new(0, 0, 10, 10)
      b = Rect.new(5, 5, 10, 10)

      assert Rect.intersect(a, b) == Rect.new(5, 5, 5, 5)
    end

    test "non-overlapping rects return nil" do
      a = Rect.new(0, 0, 5, 5)
      b = Rect.new(10, 10, 5, 5)

      assert Rect.intersect(a, b) == nil
    end

    test "one rect fully inside another returns the inner rect" do
      outer = Rect.new(0, 0, 20, 20)
      inner = Rect.new(5, 5, 3, 3)

      assert Rect.intersect(outer, inner) == Rect.new(5, 5, 3, 3)
      assert Rect.intersect(inner, outer) == Rect.new(5, 5, 3, 3)
    end

    test "adjacent rects touching at edge return nil (no overlap)" do
      a = Rect.new(0, 0, 10, 10)
      b = Rect.new(10, 0, 10, 10)

      assert Rect.intersect(a, b) == nil
    end

    test "same rect returns identical rect" do
      rect = Rect.new(3, 4, 10, 8)

      assert Rect.intersect(rect, rect) == Rect.new(3, 4, 10, 8)
    end

    test "zero-size rect intersection returns nil" do
      a = Rect.new(5, 5, 0, 0)
      b = Rect.new(5, 5, 10, 10)

      assert Rect.intersect(a, b) == nil
    end

    test "partial overlap at one corner" do
      a = Rect.new(0, 0, 5, 5)
      b = Rect.new(3, 3, 5, 5)

      assert Rect.intersect(a, b) == Rect.new(3, 3, 2, 2)
    end
  end

  describe "empty?/1" do
    test "zero width returns true" do
      assert Rect.empty?(Rect.new(1, 1, 0, 5))
    end

    test "zero height returns true" do
      assert Rect.empty?(Rect.new(1, 1, 5, 0))
    end

    test "both zero returns true" do
      assert Rect.empty?(Rect.new(0, 0, 0, 0))
    end

    test "non-zero width and height returns false" do
      refute Rect.empty?(Rect.new(0, 0, 1, 1))
    end
  end
end
