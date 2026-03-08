defmodule Tinct.Widgets.ScrollView do
  @moduledoc """
  A scrollable viewport widget.

  `ScrollView` wraps content (a list of child elements) and exposes a viewport
  into that content using `offset_x`/`offset_y` scrolling.

  This widget is intentionally simple: it treats each child as a single “row”
  of content. This matches many common terminal UI patterns (lists, log output,
  etc.) and is sufficient for the current widgets in Tinct.

  When the content height exceeds the viewport height, `ScrollView` can render a
  1-column scrollbar on the right edge.

  ## Init options

    * `:children` — list of `Tinct.Element.t()` (default `[]`)
    * `:width` — viewport width in columns (default `80`)
    * `:height` — viewport height in rows (default `10`)
    * `:show_scrollbar` — show scrollbar when scrollable (default `true`)

  ## Key handling

    * Up / mouse wheel up — scroll up 1
    * Down / mouse wheel down — scroll down 1
    * Page Up — scroll up by viewport height
    * Page Down — scroll down by viewport height

  ## Scrollbar

  When the content is taller than the viewport, a vertical scrollbar is drawn on
  the right edge:

    * Track: `│`
    * Thumb: `█`

  Thumb size is proportional to the visible fraction of the content, with a
  minimum size of 1.
  """

  use Tinct.Component

  alias Tinct.{Element, Event, View}

  @track "│"
  @thumb "█"

  defmodule Model do
    @moduledoc """
    State struct for the ScrollView widget.

    `viewport_width`/`viewport_height` represent the visible area.

    `content_width`/`content_height` are derived from the children to support
    scroll bounds.
    """

    @type t :: %__MODULE__{
            offset_x: integer(),
            offset_y: integer(),
            content_width: non_neg_integer(),
            content_height: non_neg_integer(),
            viewport_width: pos_integer(),
            viewport_height: pos_integer(),
            show_scrollbar: boolean(),
            children: [Tinct.Element.t()]
          }

    defstruct offset_x: 0,
              offset_y: 0,
              content_width: 0,
              content_height: 0,
              viewport_width: 80,
              viewport_height: 10,
              show_scrollbar: true,
              children: []
  end

  # --- Component callbacks ---

  @doc "Initializes the ScrollView model from the given options."
  @impl true
  @spec init(keyword()) :: Model.t()
  def init(opts) do
    children = Keyword.get(opts, :children, [])

    viewport_width =
      opts
      |> Keyword.get(:width, 80)
      |> max(1)

    viewport_height =
      opts
      |> Keyword.get(:height, 10)
      |> max(1)

    show_scrollbar = Keyword.get(opts, :show_scrollbar, true)

    {content_width, content_height} = measure_content(children, viewport_width)

    %Model{
      children: children,
      viewport_width: viewport_width,
      viewport_height: viewport_height,
      content_width: content_width,
      content_height: content_height,
      show_scrollbar: show_scrollbar,
      offset_x: 0,
      offset_y: 0
    }
    |> clamp_offset()
  end

  @doc "Handles messages. Supports scrolling key/mouse events and `{:set_children, children}`."
  @impl true
  @spec update(Model.t(), term()) :: Model.t()
  def update(%Model{} = model, %Event.Key{type: :press} = key) do
    handle_key(model, key)
  end

  def update(%Model{} = model, %Event.Mouse{type: :wheel, button: :wheel_up}) do
    scroll_by(model, 0, -1)
  end

  def update(%Model{} = model, %Event.Mouse{type: :wheel, button: :wheel_down}) do
    scroll_by(model, 0, 1)
  end

  def update(%Model{} = model, %Event.Resize{width: width, height: height})
      when is_integer(width) and is_integer(height) do
    model
    |> put_viewport_size(max(width, 1), max(height, 1))
    |> clamp_offset()
  end

  def update(%Model{} = model, {:set_children, children}) when is_list(children) do
    {content_width, content_height} = measure_content(children, model.viewport_width)

    %{model | children: children, content_width: content_width, content_height: content_height}
    |> clamp_offset()
  end

  def update(%Model{} = model, _msg), do: model

  @doc "Renders the current viewport as an element tree wrapped in a `Tinct.View`."
  @impl true
  @spec view(Model.t()) :: View.t()
  def view(%Model{} = model) do
    View.new(render_viewport(model))
  end

  # --- Public API ---

  @doc """
  Scrolls to an absolute position `{x, y}`, clamped to valid bounds.

  ## Examples

      iex> children = Enum.map(1..20, fn i -> Tinct.Element.text("Line \#{i}") end)
      iex> model = Tinct.Widgets.ScrollView.init(children: children, height: 5)
      iex> model = Tinct.Widgets.ScrollView.scroll_to(model, {0, 10})
      iex> model.offset_y
      10
  """
  @spec scroll_to(Model.t(), {integer(), integer()}) :: Model.t()
  def scroll_to(%Model{} = model, {x, y}) when is_integer(x) and is_integer(y) do
    %{model | offset_x: x, offset_y: y}
    |> clamp_offset()
  end

  @doc """
  Scrolls to the top of the content, resetting both offsets to zero.

  ## Examples

      iex> children = Enum.map(1..20, fn i -> Tinct.Element.text("Line \#{i}") end)
      iex> model = Tinct.Widgets.ScrollView.init(children: children, height: 5)
      iex> model = Tinct.Widgets.ScrollView.scroll_to(model, {0, 10})
      iex> model = Tinct.Widgets.ScrollView.scroll_to_top(model)
      iex> model.offset_y
      0
  """
  @spec scroll_to_top(Model.t()) :: Model.t()
  def scroll_to_top(%Model{} = model) do
    %{model | offset_x: 0, offset_y: 0}
    |> clamp_offset()
  end

  @doc """
  Scrolls to the bottom of the content so the last rows are visible.

  ## Examples

      iex> children = Enum.map(1..20, fn i -> Tinct.Element.text("Line \#{i}") end)
      iex> model = Tinct.Widgets.ScrollView.init(children: children, height: 5)
      iex> model = Tinct.Widgets.ScrollView.scroll_to_bottom(model)
      iex> model.offset_y
      15
  """
  @spec scroll_to_bottom(Model.t()) :: Model.t()
  def scroll_to_bottom(%Model{} = model) do
    %{model | offset_y: max_y(model)}
    |> clamp_offset()
  end

  # --- Rendering ---

  defp render_viewport(%Model{} = model) do
    scrollbar_needed = needs_scrollbar?(model)
    viewport_content_width = viewport_content_width(model, scrollbar_needed)

    visible_children = Enum.slice(model.children, model.offset_y, model.viewport_height)

    {thumb_start, thumb_size} =
      if scrollbar_needed do
        scrollbar_geometry(model)
      else
        {0, 0}
      end

    rows =
      visible_children
      |> Enum.with_index()
      |> Enum.map(fn {child, visual_idx} ->
        line = render_child_line(child, model.offset_x, viewport_content_width)
        line_box = Element.box([width: viewport_content_width, height: 1], [Element.text(line)])

        if scrollbar_needed do
          sb_char = scrollbar_char(visual_idx, thumb_start, thumb_size)
          Element.row([height: 1], [line_box, Element.text(sb_char)])
        else
          line_box
        end
      end)

    # Pad to viewport height with blank rows.
    rows =
      rows ++
        blank_rows(model.viewport_height - length(rows), viewport_content_width, scrollbar_needed)

    Element.column([], rows)
  end

  defp blank_rows(n, _viewport_content_width, _scrollbar_needed) when n <= 0 do
    []
  end

  defp blank_rows(n, viewport_content_width, scrollbar_needed) do
    blank_box = Element.box([width: viewport_content_width, height: 1], [Element.text("")])

    if scrollbar_needed do
      Enum.map(1..n, fn _ -> Element.row([height: 1], [blank_box, Element.text(@track)]) end)
    else
      Enum.map(1..n, fn _ -> blank_box end)
    end
  end

  defp render_child_line(%Element{type: :text, attrs: %{content: content}}, offset_x, width)
       when is_integer(offset_x) and is_integer(width) do
    slice_graphemes(content, offset_x, width)
  end

  defp render_child_line(%Element{} = _child, _offset_x, _width) do
    ""
  end

  defp slice_graphemes(_string, _offset, width) when width <= 0, do: ""

  defp slice_graphemes(string, offset, width) do
    graphemes = String.graphemes(string)

    graphemes
    |> Enum.slice(max(offset, 0), width)
    |> Enum.join()
  end

  # --- Key handling ---

  defp handle_key(model, %Event.Key{key: :up, mod: []}) do
    scroll_by(model, 0, -1)
  end

  defp handle_key(model, %Event.Key{key: :down, mod: []}) do
    scroll_by(model, 0, 1)
  end

  defp handle_key(model, %Event.Key{key: :page_up, mod: []}) do
    scroll_by(model, 0, -model.viewport_height)
  end

  defp handle_key(model, %Event.Key{key: :page_down, mod: []}) do
    scroll_by(model, 0, model.viewport_height)
  end

  defp handle_key(model, _key), do: model

  # --- Model helpers ---

  defp put_viewport_size(%Model{} = model, width, height)
       when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    %{model | viewport_width: width, viewport_height: height}
  end

  defp scroll_by(%Model{} = model, dx, dy) when is_integer(dx) and is_integer(dy) do
    %{model | offset_x: model.offset_x + dx, offset_y: model.offset_y + dy}
    |> clamp_offset()
  end

  defp clamp_offset(%Model{} = model) do
    scrollbar_needed = needs_scrollbar?(model)
    viewport_content_width = viewport_content_width(model, scrollbar_needed)

    %{
      model
      | offset_x: clamp(model.offset_x, 0, max(0, model.content_width - viewport_content_width)),
        offset_y: clamp(model.offset_y, 0, max_y(model))
    }
  end

  defp max_y(%Model{} = model) do
    max(0, model.content_height - model.viewport_height)
  end

  defp clamp(value, min_val, max_val) do
    value
    |> max(min_val)
    |> min(max_val)
  end

  defp measure_content(children, min_width) when is_list(children) and is_integer(min_width) do
    content_height = length(children)

    max_line_width =
      children
      |> Enum.map(&element_intrinsic_width/1)
      |> Enum.max(fn -> 0 end)

    content_width = max(max_line_width, min_width)

    {content_width, content_height}
  end

  defp element_intrinsic_width(%Element{type: :text, attrs: %{content: content}})
       when is_binary(content) do
    String.length(content)
  end

  defp element_intrinsic_width(%Element{style: %{width: width}}) when is_integer(width), do: width
  defp element_intrinsic_width(%Element{}), do: 0

  # --- Scrollbar ---

  defp needs_scrollbar?(%Model{show_scrollbar: false}), do: false

  defp needs_scrollbar?(%Model{content_height: content_height, viewport_height: viewport_height})
       when is_integer(content_height) and is_integer(viewport_height) do
    content_height > viewport_height
  end

  defp viewport_content_width(%Model{viewport_width: viewport_width}, true) do
    max(viewport_width - 1, 0)
  end

  defp viewport_content_width(%Model{viewport_width: viewport_width}, false) do
    viewport_width
  end

  defp scrollbar_geometry(%Model{} = model) do
    vh = model.viewport_height
    ch = model.content_height

    thumb_size = max(1, div(vh * vh, ch))

    max_offset = max(ch - vh, 1)
    available_track = max(vh - thumb_size, 0)

    thumb_start = div(model.offset_y * available_track, max_offset)

    {thumb_start, thumb_size}
  end

  defp scrollbar_char(visual_idx, thumb_start, thumb_size) do
    if visual_idx >= thumb_start and visual_idx < thumb_start + thumb_size do
      @thumb
    else
      @track
    end
  end
end
