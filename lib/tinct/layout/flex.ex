defmodule Tinct.Layout.Flex do
  @moduledoc """
  Flexbox layout algorithm for terminal character grids.

  Resolves an element tree into positioned rectangles using a simplified
  flexbox model optimized for integer character-cell coordinates. All
  arithmetic uses integers with `div/2` and `rem/2` — no fractional values,
  no subpixel rendering.

  ## Algorithm

  1. Determine main axis from container type (`:row`/`:box` → horizontal, `:column` → vertical)
  2. Subtract padding to find the content area
  3. Compute base sizes for each child (explicit dimension, text length, or 0)
  4. Distribute remaining space via `flex_grow` / `flex_shrink`
  5. Size children on the cross axis (stretch by default)
  6. Position children using `justify_content` and `align_items`
  7. Recurse into container children
  """

  alias Tinct.Element
  alias Tinct.Layout.Rect
  alias Tinct.Style

  @doc """
  Resolves an element tree into a flat list of `{element, rect}` tuples.

  Each element in the tree receives a `Rect` describing its position and size.
  Text elements are leaf nodes; containers recurse into their children.

  ## Examples

      iex> alias Tinct.{Element, Layout.Rect, Layout.Flex}
      iex> el = Element.text("hi")
      iex> rect = Rect.new(0, 0, 10, 5)
      iex> [{^el, result}] = Flex.resolve(el, rect)
      iex> result
      %Rect{x: 0, y: 0, width: 10, height: 5}
  """
  @spec resolve(Element.t(), Rect.t()) :: [{Element.t(), Rect.t()}]
  def resolve(%Element{type: :text} = element, %Rect{} = rect) do
    [{element, rect}]
  end

  def resolve(%Element{type: :rich_text} = element, %Rect{} = rect) do
    [{element, rect}]
  end

  def resolve(%Element{} = element, %Rect{} = rect) do
    content = content_area(rect, element.style)

    case element.children do
      [] ->
        [{element, rect}]

      children ->
        child_rects = layout_children(children, content, element)

        child_results =
          children
          |> Enum.zip(child_rects)
          |> Enum.flat_map(fn {child, child_rect} -> resolve(child, child_rect) end)

        [{element, rect} | child_results]
    end
  end

  # --- Content area ---

  @spec content_area(Rect.t(), Style.t()) :: Rect.t()
  defp content_area(%Rect{} = rect, %Style{} = style) do
    Rect.new(
      rect.x + style.padding_left,
      rect.y + style.padding_top,
      max(rect.width - style.padding_left - style.padding_right, 0),
      max(rect.height - style.padding_top - style.padding_bottom, 0)
    )
  end

  # --- Main layout pipeline ---

  @spec layout_children([Element.t()], Rect.t(), Element.t()) :: [Rect.t()]
  defp layout_children(children, content_rect, container) do
    direction = flex_direction(container.type)
    style = container.style
    n = length(children)
    total_gap = if n > 1, do: style.gap * (n - 1), else: 0

    {main_available, cross_available} = axis_sizes(content_rect, direction)
    main_for_children = max(main_available - total_gap, 0)

    base_sizes = Enum.map(children, &base_size(&1, direction, cross_available))
    flexed = flex_distribute(children, base_sizes, main_for_children)

    main_sizes =
      children
      |> Enum.zip(flexed)
      |> Enum.map(fn {child, size} -> clamp_main(size, child.style, direction) end)

    cross_sizes =
      Enum.map(children, fn child ->
        compute_cross_size(child, cross_available, direction, style.align_items)
      end)

    position_children(
      main_sizes,
      cross_sizes,
      content_rect,
      direction,
      style.gap,
      style.justify_content,
      style.align_items
    )
  end

  # --- Axis helpers ---

  defp flex_direction(:row), do: :row
  defp flex_direction(:box), do: :row
  defp flex_direction(:column), do: :column

  defp axis_sizes(%Rect{width: w, height: h}, :row), do: {w, h}
  defp axis_sizes(%Rect{width: w, height: h}, :column), do: {h, w}

  defp axis_origin(%Rect{x: x, y: y}, :row), do: {x, y}
  defp axis_origin(%Rect{x: x, y: y}, :column), do: {y, x}

  # --- Base sizes ---

  defp base_size(%Element{type: :rich_text, attrs: %{spans: spans}}, :row, _cross) do
    Enum.reduce(spans, 0, fn {content, _opts}, acc -> acc + String.length(content) end)
  end

  defp base_size(%Element{type: :rich_text}, :column, _cross), do: 1

  defp base_size(%Element{type: :text, attrs: %{content: content}}, :row, _cross) do
    String.length(content)
  end

  defp base_size(%Element{type: :text, attrs: %{content: content}}, :column, cross) do
    # Wrap text to the available width and count lines, so the flex
    # algorithm allocates enough vertical space for wrapped text.
    if cross > 0 do
      content
      |> Tinct.Layout.wrap_text(cross)
      |> length()
      |> max(1)
    else
      1
    end
  end

  defp base_size(%Element{style: style, children: children, type: type}, direction, cross) do
    explicit = explicit_main(style, direction)

    if explicit do
      explicit
    else
      padding = main_padding(style, direction)
      children_intrinsic = intrinsic_children_size(children, type, direction, cross)
      padding + children_intrinsic
    end
  end

  defp explicit_main(%Style{} = style, :row), do: style.width
  defp explicit_main(%Style{} = style, :column), do: style.height

  defp main_padding(%Style{} = style, :row), do: style.padding_left + style.padding_right
  defp main_padding(%Style{} = style, :column), do: style.padding_top + style.padding_bottom

  # Compute intrinsic size from children along the main axis
  defp intrinsic_children_size([], _type, _direction, _cross), do: 0

  defp intrinsic_children_size(children, type, direction, cross) do
    child_sizes = Enum.map(children, &base_size(&1, direction, cross))

    case {type, direction} do
      # Column container in column direction: sum children heights
      {:column, :column} -> Enum.sum(child_sizes)
      # Row container in row direction: sum children widths
      {:row, :row} -> Enum.sum(child_sizes)
      # Cross-axis: take the max
      _ -> Enum.max(child_sizes, fn -> 0 end)
    end
  end

  # --- Flex distribution ---

  defp flex_distribute(children, base_sizes, available) do
    total_base = Enum.sum(base_sizes)
    remaining = available - total_base

    cond do
      remaining > 0 ->
        grow_values = Enum.map(children, & &1.style.flex_grow)
        total_grow = Enum.sum(grow_values)

        if total_grow > 0 do
          distribute_grow(base_sizes, grow_values, total_grow, remaining)
        else
          base_sizes
        end

      remaining < 0 ->
        shrink_values = Enum.map(children, & &1.style.flex_shrink)

        weighted =
          base_sizes
          |> Enum.zip(shrink_values)
          |> Enum.map(fn {b, s} -> b * s end)

        total_weighted = Enum.sum(weighted)

        if total_weighted > 0 do
          distribute_shrink(base_sizes, shrink_values, total_weighted, -remaining)
        else
          base_sizes
        end

      true ->
        base_sizes
    end
  end

  defp distribute_grow(base_sizes, grow_values, total_grow, extra) do
    shares =
      Enum.map(grow_values, fn g ->
        if g > 0, do: div(extra * g, total_grow), else: 0
      end)

    distributed = Enum.sum(shares)
    leftover = extra - distributed

    {result, _} =
      [base_sizes, grow_values, shares]
      |> Enum.zip()
      |> Enum.map_reduce(leftover, fn {base, grow, share}, left ->
        bonus = if grow > 0 and left > 0, do: 1, else: 0
        {base + share + bonus, left - bonus}
      end)

    result
  end

  defp distribute_shrink(base_sizes, shrink_values, total_weighted, overflow) do
    reductions =
      base_sizes
      |> Enum.zip(shrink_values)
      |> Enum.map(fn {base, shrink} ->
        if shrink > 0 and base > 0 do
          div(overflow * base * shrink, total_weighted)
        else
          0
        end
      end)

    distributed = Enum.sum(reductions)
    leftover = overflow - distributed

    {result, _} =
      [base_sizes, shrink_values, reductions]
      |> Enum.zip()
      |> Enum.map_reduce(leftover, fn {base, shrink, reduction}, left ->
        extra = if shrink > 0 and base > 0 and left > 0, do: 1, else: 0
        {max(base - reduction - extra, 0), left - extra}
      end)

    result
  end

  # --- Clamping ---

  defp clamp_main(size, %Style{} = style, :row) do
    size
    |> clamp_min(style.min_width)
    |> clamp_max(style.max_width)
  end

  defp clamp_main(size, %Style{} = style, :column) do
    size
    |> clamp_min(style.min_height)
    |> clamp_max(style.max_height)
  end

  defp clamp_min(size, nil), do: size
  defp clamp_min(size, min), do: max(size, min)

  defp clamp_max(size, nil), do: size
  defp clamp_max(size, max), do: min(size, max)

  # --- Cross-axis sizing ---

  defp compute_cross_size(%Element{type: type}, cross_available, :row, :stretch)
       when type in [:text, :rich_text] do
    cross_available
  end

  defp compute_cross_size(%Element{type: type}, _cross_available, :row, _align)
       when type in [:text, :rich_text],
       do: 1

  defp compute_cross_size(%Element{type: type}, cross_available, :column, :stretch)
       when type in [:text, :rich_text] do
    cross_available
  end

  defp compute_cross_size(
         %Element{type: :text, attrs: %{content: content}},
         _cross_available,
         :column,
         _align
       ) do
    String.length(content)
  end

  defp compute_cross_size(
         %Element{type: :rich_text, attrs: %{spans: spans}},
         _cross_available,
         :column,
         _align
       ) do
    Enum.reduce(spans, 0, fn {content, _opts}, acc -> acc + String.length(content) end)
  end

  defp compute_cross_size(%Element{style: style}, cross_available, direction, align) do
    base =
      if align == :stretch,
        do: cross_available,
        else: cross_explicit(style, direction) || cross_available

    case direction do
      :row ->
        base |> clamp_min(style.min_height) |> clamp_max(style.max_height)

      :column ->
        base |> clamp_min(style.min_width) |> clamp_max(style.max_width)
    end
  end

  defp cross_explicit(%Style{} = style, :row), do: style.height
  defp cross_explicit(%Style{} = style, :column), do: style.width

  # --- Positioning ---

  defp position_children(main_sizes, cross_sizes, content_rect, direction, gap, justify, align) do
    {main_available, cross_available} = axis_sizes(content_rect, direction)
    {origin_main, origin_cross} = axis_origin(content_rect, direction)

    n = length(main_sizes)
    total_used = Enum.sum(main_sizes) + if(n > 1, do: gap * (n - 1), else: 0)
    free_space = max(main_available - total_used, 0)

    main_positions = compute_positions(main_sizes, gap, free_space, n, justify)

    [main_positions, main_sizes, cross_sizes]
    |> Enum.zip()
    |> Enum.map(fn {main_pos, main_s, cross_s} ->
      cross_offset = align_offset(align, cross_available, cross_s)

      make_rect(
        origin_main + main_pos,
        origin_cross + cross_offset,
        main_s,
        cross_s,
        direction
      )
    end)
  end

  defp compute_positions(main_sizes, gap, free_space, n, justify) do
    case justify do
      :start ->
        accumulate(main_sizes, gap, 0)

      :end ->
        accumulate(main_sizes, gap, free_space)

      :center ->
        accumulate(main_sizes, gap, div(free_space, 2))

      :space_between when n > 1 ->
        extra_per = div(free_space, n - 1)
        extra_rem = rem(free_space, n - 1)
        accumulate_with_extra(main_sizes, gap, extra_per, extra_rem)

      :space_between ->
        accumulate(main_sizes, gap, 0)

      :space_around when n > 0 ->
        per_child = div(free_space, n)
        start = div(per_child, 2)
        accumulate(main_sizes, gap + per_child, start)

      :space_around ->
        accumulate(main_sizes, gap, 0)
    end
  end

  defp accumulate(sizes, gap, start_offset) do
    {positions, _} =
      Enum.map_reduce(sizes, start_offset, fn size, cursor ->
        {cursor, cursor + size + gap}
      end)

    positions
  end

  defp accumulate_with_extra(sizes, gap, extra_per, extra_rem) do
    {positions, _} =
      Enum.map_reduce(sizes, {0, extra_rem}, fn size, {cursor, rem_left} ->
        bonus = if rem_left > 0, do: 1, else: 0
        next = cursor + size + gap + extra_per + bonus
        {cursor, {next, rem_left - bonus}}
      end)

    positions
  end

  defp align_offset(:stretch, _available, _size), do: 0
  defp align_offset(:start, _available, _size), do: 0
  defp align_offset(:center, available, size), do: max(div(available - size, 2), 0)
  defp align_offset(:end, available, size), do: max(available - size, 0)

  defp make_rect(main_pos, cross_pos, main_size, cross_size, :row) do
    Rect.new(main_pos, cross_pos, main_size, cross_size)
  end

  defp make_rect(main_pos, cross_pos, main_size, cross_size, :column) do
    Rect.new(cross_pos, main_pos, cross_size, main_size)
  end
end
