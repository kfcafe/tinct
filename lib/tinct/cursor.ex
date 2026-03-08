defmodule Tinct.Cursor do
  @moduledoc """
  Declarative cursor state for terminal UI views.

  A `Cursor` describes the desired cursor position, shape, and visibility.
  The framework compares consecutive cursors to emit the minimal terminal
  escape sequences needed to update the cursor state.

  ## Shapes

    * `:block` — solid block cursor (default)
    * `:underline` — underline cursor
    * `:bar` — vertical bar cursor

  ## Examples

      Cursor.new(0, 0)
      Cursor.new(10, 5, shape: :bar, blink: true)
  """

  alias Tinct.Color

  @typedoc "Cursor shape."
  @type shape :: :block | :underline | :bar

  @typedoc "A declarative cursor state."
  @type t :: %__MODULE__{
          x: non_neg_integer(),
          y: non_neg_integer(),
          shape: shape(),
          blink: boolean(),
          color: Color.t() | nil,
          visible: boolean()
        }

  defstruct x: 0,
            y: 0,
            shape: :block,
            blink: false,
            color: nil,
            visible: true

  @doc """
  Creates a block cursor at the given position.

  ## Examples

      iex> cursor = Tinct.Cursor.new(5, 10)
      iex> {cursor.x, cursor.y, cursor.shape}
      {5, 10, :block}
  """
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(x, y) when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    %__MODULE__{x: x, y: y}
  end

  @doc """
  Creates a cursor at the given position with options.

  ## Options

    * `:shape` — cursor shape: `:block`, `:underline`, or `:bar` (default `:block`)
    * `:blink` — whether the cursor blinks (default `false`)
    * `:color` — cursor color as a `Tinct.Color.t()` or `nil` for default (default `nil`)
    * `:visible` — whether the cursor is visible (default `true`)

  ## Examples

      iex> cursor = Tinct.Cursor.new(0, 0, shape: :bar, blink: true)
      iex> {cursor.shape, cursor.blink}
      {:bar, true}

      iex> cursor = Tinct.Cursor.new(3, 7, color: :green, visible: false)
      iex> {cursor.color, cursor.visible}
      {:green, false}
  """
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  def new(x, y, opts)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 and is_list(opts) do
    %__MODULE__{
      x: x,
      y: y,
      shape: Keyword.get(opts, :shape, :block),
      blink: Keyword.get(opts, :blink, false),
      color: Keyword.get(opts, :color, nil),
      visible: Keyword.get(opts, :visible, true)
    }
  end
end
