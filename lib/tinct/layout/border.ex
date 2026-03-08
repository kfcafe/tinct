defmodule Tinct.Layout.Border do
  @moduledoc """
  Border rendering for terminal UI elements.

  Provides character sets for different border styles and functions to render
  borders onto a `Tinct.Buffer`.

  Borders are *auto-connecting*: when a border is rendered onto a buffer cell
  that already contains a box-drawing border character, the characters are
  merged into the appropriate intersection (for example `"─"` + `"│"` becomes
  `"┼"`).

  ## Border styles

    * `:single` — light box drawing: `┌ ─ ┐ │ └ ┘`
    * `:double` — double lines: `╔ ═ ╗ ║ ╚ ╝`
    * `:round` — rounded corners: `╭ ─ ╮ │ ╰ ╯`
    * `:bold` — heavy box drawing: `┏ ━ ┓ ┃ ┗ ┛`
    * `:none` — invisible (no border is rendered)
  """

  import Bitwise, only: [bor: 2]

  alias Tinct.Buffer
  alias Tinct.Buffer.Cell
  alias Tinct.Layout.Rect

  @typedoc "A set of eight border characters."
  @type t :: %__MODULE__{
          top_left: String.t(),
          top: String.t(),
          top_right: String.t(),
          left: String.t(),
          right: String.t(),
          bottom_left: String.t(),
          bottom: String.t(),
          bottom_right: String.t()
        }

  @typedoc "A border style identifier."
  @type border_style :: :single | :double | :round | :bold | :none

  defstruct [:top_left, :top, :top_right, :left, :right, :bottom_left, :bottom, :bottom_right]

  # Direction bitmask: up=1, right=2, down=4, left=8
  @char_masks %{
    # light
    "─" => 10,
    "│" => 5,
    "┌" => 6,
    "┐" => 12,
    "└" => 3,
    "┘" => 9,
    "┼" => 15,
    "┬" => 14,
    "┴" => 11,
    "├" => 7,
    "┤" => 13,

    # rounded corners (light edges)
    "╭" => 6,
    "╮" => 12,
    "╰" => 3,
    "╯" => 9,

    # double
    "═" => 10,
    "║" => 5,
    "╔" => 6,
    "╗" => 12,
    "╚" => 3,
    "╝" => 9,
    "╬" => 15,
    "╦" => 14,
    "╩" => 11,
    "╠" => 7,
    "╣" => 13,

    # heavy
    "━" => 10,
    "┃" => 5,
    "┏" => 6,
    "┓" => 12,
    "┗" => 3,
    "┛" => 9,
    "╋" => 15,
    "┳" => 14,
    "┻" => 11,
    "┣" => 7,
    "┫" => 13
  }

  @doc """
  Returns the border character set for a given style.

  ## Examples

      iex> chars = Tinct.Layout.Border.chars(:single)
      iex> chars.top_left
      "┌"
  """
  @spec chars(border_style()) :: t()
  def chars(:single) do
    %__MODULE__{
      top_left: "┌",
      top: "─",
      top_right: "┐",
      left: "│",
      right: "│",
      bottom_left: "└",
      bottom: "─",
      bottom_right: "┘"
    }
  end

  def chars(:double) do
    %__MODULE__{
      top_left: "╔",
      top: "═",
      top_right: "╗",
      left: "║",
      right: "║",
      bottom_left: "╚",
      bottom: "═",
      bottom_right: "╝"
    }
  end

  def chars(:round) do
    %__MODULE__{
      top_left: "╭",
      top: "─",
      top_right: "╮",
      left: "│",
      right: "│",
      bottom_left: "╰",
      bottom: "─",
      bottom_right: "╯"
    }
  end

  def chars(:bold) do
    %__MODULE__{
      top_left: "┏",
      top: "━",
      top_right: "┓",
      left: "┃",
      right: "┃",
      bottom_left: "┗",
      bottom: "━",
      bottom_right: "┛"
    }
  end

  def chars(:none) do
    %__MODULE__{
      top_left: " ",
      top: " ",
      top_right: " ",
      left: " ",
      right: " ",
      bottom_left: " ",
      bottom: " ",
      bottom_right: " "
    }
  end

  @doc """
  Renders a border onto a buffer at the given rect.

  Draws corners and edges using the character set for the given border style.
  Returns the buffer unchanged if the rect is too small (width or height < 2)
  or the style is `:none`.
  """
  @spec render(Rect.t(), border_style(), Buffer.t()) :: Buffer.t()
  def render(%Rect{width: w, height: h}, _style, buffer) when w < 2 or h < 2, do: buffer
  def render(%Rect{}, :none, buffer), do: buffer

  def render(%Rect{} = rect, style, %Buffer{} = buffer) do
    render(rect, style, buffer, [])
  end

  @doc """
  Renders a border onto a buffer at the given rect with options.

  Supports the same border styles as `render/3`, plus:

    * `:title` — text to display in the top border edge
    * `:fg` — foreground color for border characters

  ## Title rendering

  Titles are rendered starting near the top-left corner, like:

      ┌─ Title ──────────┐

  The title is truncated to `rect.width - 4` characters.
  """
  @spec render(Rect.t(), border_style(), Buffer.t(), keyword()) :: Buffer.t()
  def render(%Rect{width: w, height: h}, _style, buffer, _opts) when w < 2 or h < 2, do: buffer
  def render(%Rect{}, :none, buffer, _opts), do: buffer

  def render(%Rect{} = rect, style, %Buffer{} = buffer, opts) when is_list(opts) do
    c = chars(style)
    fg = Keyword.get(opts, :fg)
    title = Keyword.get(opts, :title)
    %{x: x, y: y, width: w, height: h} = rect

    buffer
    |> put_border_char(x, y, c.top_left, fg)
    |> put_border_char(x + w - 1, y, c.top_right, fg)
    |> put_border_char(x, y + h - 1, c.bottom_left, fg)
    |> put_border_char(x + w - 1, y + h - 1, c.bottom_right, fg)
    |> draw_horizontal_edges(x, y, w, h, c, fg)
    |> draw_vertical_edges(x, y, w, h, c, fg)
    |> render_title(x, y, w, title, fg)
  end

  @doc """
  Returns the inner content rect after accounting for the border.

  For all visible border styles, shrinks by 1 cell on each side.
  For `:none` or `nil`, returns the rect unchanged.

  ## Examples

      iex> alias Tinct.Layout.{Rect, Border}
      iex> Border.inner_rect(Rect.new(0, 0, 10, 5), :single)
      %Rect{x: 1, y: 1, width: 8, height: 3}

      iex> alias Tinct.Layout.{Rect, Border}
      iex> Border.inner_rect(Rect.new(0, 0, 10, 5), :none)
      %Rect{x: 0, y: 0, width: 10, height: 5}
  """
  @spec inner_rect(Rect.t(), border_style() | nil) :: Rect.t()
  def inner_rect(%Rect{} = rect, nil), do: rect
  def inner_rect(%Rect{} = rect, :none), do: rect

  def inner_rect(%Rect{} = rect, _style) do
    Rect.new(
      rect.x + 1,
      rect.y + 1,
      max(rect.width - 2, 0),
      max(rect.height - 2, 0)
    )
  end

  @doc """
  Merges two characters, producing the appropriate box-drawing intersection.

  This is used by `render/3` and `render/4` to auto-connect borders when two
  bordered elements share edges.

  Unknown (non box-drawing) characters are treated as overwrites: if either
  side isn't recognized as a border character, the `new_char` is returned.
  """
  @spec merge_border_chars(String.t(), String.t()) :: String.t()
  def merge_border_chars(existing_char, new_char)
      when is_binary(existing_char) and is_binary(new_char) do
    cond do
      existing_char == new_char ->
        existing_char

      new_char == " " ->
        " "

      existing_char == " " ->
        new_char

      true ->
        merge_non_space_border_chars(existing_char, new_char)
    end
  end

  defp merge_non_space_border_chars(existing_char, new_char) do
    existing_mask = char_mask(existing_char)
    new_mask = char_mask(new_char)

    if existing_mask == 0 or new_mask == 0 do
      new_char
    else
      merged_mask = bor(existing_mask, new_mask)
      existing_weight = weight_for_char(existing_char)
      new_weight = weight_for_char(new_char)
      merged_weight = merge_weight(existing_weight, new_weight)

      choose_merged_char(
        existing_char,
        new_char,
        existing_mask,
        new_mask,
        merged_mask,
        existing_weight,
        new_weight,
        merged_weight
      )
    end
  end

  defp choose_merged_char(
         existing_char,
         new_char,
         existing_mask,
         new_mask,
         merged_mask,
         existing_weight,
         new_weight,
         merged_weight
       )
       when is_integer(existing_mask) and is_integer(new_mask) and is_integer(merged_mask) do
    cond do
      merged_mask == existing_mask and merged_weight == existing_weight ->
        existing_char

      merged_mask == new_mask and merged_weight == new_weight ->
        new_char

      true ->
        char_for_mask(merged_mask, merged_weight) || new_char
    end
  end

  # --- Private helpers ---

  defp put_border_char(%Buffer{} = buffer, col, row, new_char, fg) do
    existing_cell = Buffer.get(buffer, col, row)
    merged_char = merge_border_chars(existing_cell.char, new_char)

    overrides = [char: merged_char]
    overrides = if is_nil(fg), do: overrides, else: Keyword.put(overrides, :fg, fg)

    Buffer.put(buffer, col, row, Cell.styled(existing_cell, overrides))
  end

  defp draw_horizontal_edges(buffer, _x, _y, w, h, _c, _fg) when w <= 2 or h <= 0 do
    buffer
  end

  defp draw_horizontal_edges(buffer, x, y, w, h, c, fg) do
    Enum.reduce((x + 1)..(x + w - 2)//1, buffer, fn col, buf ->
      buf
      |> put_border_char(col, y, c.top, fg)
      |> put_border_char(col, y + h - 1, c.bottom, fg)
    end)
  end

  defp draw_vertical_edges(buffer, _x, _y, w, h, _c, _fg) when h <= 2 or w <= 0 do
    buffer
  end

  defp draw_vertical_edges(buffer, x, y, w, h, c, fg) do
    Enum.reduce((y + 1)..(y + h - 2)//1, buffer, fn row, buf ->
      buf
      |> put_border_char(x, row, c.left, fg)
      |> put_border_char(x + w - 1, row, c.right, fg)
    end)
  end

  defp render_title(buffer, _x, _y, _w, nil, _fg), do: buffer

  defp render_title(buffer, x, y, w, title, fg) when is_binary(title) do
    max_len = w - 4

    if max_len <= 0 do
      buffer
    else
      truncated = String.slice(title, 0, max_len)

      # Format: ┌ Title ───...─┐
      #
      # Layout:
      #   x+0: corner
      #   x+1: space
      #   x+2..: title
      leading_space_col = x + 1
      title_start_col = x + 2
      after_title_col = title_start_col + String.length(truncated)
      last_inner_col = x + w - 2

      buffer
      |> put_border_char(leading_space_col, y, " ", fg)
      |> write_title_chars(title_start_col, y, truncated, fg)
      |> maybe_put_trailing_space(after_title_col, y, last_inner_col, fg)
    end
  end

  defp maybe_put_trailing_space(buffer, col, row, last_inner_col, fg)
       when col <= last_inner_col do
    put_border_char(buffer, col, row, " ", fg)
  end

  defp maybe_put_trailing_space(buffer, _col, _row, _last_inner_col, _fg), do: buffer

  defp write_title_chars(buffer, start_col, y, title, fg) do
    title
    |> String.graphemes()
    |> Enum.with_index(start_col)
    |> Enum.reduce(buffer, fn {grapheme, col}, buf ->
      put_border_char(buf, col, y, grapheme, fg)
    end)
  end

  defp char_mask(char) do
    Map.get(@char_masks, char, 0)
  end

  defp weight_for_char(char)
       when char in [
              "═",
              "║",
              "╔",
              "╗",
              "╚",
              "╝",
              "╬",
              "╦",
              "╩",
              "╠",
              "╣"
            ],
       do: :double

  defp weight_for_char(char)
       when char in ["━", "┃", "┏", "┓", "┗", "┛", "╋", "┳", "┻", "┣", "┫"],
       do: :bold

  defp weight_for_char(_char), do: :single

  defp merge_weight(:double, _), do: :double
  defp merge_weight(_, :double), do: :double
  defp merge_weight(:bold, _), do: :bold
  defp merge_weight(_, :bold), do: :bold
  defp merge_weight(:single, :single), do: :single

  @single_mask_to_char %{
    10 => "─",
    5 => "│",
    6 => "┌",
    12 => "┐",
    3 => "└",
    9 => "┘",
    15 => "┼",
    14 => "┬",
    11 => "┴",
    7 => "├",
    13 => "┤"
  }

  @double_mask_to_char %{
    10 => "═",
    5 => "║",
    6 => "╔",
    12 => "╗",
    3 => "╚",
    9 => "╝",
    15 => "╬",
    14 => "╦",
    11 => "╩",
    7 => "╠",
    13 => "╣"
  }

  @bold_mask_to_char %{
    10 => "━",
    5 => "┃",
    6 => "┏",
    12 => "┓",
    3 => "┗",
    9 => "┛",
    15 => "╋",
    14 => "┳",
    11 => "┻",
    7 => "┣",
    13 => "┫"
  }

  defp char_for_mask(mask, :single), do: Map.get(@single_mask_to_char, mask)
  defp char_for_mask(mask, :double), do: Map.get(@double_mask_to_char, mask)
  defp char_for_mask(mask, :bold), do: Map.get(@bold_mask_to_char, mask)
end
