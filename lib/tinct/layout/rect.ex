defmodule Tinct.Layout.Rect do
  @moduledoc """
  A positioned rectangle on the screen.

  Represents a rectangular region with an origin `(x, y)` and dimensions
  `(width, height)`. Used by the layout engine to track where each element
  lands on screen, and for hit-testing (e.g. mouse clicks).

  ## Examples

      iex> rect = Tinct.Layout.Rect.new(5, 10, 20, 8)
      iex> Tinct.Layout.Rect.contains?(rect, 15, 14)
      true

      iex> rect = Tinct.Layout.Rect.new(0, 0, 0, 0)
      iex> Tinct.Layout.Rect.empty?(rect)
      true
  """

  @typedoc "A positioned rectangle with origin and dimensions."
  @type t :: %__MODULE__{
          x: non_neg_integer(),
          y: non_neg_integer(),
          width: non_neg_integer(),
          height: non_neg_integer()
        }

  defstruct x: 0, y: 0, width: 0, height: 0

  @doc """
  Creates a new rectangle from origin and dimensions.

  ## Examples

      iex> Tinct.Layout.Rect.new(1, 2, 10, 5)
      %Tinct.Layout.Rect{x: 1, y: 2, width: 10, height: 5}
  """
  @spec new(non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  def new(x, y, width, height) do
    %__MODULE__{x: x, y: y, width: width, height: height}
  end

  @doc """
  Returns `true` if the point `(px, py)` lies within the rectangle.

  The check is inclusive of the origin and exclusive of the far edge:
  a point at `(x + width, y)` is outside the rectangle.

  ## Examples

      iex> rect = Tinct.Layout.Rect.new(5, 5, 10, 10)
      iex> Tinct.Layout.Rect.contains?(rect, 5, 5)
      true

      iex> rect = Tinct.Layout.Rect.new(5, 5, 10, 10)
      iex> Tinct.Layout.Rect.contains?(rect, 15, 5)
      false
  """
  @spec contains?(t(), integer(), integer()) :: boolean()
  def contains?(%__MODULE__{x: x, y: y, width: w, height: h}, px, py) do
    px >= x and px < x + w and py >= y and py < y + h
  end

  @doc """
  Returns the intersection of two rectangles, or `nil` if they don't overlap.

  ## Examples

      iex> a = Tinct.Layout.Rect.new(0, 0, 10, 10)
      iex> b = Tinct.Layout.Rect.new(5, 5, 10, 10)
      iex> Tinct.Layout.Rect.intersect(a, b)
      %Tinct.Layout.Rect{x: 5, y: 5, width: 5, height: 5}

      iex> a = Tinct.Layout.Rect.new(0, 0, 5, 5)
      iex> b = Tinct.Layout.Rect.new(10, 10, 5, 5)
      iex> Tinct.Layout.Rect.intersect(a, b)
      nil
  """
  @spec intersect(t(), t()) :: t() | nil
  def intersect(%__MODULE__{} = a, %__MODULE__{} = b) do
    x1 = max(a.x, b.x)
    y1 = max(a.y, b.y)
    x2 = min(a.x + a.width, b.x + b.width)
    y2 = min(a.y + a.height, b.y + b.height)

    if x2 > x1 and y2 > y1 do
      %__MODULE__{x: x1, y: y1, width: x2 - x1, height: y2 - y1}
    else
      nil
    end
  end

  @doc """
  Returns `true` if the rectangle has zero width or zero height.

  ## Examples

      iex> Tinct.Layout.Rect.empty?(%Tinct.Layout.Rect{width: 0, height: 5})
      true

      iex> Tinct.Layout.Rect.empty?(%Tinct.Layout.Rect{width: 10, height: 5})
      false
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{width: w, height: h}) do
    w == 0 or h == 0
  end
end
