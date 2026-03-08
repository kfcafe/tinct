defmodule Tinct.Buffer do
  @moduledoc """
  A 2D grid of cells representing the terminal screen.

  The buffer uses a map of `{col, row}` tuples to `Tinct.Buffer.Cell` structs
  for O(1) random access and efficient sparse storage. Coordinates are zero-indexed
  with `{0, 0}` at the top-left corner.

  ## Examples

      iex> buf = Tinct.Buffer.new(80, 24)
      iex> buf.width
      80
      iex> buf.height
      24
  """

  alias Tinct.Buffer.Cell

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          cells: %{optional({non_neg_integer(), non_neg_integer()}) => Cell.t()}
        }

  defstruct width: 0,
            height: 0,
            cells: %{}

  @doc """
  Creates a buffer of the given dimensions filled with empty cells.

  ## Examples

      iex> buf = Tinct.Buffer.new(10, 5)
      iex> {buf.width, buf.height}
      {10, 5}
  """
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(width, height)
      when is_integer(width) and is_integer(height) and width >= 0 and height >= 0 do
    default = Cell.new()

    cells =
      for col <- 0..(width - 1)//1,
          row <- 0..(height - 1)//1,
          into: %{} do
        {{col, row}, default}
      end

    %__MODULE__{width: width, height: height, cells: cells}
  end

  @doc """
  Gets the cell at the given column and row.

  Returns a default (empty) cell if the coordinates are out of bounds.

  ## Examples

      iex> buf = Tinct.Buffer.new(10, 5)
      iex> cell = Tinct.Buffer.get(buf, 0, 0)
      iex> cell.char
      " "
  """
  @spec get(t(), integer(), integer()) :: Cell.t()
  def get(%__MODULE__{} = buffer, col, row) do
    Map.get(buffer.cells, {col, row}, Cell.new())
  end

  @doc """
  Sets the cell at the given column and row.

  Returns the buffer unchanged if the coordinates are out of bounds.

  ## Examples

      iex> buf = Tinct.Buffer.new(10, 5)
      iex> cell = Tinct.Buffer.Cell.new(char: "X")
      iex> buf = Tinct.Buffer.put(buf, 0, 0, cell)
      iex> Tinct.Buffer.get(buf, 0, 0).char
      "X"
  """
  @spec put(t(), non_neg_integer(), non_neg_integer(), Cell.t()) :: t()
  def put(%__MODULE__{} = buffer, col, row, %Cell{} = cell) do
    if col >= 0 and col < buffer.width and row >= 0 and row < buffer.height do
      %{buffer | cells: Map.put(buffer.cells, {col, row}, cell)}
    else
      buffer
    end
  end

  @doc """
  Writes a string starting at the given column and row with the given style.

  Each grapheme cluster in the string occupies one cell, advancing the column
  by one. Characters that would extend past the buffer width are truncated.

  ## Style Options

  Accepts any keyword option valid for `Tinct.Buffer.Cell.new/1` except `:char`,
  which is set from the string's grapheme clusters.

  ## Examples

      iex> buf = Tinct.Buffer.new(10, 1)
      iex> buf = Tinct.Buffer.put_string(buf, 0, 0, "Hi", fg: :green)
      iex> Tinct.Buffer.get(buf, 0, 0).char
      "H"
      iex> Tinct.Buffer.get(buf, 1, 0).char
      "i"
      iex> Tinct.Buffer.get(buf, 0, 0).fg
      :green
  """
  @spec put_string(t(), non_neg_integer(), non_neg_integer(), String.t(), keyword()) :: t()
  def put_string(%__MODULE__{} = buffer, col, row, string, style \\ [])
      when is_binary(string) and is_list(style) do
    if row < 0 or row >= buffer.height do
      buffer
    else
      string
      |> String.graphemes()
      |> Enum.with_index(col)
      |> Enum.reduce(buffer, fn {grapheme, current_col}, acc ->
        put_string_grapheme(acc, current_col, row, grapheme, style)
      end)
    end
  end

  defp put_string_grapheme(%__MODULE__{} = buffer, col, row, grapheme, style)
       when is_integer(col) and is_integer(row) and is_binary(grapheme) and is_list(style) do
    if col >= 0 and col < buffer.width do
      cell = Cell.new(Keyword.put(style, :char, grapheme))
      %{buffer | cells: Map.put(buffer.cells, {col, row}, cell)}
    else
      buffer
    end
  end

  @doc """
  Resets all cells in the buffer to the default empty cell.

  ## Examples

      iex> buf = Tinct.Buffer.new(10, 5)
      iex> buf = Tinct.Buffer.put_string(buf, 0, 0, "Hello")
      iex> buf = Tinct.Buffer.clear(buf)
      iex> Tinct.Buffer.get(buf, 0, 0).char
      " "
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = buffer) do
    new(buffer.width, buffer.height)
  end

  @doc """
  Resizes the buffer to new dimensions, preserving cells that fit within the
  new bounds. New cells are filled with defaults.

  ## Examples

      iex> buf = Tinct.Buffer.new(5, 5)
      iex> buf = Tinct.Buffer.put_string(buf, 0, 0, "AB")
      iex> buf = Tinct.Buffer.resize(buf, 10, 10)
      iex> Tinct.Buffer.get(buf, 0, 0).char
      "A"
      iex> Tinct.Buffer.get(buf, 1, 0).char
      "B"
  """
  @spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
  def resize(%__MODULE__{} = buffer, new_width, new_height)
      when is_integer(new_width) and is_integer(new_height) and new_width >= 0 and new_height >= 0 do
    new_buffer = new(new_width, new_height)

    cells =
      Enum.reduce(buffer.cells, new_buffer.cells, fn {{col, row}, cell}, acc ->
        if col < new_width and row < new_height do
          Map.put(acc, {col, row}, cell)
        else
          acc
        end
      end)

    %{new_buffer | cells: cells}
  end

  @doc """
  Extracts a rectangular sub-buffer from the given buffer.

  The sub-buffer starts at `(x, y)` with the given width and height. Cells
  outside the source buffer bounds are filled with defaults.

  ## Examples

      iex> buf = Tinct.Buffer.new(10, 10)
      iex> buf = Tinct.Buffer.put_string(buf, 2, 3, "Hi")
      iex> sub = Tinct.Buffer.region(buf, 2, 3, 4, 1)
      iex> Tinct.Buffer.get(sub, 0, 0).char
      "H"
      iex> Tinct.Buffer.get(sub, 1, 0).char
      "i"
  """
  @spec region(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          t()
  def region(%__MODULE__{} = buffer, x, y, width, height)
      when is_integer(x) and is_integer(y) and is_integer(width) and is_integer(height) and
             width >= 0 and height >= 0 do
    sub = new(width, height)

    cells =
      for col <- 0..(width - 1)//1,
          row <- 0..(height - 1)//1,
          into: sub.cells do
        source_cell = get(buffer, x + col, y + row)
        {{col, row}, source_cell}
      end

    %{sub | cells: cells}
  end
end
