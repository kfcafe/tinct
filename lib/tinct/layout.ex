defmodule Tinct.Layout do
  @moduledoc """
  Orchestrates element tree layout and rendering to a buffer.

  Takes an element tree built with `Tinct.Element` builders, runs the flex
  layout algorithm to position elements, then renders text content and borders
  into a `Tinct.Buffer`.

  ## Pipeline

  1. Pre-process the element tree (add padding for borders)
  2. Run `Tinct.Layout.Flex.resolve/2` to get positioned `{element, rect}` tuples
  3. Render each positioned element into the buffer:
     - Text elements: write content with word wrapping and style
     - Bordered containers: draw border characters
     - Plain containers: skip (children already positioned by flex)

  ## Examples

      iex> alias Tinct.{Element, Layout, Buffer}
      iex> el = Element.text("Hi")
      iex> buf = Layout.render(el, {10, 1})
      iex> Buffer.get(buf, 0, 0).char
      "H"
      iex> Buffer.get(buf, 1, 0).char
      "i"
  """

  alias Tinct.{Buffer, Element, Style, Theme}
  alias Tinct.Layout.{Border, Flex, Rect}

  @doc """
  Resolves an element tree into positioned rectangles.

  Useful for hit-testing and interaction mapping (for example, mouse click
  routing in composed dashboards) where you need to know where each element
  landed on screen.
  """
  @spec resolve(Element.t(), {non_neg_integer(), non_neg_integer()}) :: [{Element.t(), Rect.t()}]
  def resolve(%Element{} = element, {width, height}) do
    root_rect = Rect.new(0, 0, width, height)

    element
    |> prepare_for_layout()
    |> Flex.resolve(root_rect)
  end

  @doc """
  Renders an element tree into a buffer at the given dimensions.

  Accepts an optional theme for style resolution (defaults to `Theme.default/0`).

  ## Examples

      iex> alias Tinct.{Element, Layout, Buffer}
      iex> el = Element.column([], [Element.text("hello"), Element.text("world")])
      iex> buf = Layout.render(el, {20, 5})
      iex> Buffer.get(buf, 0, 0).char
      "h"
      iex> Buffer.get(buf, 0, 1).char
      "w"
  """
  @spec render(Element.t(), {non_neg_integer(), non_neg_integer()}, Theme.t()) :: Buffer.t()
  @spec render(Element.t(), {non_neg_integer(), non_neg_integer()}) :: Buffer.t()
  def render(element, dimensions, theme \\ Theme.default())

  def render(%Element{} = element, {width, height}, %Theme{} = theme) do
    buffer = Buffer.new(width, height)

    element
    |> resolve({width, height})
    |> Enum.reduce(buffer, fn {el, rect}, buf ->
      render_element(el, rect, buf, theme)
    end)
  end

  # --- Pre-processing ---

  # Adds padding for bordered elements so flex layout accounts for border space.
  # Text elements are leaves and never have borders.
  defp prepare_for_layout(%Element{type: :text} = element), do: element
  defp prepare_for_layout(%Element{type: :rich_text} = element), do: element

  defp prepare_for_layout(%Element{style: style, children: children} = element) do
    adjusted_children = Enum.map(children, &prepare_for_layout/1)
    adjusted_style = ensure_border_padding(style)
    %{element | style: adjusted_style, children: adjusted_children}
  end

  defp ensure_border_padding(%Style{border: border} = style)
       when border in [nil, :none] do
    style
  end

  defp ensure_border_padding(%Style{} = style) do
    %{
      style
      | padding_top: max(style.padding_top, 1),
        padding_right: max(style.padding_right, 1),
        padding_bottom: max(style.padding_bottom, 1),
        padding_left: max(style.padding_left, 1)
    }
  end

  # --- Element rendering ---

  defp render_element(%Element{type: :text} = element, rect, buffer, theme) do
    render_text(element, rect, buffer, theme)
  end

  defp render_element(%Element{type: :rich_text} = element, rect, buffer, _theme) do
    render_rich_text(element, rect, buffer)
  end

  defp render_element(%Element{style: %Style{border: border}, attrs: attrs}, rect, buffer, _theme)
       when border not in [nil, :none] do
    Border.render(rect, border, buffer, border_opts(attrs))
  end

  defp render_element(%Element{attrs: %{split_divider: char}}, rect, buffer, _theme) do
    render_split_divider(char, rect, buffer)
  end

  defp render_element(_element, _rect, buffer, _theme), do: buffer

  defp render_split_divider(_char, %Rect{width: 0}, buffer), do: buffer
  defp render_split_divider(_char, %Rect{height: 0}, buffer), do: buffer

  defp render_split_divider(char, %Rect{} = rect, buffer) when is_binary(char) do
    Enum.reduce(0..(rect.height - 1)//1, buffer, &render_split_divider_row(char, rect, &1, &2))
  end

  defp render_split_divider_row(char, %Rect{} = rect, row_offset, buffer)
       when is_binary(char) and is_integer(row_offset) do
    Enum.reduce(0..(rect.width - 1)//1, buffer, fn col_offset, buf ->
      Buffer.put_string(buf, rect.x + col_offset, rect.y + row_offset, char, [])
    end)
  end

  defp border_opts(attrs) do
    opts = []

    opts =
      case Map.get(attrs, :title) do
        nil -> opts
        title -> [{:title, title} | opts]
      end

    case Map.get(attrs, :border_color) do
      nil -> opts
      color -> [{:fg, color} | opts]
    end
  end

  # --- Text rendering ---

  defp render_text(%Element{attrs: attrs, style: style}, rect, buffer, _theme) do
    resolved_style = Style.resolve(style)
    cell_attrs = Style.to_cell_attrs(resolved_style)
    content = Map.get(attrs, :content, "")

    preserve_whitespace? = Map.get(attrs, :preserve_whitespace, false)
    pad_to_width? = Map.get(attrs, :pad_to_width, false)

    lines =
      if preserve_whitespace? do
        wrap_text_preserve_whitespace(content, rect.width)
      else
        wrap_text(content, rect.width)
      end

    lines
    |> Enum.take(rect.height)
    |> Enum.map(&maybe_pad_line(&1, rect.width, pad_to_width?))
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {line, row_offset}, buf ->
      Buffer.put_string(buf, rect.x, rect.y + row_offset, line, cell_attrs)
    end)
  end

  # --- Rich text rendering ---

  defp render_rich_text(_element, %Rect{width: 0}, buffer), do: buffer
  defp render_rich_text(_element, %Rect{height: 0}, buffer), do: buffer

  defp render_rich_text(%Element{attrs: %{spans: spans}}, %Rect{} = rect, buffer) do
    spans
    |> Enum.reduce({buffer, rect.x}, &render_rich_text_span(&1, rect, &2))
    |> elem(0)
  end

  defp render_rich_text_span({content, opts}, %Rect{} = rect, {buffer, col})
       when is_binary(content) and is_list(opts) do
    span_style = opts |> Style.new() |> Style.resolve()
    cell_attrs = Style.to_cell_attrs(span_style)
    max_col = rect.x + rect.width - 1

    content
    |> String.graphemes()
    |> Enum.reduce_while({buffer, col}, fn
      _grapheme, {buf, c} when c > max_col ->
        {:halt, {buf, c}}

      grapheme, {buf, c} ->
        {:cont, {Buffer.put_string(buf, c, rect.y, grapheme, cell_attrs), c + 1}}
    end)
  end

  defp maybe_pad_line(line, _width, false), do: line

  defp maybe_pad_line(line, width, true) when is_binary(line) and is_integer(width) do
    cond do
      width <= 0 ->
        ""

      String.length(line) < width ->
        line <> String.duplicate(" ", width - String.length(line))

      String.length(line) > width ->
        String.slice(line, 0, width)

      true ->
        line
    end
  end

  # --- Text wrapping ---

  @doc false
  @spec wrap_text(String.t(), non_neg_integer()) :: [String.t()]
  def wrap_text(_text, 0), do: []

  def wrap_text(text, width) when is_binary(text) and width > 0 do
    text
    |> String.split()
    |> wrap_words(width, [], "")
  end

  defp wrap_text_preserve_whitespace(_text, 0), do: []

  defp wrap_text_preserve_whitespace(text, width) when is_binary(text) and width > 0 do
    text
    |> String.split("\n", trim: false)
    |> Enum.flat_map(&chunk_preserved_line(&1, width))
  end

  defp chunk_preserved_line(line, width)
       when is_binary(line) and is_integer(width) and width > 0 do
    line
    |> String.graphemes()
    |> Enum.chunk_every(width)
    |> case do
      [] -> [""]
      chunks -> Enum.map(chunks, &Enum.join/1)
    end
  end

  defp wrap_words([], _width, lines, current) do
    Enum.reverse([current | lines])
  end

  defp wrap_words([word | rest], width, lines, "") do
    if String.length(word) > width do
      {first, remaining} = String.split_at(word, width)
      wrap_words([remaining | rest], width, [first | lines], "")
    else
      wrap_words(rest, width, lines, word)
    end
  end

  defp wrap_words([word | rest], width, lines, current) do
    candidate = current <> " " <> word

    if String.length(candidate) <= width do
      wrap_words(rest, width, lines, candidate)
    else
      wrap_words([word | rest], width, [current | lines], "")
    end
  end
end
