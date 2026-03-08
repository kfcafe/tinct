defmodule Tinct.Buffer.Cell do
  @moduledoc """
  A single terminal cell containing a character, colors, and text attributes.

  Cells are the atomic unit of the rendering engine. Each cell in a `Tinct.Buffer`
  holds one grapheme cluster, foreground/background colors, and style flags.

  ## Examples

      iex> Tinct.Buffer.Cell.new()
      %Tinct.Buffer.Cell{char: " ", fg: :default, bg: :default}

      iex> Tinct.Buffer.Cell.new(char: "A", fg: :red, bold: true)
      %Tinct.Buffer.Cell{char: "A", fg: :red, bold: true}
  """

  @type color ::
          atom() | {non_neg_integer(), non_neg_integer(), non_neg_integer()} | non_neg_integer()

  @type t :: %__MODULE__{
          char: String.t(),
          fg: color(),
          bg: color(),
          bold: boolean(),
          italic: boolean(),
          underline: boolean(),
          strikethrough: boolean(),
          dim: boolean(),
          inverse: boolean()
        }

  defstruct char: " ",
            fg: :default,
            bg: :default,
            bold: false,
            italic: false,
            underline: false,
            strikethrough: false,
            dim: false,
            inverse: false

  @doc """
  Creates an empty cell with default values (space character, default colors, no styles).

  ## Examples

      iex> Tinct.Buffer.Cell.new()
      %Tinct.Buffer.Cell{char: " ", fg: :default, bg: :default}
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Creates a cell with the given options.

  ## Options

    * `:char` - single grapheme cluster (default: `" "`)
    * `:fg` - foreground color (default: `:default`)
    * `:bg` - background color (default: `:default`)
    * `:bold` - bold text (default: `false`)
    * `:italic` - italic text (default: `false`)
    * `:underline` - underlined text (default: `false`)
    * `:strikethrough` - strikethrough text (default: `false`)
    * `:dim` - dim/faint text (default: `false`)
    * `:inverse` - swap foreground and background (default: `false`)

  ## Examples

      iex> Tinct.Buffer.Cell.new(char: "X", fg: :green, bold: true)
      %Tinct.Buffer.Cell{char: "X", fg: :green, bold: true}
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts), do: struct(__MODULE__, opts)

  @doc """
  Returns the default cell — equivalent to `new/0`.

  Useful as a constant for comparisons and clearing operations.

  ## Examples

      iex> Tinct.Buffer.Cell.reset()
      %Tinct.Buffer.Cell{char: " ", fg: :default, bg: :default}
  """
  @spec reset() :: t()
  def reset, do: %__MODULE__{}

  @doc """
  Compares two cells for equality across all fields.

  Used by the diff algorithm to detect which cells have changed between frames.

  ## Examples

      iex> a = Tinct.Buffer.Cell.new(char: "A")
      iex> b = Tinct.Buffer.Cell.new(char: "A")
      iex> Tinct.Buffer.Cell.equal?(a, b)
      true

      iex> a = Tinct.Buffer.Cell.new(char: "A")
      iex> b = Tinct.Buffer.Cell.new(char: "B")
      iex> Tinct.Buffer.Cell.equal?(a, b)
      false
  """
  @spec equal?(t(), t()) :: boolean()
  def equal?(%__MODULE__{} = a, %__MODULE__{} = b) do
    a.char == b.char and
      a.fg == b.fg and
      a.bg == b.bg and
      a.bold == b.bold and
      a.italic == b.italic and
      a.underline == b.underline and
      a.strikethrough == b.strikethrough and
      a.dim == b.dim and
      a.inverse == b.inverse
  end

  @doc """
  Applies style overrides to a cell, returning a new cell with the updated values.

  Accepts the same keyword options as `new/1`. Only the specified fields are changed;
  all other fields retain their current values.

  ## Examples

      iex> cell = Tinct.Buffer.Cell.new(char: "A")
      iex> Tinct.Buffer.Cell.styled(cell, fg: :red, bold: true)
      %Tinct.Buffer.Cell{char: "A", fg: :red, bold: true}
  """
  @spec styled(t(), keyword()) :: t()
  def styled(%__MODULE__{} = cell, overrides) when is_list(overrides) do
    struct(cell, overrides)
  end
end
