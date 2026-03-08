defmodule Tinct.Overlay do
  @moduledoc """
  A layered element that renders on top of main content.

  Overlays paint after the main content buffer, overwriting cells at their
  positioned rectangle. Use overlays for command palettes, confirmation dialogs,
  task detail popups, and error modals.

  ## Positioning

  The `:anchor` option controls where the overlay appears on screen:

    * `:center` — centered horizontally and vertically (default)
    * `{:absolute, x, y}` — positioned at exact coordinates

  ## Backdrop

  The `:backdrop` option controls what happens to cells underneath:

    * `:dim` — sets the dim attribute on all non-overlay cells
    * `:none` — leaves background cells untouched (default)

  ## Examples

      Overlay.new(modal_element,
        anchor: :center,
        width: 60,
        height: 20,
        backdrop: :dim
      )
  """

  alias Tinct.Buffer
  alias Tinct.Buffer.Cell
  alias Tinct.Element
  alias Tinct.Layout
  alias Tinct.Layout.Rect
  alias Tinct.Theme

  @typedoc "Anchor position for an overlay."
  @type anchor :: :center | {:absolute, non_neg_integer(), non_neg_integer()}

  @typedoc "Backdrop effect applied to cells underneath the overlay."
  @type backdrop :: :dim | :none

  @typedoc "An overlay layer."
  @type t :: %__MODULE__{
          content: Element.t(),
          anchor: anchor(),
          width: pos_integer(),
          height: pos_integer(),
          backdrop: backdrop()
        }

  @enforce_keys [:content, :width, :height]
  defstruct content: nil,
            anchor: :center,
            width: 0,
            height: 0,
            backdrop: :none

  @doc """
  Creates a new overlay from an element with positioning options.

  ## Options

    * `:anchor` — `:center` or `{:absolute, x, y}` (default `:center`)
    * `:width` (required) — overlay width in columns
    * `:height` (required) — overlay height in rows
    * `:backdrop` — `:dim` or `:none` (default `:none`)

  ## Examples

      iex> el = Tinct.Element.text("Hello")
      iex> overlay = Tinct.Overlay.new(el, width: 40, height: 10)
      iex> overlay.anchor
      :center
      iex> overlay.backdrop
      :none
      iex> overlay.width
      40
  """
  @spec new(Element.t(), keyword()) :: t()
  def new(%Element{} = content, opts) when is_list(opts) do
    %__MODULE__{
      content: content,
      anchor: Keyword.get(opts, :anchor, :center),
      width: Keyword.fetch!(opts, :width),
      height: Keyword.fetch!(opts, :height),
      backdrop: Keyword.get(opts, :backdrop, :none)
    }
  end

  @doc """
  Calculates the positioned rectangle for an overlay within the given screen dimensions.

  Clamps the overlay to fit within the screen bounds.

  ## Examples

      iex> overlay = Tinct.Overlay.new(Tinct.Element.text("hi"), width: 20, height: 10)
      iex> rect = Tinct.Overlay.calculate_rect(overlay, 80, 24)
      iex> {rect.x, rect.y, rect.width, rect.height}
      {30, 7, 20, 10}
  """
  @spec calculate_rect(t(), non_neg_integer(), non_neg_integer()) :: Rect.t()
  def calculate_rect(%__MODULE__{} = overlay, screen_width, screen_height) do
    w = min(overlay.width, screen_width)
    h = min(overlay.height, screen_height)

    {x, y} =
      case overlay.anchor do
        :center ->
          {center_offset(screen_width, w), center_offset(screen_height, h)}

        {:absolute, ax, ay} ->
          {min(ax, max(0, screen_width - w)), min(ay, max(0, screen_height - h))}
      end

    Rect.new(x, y, w, h)
  end

  @doc """
  Applies a list of overlays to a buffer, rendering each on top in order.

  For each overlay:
  1. If backdrop is `:dim`, dims all cells in the current buffer
  2. Renders the overlay's content into a sub-buffer at the calculated rect
  3. Paints the sub-buffer onto the main buffer

  The last overlay in the list renders on top.

  ## Examples

      iex> buf = Tinct.Buffer.new(20, 5)
      iex> el = Tinct.Element.text("OK")
      iex> overlay = Tinct.Overlay.new(el, width: 10, height: 3, anchor: {:absolute, 0, 0})
      iex> result = Tinct.Overlay.render_overlays(buf, [overlay])
      iex> Tinct.Buffer.get(result, 0, 0).char
      "O"
  """
  @spec render_overlays(Buffer.t(), [t()], Theme.t()) :: Buffer.t()
  def render_overlays(buffer, overlays, theme \\ Theme.default())

  def render_overlays(%Buffer{} = buffer, [], _theme), do: buffer

  def render_overlays(%Buffer{} = buffer, overlays, %Theme{} = theme) when is_list(overlays) do
    Enum.reduce(overlays, buffer, fn %__MODULE__{} = overlay, buf ->
      rect = calculate_rect(overlay, buf.width, buf.height)
      buf = apply_backdrop(buf, overlay.backdrop)
      overlay_buf = Layout.render(overlay.content, {rect.width, rect.height}, theme)
      paint_onto(buf, overlay_buf, rect.x, rect.y)
    end)
  end

  # --- Private helpers ---

  defp center_offset(screen_size, overlay_size) do
    div(max(0, screen_size - overlay_size), 2)
  end

  defp apply_backdrop(buffer, :none), do: buffer

  defp apply_backdrop(%Buffer{} = buffer, :dim) do
    cells =
      Map.new(buffer.cells, fn {pos, %Cell{} = cell} ->
        {pos, %{cell | dim: true}}
      end)

    %{buffer | cells: cells}
  end

  defp paint_onto(%Buffer{} = target, %Buffer{} = source, offset_x, offset_y) do
    Enum.reduce(source.cells, target, fn {{col, row}, cell}, buf ->
      target_col = offset_x + col
      target_row = offset_y + row
      Buffer.put(buf, target_col, target_row, cell)
    end)
  end
end
