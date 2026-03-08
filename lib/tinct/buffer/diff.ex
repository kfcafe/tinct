defmodule Tinct.Buffer.Diff do
  @moduledoc """
  Compares two buffers and produces minimal ANSI output for efficient rendering.

  Instead of redrawing the entire screen each frame, `diff/2` compares the new
  buffer against the previous one and emits escape sequences only for cells that
  changed. Adjacent changed cells on the same row are coalesced into single
  writes, and style changes are tracked to avoid redundant SGR sequences.

  All output is iodata — no string concatenation.
  """

  alias Tinct.ANSI
  alias Tinct.Buffer
  alias Tinct.Buffer.Cell

  @default_style {:default, :default, false, false, false, false, false, false}

  @doc """
  Compares two buffers and returns iodata that transforms the terminal from
  the previous state to the new state.

  If the buffers differ in size, falls back to `full_render/1` of the new buffer.
  If the buffers are identical, returns empty iodata.

  ## Examples

      iex> prev = Tinct.Buffer.new(10, 5)
      iex> new = Tinct.Buffer.put_string(prev, 0, 0, "Hi")
      iex> iodata = Tinct.Buffer.Diff.diff(prev, new)
      iex> is_list(iodata) or is_binary(iodata)
      true
  """
  @spec diff(Buffer.t(), Buffer.t()) :: iodata()
  def diff(%Buffer{} = prev, %Buffer{} = new) do
    if prev.width != new.width or prev.height != new.height do
      full_render(new)
    else
      do_diff(prev, new)
    end
  end

  @doc """
  Renders the entire buffer as iodata, suitable for the first frame or full redraw.

  Emits `move_to` at the start of each row, coalesces styles across consecutive
  cells, and appends a reset at the end if any styled content was emitted.

  ## Examples

      iex> buf = Tinct.Buffer.new(5, 2)
      iex> buf = Tinct.Buffer.put_string(buf, 0, 0, "Hello")
      iex> iodata = Tinct.Buffer.Diff.full_render(buf)
      iex> is_list(iodata) or is_binary(iodata)
      true
  """
  @spec full_render(Buffer.t()) :: iodata()
  def full_render(%Buffer{} = buffer) do
    if buffer.width == 0 or buffer.height == 0 do
      []
    else
      initial_state = %{output: [], cursor_col: nil, cursor_row: nil, style: nil}

      initial_state
      |> scan_all_cells(buffer)
      |> finalize()
    end
  end

  # --- Private Implementation ---

  defp do_diff(prev, new) do
    if new.width == 0 or new.height == 0 do
      []
    else
      initial_state = %{output: [], cursor_col: nil, cursor_row: nil, style: nil}

      initial_state
      |> scan_changed_cells(prev, new)
      |> finalize()
    end
  end

  defp scan_all_cells(state, buffer) do
    Enum.reduce(0..(buffer.height - 1)//1, state, fn row, row_acc ->
      Enum.reduce(0..(buffer.width - 1)//1, row_acc, fn col, col_acc ->
        cell = Buffer.get(buffer, col, row)

        col_acc
        |> maybe_move(col, row)
        |> maybe_change_style(cell)
        |> emit_char(cell.char, col)
      end)
    end)
  end

  defp scan_changed_cells(state, prev, new) do
    Enum.reduce(0..(new.height - 1)//1, state, fn row, row_acc ->
      scan_changed_cells_row(row_acc, prev, new, row)
    end)
  end

  defp scan_changed_cells_row(state, prev, new, row) do
    Enum.reduce(0..(new.width - 1)//1, state, fn col, col_acc ->
      scan_changed_cell(col_acc, prev, new, col, row)
    end)
  end

  defp scan_changed_cell(state, prev, new, col, row) do
    old_cell = Buffer.get(prev, col, row)
    new_cell = Buffer.get(new, col, row)

    if Cell.equal?(old_cell, new_cell) do
      state
    else
      state
      |> maybe_move(col, row)
      |> maybe_change_style(new_cell)
      |> emit_char(new_cell.char, col)
    end
  end

  defp maybe_move(state, col, row) do
    if state.cursor_col == col and state.cursor_row == row do
      state
    else
      %{state | output: [state.output, ANSI.move_to(col, row)], cursor_col: col, cursor_row: row}
    end
  end

  defp maybe_change_style(state, cell) do
    new_style = cell_style(cell)

    if state.style == new_style do
      state
    else
      output = emit_sgr(state.output, cell, new_style)
      %{state | output: output, style: new_style}
    end
  end

  defp emit_sgr(output, _cell, @default_style) do
    [output, ANSI.reset()]
  end

  defp emit_sgr(output, cell, _new_style) do
    [output, ANSI.reset(), ANSI.sgr(cell_sgr_attrs(cell))]
  end

  defp emit_char(state, char, col) do
    next_col = if single_column_ascii?(char), do: col + 1, else: nil
    %{state | output: [state.output, char], cursor_col: next_col}
  end

  defp single_column_ascii?(<<byte>>) when byte in 0..127, do: true
  defp single_column_ascii?(_), do: false

  defp finalize(%{style: nil}), do: []
  defp finalize(%{output: output, style: @default_style}), do: output
  defp finalize(%{output: output}), do: [output, ANSI.reset()]

  defp cell_style(cell) do
    {cell.fg, cell.bg, cell.bold, cell.italic, cell.underline, cell.strikethrough, cell.dim,
     cell.inverse}
  end

  defp cell_sgr_attrs(cell) do
    []
    |> maybe_attr(:inverse, cell.inverse)
    |> maybe_attr(:dim, cell.dim)
    |> maybe_attr(:strikethrough, cell.strikethrough)
    |> maybe_attr(:underline, cell.underline)
    |> maybe_attr(:italic, cell.italic)
    |> maybe_attr(:bold, cell.bold)
    |> maybe_color(:bg, cell.bg)
    |> maybe_color(:fg, cell.fg)
  end

  defp maybe_attr(attrs, _key, false), do: attrs
  defp maybe_attr(attrs, key, true), do: [{key, true} | attrs]

  defp maybe_color(attrs, _key, :default), do: attrs
  defp maybe_color(attrs, key, color), do: [{key, color} | attrs]
end
