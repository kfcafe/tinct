defmodule Tinct.ANSI do
  @moduledoc """
  Encodes terminal operations as ANSI escape sequences.

  All functions return iodata (binaries or iolists) for efficient concatenation.
  Nothing is written to stdout — that's the Writer's job.

  ## Cursor Movement

      iex> Tinct.ANSI.move_to(0, 0) |> IO.iodata_to_binary()
      "\\e[1;1H"

      iex> Tinct.ANSI.hide_cursor()
      "\\e[?25l"

  ## Styles (SGR)

      iex> Tinct.ANSI.sgr(bold: true, fg: :red) |> IO.iodata_to_binary()
      "\\e[1;31m"

      iex> Tinct.ANSI.reset()
      "\\e[0m"
  """

  @csi "\e["

  @named_colors %{
    black: 0,
    red: 1,
    green: 2,
    yellow: 3,
    blue: 4,
    magenta: 5,
    cyan: 6,
    white: 7
  }

  @bright_colors %{
    bright_black: 8,
    bright_red: 9,
    bright_green: 10,
    bright_yellow: 11,
    bright_blue: 12,
    bright_magenta: 13,
    bright_cyan: 14,
    bright_white: 15
  }

  @type color ::
          :default
          | :black
          | :red
          | :green
          | :yellow
          | :blue
          | :magenta
          | :cyan
          | :white
          | :bright_black
          | :bright_red
          | :bright_green
          | :bright_yellow
          | :bright_blue
          | :bright_magenta
          | :bright_cyan
          | :bright_white
          | {:indexed, 0..255}
          | {:rgb, 0..255, 0..255, 0..255}

  @type cursor_shape :: :block | :underline | :bar

  # --- Cursor Movement ---

  @doc """
  Move cursor to absolute position (col, row), zero-indexed.

  Uses CSI `{row+1};{col+1}H`.

  ## Examples

      iex> Tinct.ANSI.move_to(9, 4) |> IO.iodata_to_binary()
      "\\e[5;10H"
  """
  @spec move_to(non_neg_integer(), non_neg_integer()) :: iodata()
  def move_to(col, row) do
    [@csi, Integer.to_string(row + 1), ";", Integer.to_string(col + 1), "H"]
  end

  @doc "Move cursor up by `n` rows."
  @spec move_up(pos_integer()) :: iodata()
  def move_up(n), do: [@csi, Integer.to_string(n), "A"]

  @doc "Move cursor down by `n` rows."
  @spec move_down(pos_integer()) :: iodata()
  def move_down(n), do: [@csi, Integer.to_string(n), "B"]

  @doc "Move cursor right by `n` columns."
  @spec move_right(pos_integer()) :: iodata()
  def move_right(n), do: [@csi, Integer.to_string(n), "C"]

  @doc "Move cursor left by `n` columns."
  @spec move_left(pos_integer()) :: iodata()
  def move_left(n), do: [@csi, Integer.to_string(n), "D"]

  @doc "Hide the cursor."
  @spec hide_cursor() :: iodata()
  def hide_cursor, do: "\e[?25l"

  @doc "Show the cursor."
  @spec show_cursor() :: iodata()
  def show_cursor, do: "\e[?25h"

  @doc """
  Set the cursor shape using DECSCUSR.

  - `:block` — steady block cursor (`\\e[2 q`)
  - `:underline` — steady underline cursor (`\\e[4 q`)
  - `:bar` — steady bar (vertical line) cursor (`\\e[6 q`)
  """
  @spec cursor_shape(cursor_shape()) :: iodata()
  def cursor_shape(:block), do: "\e[2 q"
  def cursor_shape(:underline), do: "\e[4 q"
  def cursor_shape(:bar), do: "\e[6 q"

  @doc "Save cursor position (DECSC)."
  @spec save_cursor() :: iodata()
  def save_cursor, do: "\e7"

  @doc "Restore cursor position (DECRC)."
  @spec restore_cursor() :: iodata()
  def restore_cursor, do: "\e8"

  # --- Screen Control ---

  @doc "Clear the entire screen."
  @spec clear_screen() :: iodata()
  def clear_screen, do: "\e[2J"

  @doc "Clear the entire current line."
  @spec clear_line() :: iodata()
  def clear_line, do: "\e[2K"

  @doc "Clear from cursor to end of current line."
  @spec clear_to_end_of_line() :: iodata()
  def clear_to_end_of_line, do: "\e[K"

  @doc "Enter alternate screen buffer."
  @spec enter_alt_screen() :: iodata()
  def enter_alt_screen, do: "\e[?1049h"

  @doc "Exit alternate screen buffer."
  @spec exit_alt_screen() :: iodata()
  def exit_alt_screen, do: "\e[?1049l"

  @doc "Scroll the screen up by `n` lines."
  @spec scroll_up(pos_integer()) :: iodata()
  def scroll_up(n), do: [@csi, Integer.to_string(n), "S"]

  @doc "Scroll the screen down by `n` lines."
  @spec scroll_down(pos_integer()) :: iodata()
  def scroll_down(n), do: [@csi, Integer.to_string(n), "T"]

  # --- Style (SGR — Select Graphic Rendition) ---

  @doc """
  Build an SGR sequence from a keyword list of style attributes.

  Returns an empty iolist when no attributes produce codes.

  ## Attributes

  - `bold: true` — bold text (SGR 1)
  - `dim: true` — dim/faint text (SGR 2)
  - `italic: true` — italic text (SGR 3)
  - `underline: true` — underlined text (SGR 4)
  - `blink: true` — blinking text (SGR 5)
  - `inverse: true` — inverse/reverse video (SGR 7)
  - `strikethrough: true` — strikethrough text (SGR 9)
  - `fg: color` — foreground color
  - `bg: color` — background color

  ## Examples

      iex> Tinct.ANSI.sgr(bold: true) |> IO.iodata_to_binary()
      "\\e[1m"

      iex> Tinct.ANSI.sgr(bold: true, fg: :red) |> IO.iodata_to_binary()
      "\\e[1;31m"

      iex> Tinct.ANSI.sgr(fg: :red, bg: :blue) |> IO.iodata_to_binary()
      "\\e[31;44m"

      iex> Tinct.ANSI.sgr(bold: false)
      []
  """
  @spec sgr(keyword()) :: iodata()
  def sgr(attrs) when is_list(attrs) do
    codes = Enum.flat_map(attrs, &sgr_codes/1)

    case codes do
      [] -> []
      _ -> [@csi, Enum.intersperse(Enum.map(codes, &Integer.to_string/1), ";"), "m"]
    end
  end

  @doc "Reset all text attributes (SGR 0)."
  @spec reset() :: iodata()
  def reset, do: "\e[0m"

  @doc """
  Generate foreground color escape sequence.

  Accepts named colors (`:red`), bright colors (`:bright_red`),
  indexed colors (`{:indexed, 196}`), RGB (`{:rgb, 255, 128, 0}`),
  or `:default`.

  ## Examples

      iex> Tinct.ANSI.fg_color(:red) |> IO.iodata_to_binary()
      "\\e[31m"

      iex> Tinct.ANSI.fg_color({:rgb, 255, 128, 0}) |> IO.iodata_to_binary()
      "\\e[38;2;255;128;0m"
  """
  @spec fg_color(color()) :: iodata()
  def fg_color(color) do
    codes = color_codes(color, :fg)
    [@csi, Enum.intersperse(Enum.map(codes, &Integer.to_string/1), ";"), "m"]
  end

  @doc """
  Generate background color escape sequence.

  Accepts the same color formats as `fg_color/1`.

  ## Examples

      iex> Tinct.ANSI.bg_color(:blue) |> IO.iodata_to_binary()
      "\\e[44m"

      iex> Tinct.ANSI.bg_color({:indexed, 42}) |> IO.iodata_to_binary()
      "\\e[48;5;42m"
  """
  @spec bg_color(color()) :: iodata()
  def bg_color(color) do
    codes = color_codes(color, :bg)
    [@csi, Enum.intersperse(Enum.map(codes, &Integer.to_string/1), ";"), "m"]
  end

  # --- Synchronized Rendering (Mode 2026) ---

  @doc "Begin synchronized output (Mode 2026)."
  @spec begin_sync() :: iodata()
  def begin_sync, do: "\e[?2026h"

  @doc "End synchronized output (Mode 2026)."
  @spec end_sync() :: iodata()
  def end_sync, do: "\e[?2026l"

  # --- Mouse ---

  @doc "Enable cell motion mouse tracking with SGR encoding."
  @spec enable_mouse_cell() :: iodata()
  def enable_mouse_cell, do: "\e[?1002h\e[?1006h"

  @doc "Disable mouse tracking."
  @spec disable_mouse() :: iodata()
  def disable_mouse, do: "\e[?1002l\e[?1006l"

  @doc "Enable all motion mouse tracking with SGR encoding."
  @spec enable_mouse_all() :: iodata()
  def enable_mouse_all, do: "\e[?1003h\e[?1006h"

  # --- Bracketed Paste ---

  @doc "Enable bracketed paste mode."
  @spec enable_bracketed_paste() :: iodata()
  def enable_bracketed_paste, do: "\e[?2004h"

  @doc "Disable bracketed paste mode."
  @spec disable_bracketed_paste() :: iodata()
  def disable_bracketed_paste, do: "\e[?2004l"

  # --- Unicode Width (Mode 2027) ---

  @doc "Enable unicode width mode (Mode 2027)."
  @spec enable_unicode_width() :: iodata()
  def enable_unicode_width, do: "\e[?2027h"

  @doc "Disable unicode width mode (Mode 2027)."
  @spec disable_unicode_width() :: iodata()
  def disable_unicode_width, do: "\e[?2027l"

  # --- Private Helpers ---

  defp sgr_codes({:bold, true}), do: [1]
  defp sgr_codes({:dim, true}), do: [2]
  defp sgr_codes({:italic, true}), do: [3]
  defp sgr_codes({:underline, true}), do: [4]
  defp sgr_codes({:blink, true}), do: [5]
  defp sgr_codes({:inverse, true}), do: [7]
  defp sgr_codes({:strikethrough, true}), do: [9]
  defp sgr_codes({:fg, color}), do: color_codes(color, :fg)
  defp sgr_codes({:bg, color}), do: color_codes(color, :bg)
  defp sgr_codes({_attr, false}), do: []

  defp color_codes(:default, :fg), do: [39]
  defp color_codes(:default, :bg), do: [49]

  defp color_codes({:rgb, r, g, b}, :fg), do: [38, 2, r, g, b]
  defp color_codes({:rgb, r, g, b}, :bg), do: [48, 2, r, g, b]

  defp color_codes({:indexed, n}, :fg) when n in 0..255, do: [38, 5, n]
  defp color_codes({:indexed, n}, :bg) when n in 0..255, do: [48, 5, n]

  defp color_codes(name, :fg) when is_map_key(@named_colors, name) do
    [30 + Map.fetch!(@named_colors, name)]
  end

  defp color_codes(name, :bg) when is_map_key(@named_colors, name) do
    [40 + Map.fetch!(@named_colors, name)]
  end

  defp color_codes(name, :fg) when is_map_key(@bright_colors, name) do
    [90 + Map.fetch!(@bright_colors, name) - 8]
  end

  defp color_codes(name, :bg) when is_map_key(@bright_colors, name) do
    [100 + Map.fetch!(@bright_colors, name) - 8]
  end
end
