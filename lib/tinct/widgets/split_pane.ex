defmodule Tinct.Widgets.SplitPane do
  @moduledoc """
  A split pane widget that divides available space between children with a
  visible divider.

  Supports horizontal (side by side) and vertical (stacked) splits with
  configurable ratios and minimum size constraints.

  ## Usage as a component

      state = Tinct.Test.render(Tinct.Widgets.SplitPane,
        direction: :horizontal,
        panes: [
          {Element.text("Left"), ratio: 0.3, min: 20},
          {Element.text("Right"), ratio: 0.7}
        ]
      )

  ## Usage via element function

      SplitPane.element(
        direction: :vertical,
        panes: [
          {Element.text("Top"), ratio: 0.6},
          {Element.text("Bottom"), ratio: 0.4}
        ]
      )

  ## Nested splits

      inner = SplitPane.element(
        direction: :vertical,
        panes: [
          {Element.text("Top"), ratio: 0.5},
          {Element.text("Bottom"), ratio: 0.5}
        ]
      )

      SplitPane.element(
        direction: :horizontal,
        panes: [
          {Element.text("Left"), ratio: 0.3},
          {inner, ratio: 0.7}
        ]
      )
  """

  use Tinct.Component

  alias Tinct.{Element, Style, View}

  @typedoc "Split direction: `:horizontal` for side by side, `:vertical` for stacked."
  @type direction :: :horizontal | :vertical

  @typedoc "Divider line style."
  @type divider_style :: :single

  defmodule Model do
    @moduledoc "State struct for the SplitPane widget."

    @type t :: %__MODULE__{
            direction: Tinct.Widgets.SplitPane.direction(),
            panes: [map()],
            divider: Tinct.Widgets.SplitPane.divider_style()
          }

    defstruct direction: :horizontal,
              panes: [],
              divider: :single
  end

  # --- Component callbacks ---

  @doc """
  Initializes the split pane from the given options.

  ## Options

    * `:direction` — `:horizontal` (side by side) or `:vertical` (stacked).
      Default: `:horizontal`
    * `:panes` — list of `{element, opts}` tuples where opts can include:
      * `:ratio` — proportion of space (default: `0.5`)
      * `:min` — minimum size in cells (default: `0`)
    * `:divider` — divider style, currently only `:single` (default: `:single`)

  ## Examples

      iex> model = Tinct.Widgets.SplitPane.init(direction: :horizontal)
      iex> model.direction
      :horizontal
  """
  @impl Tinct.Component
  @spec init(keyword()) :: Model.t()
  def init(opts) when is_list(opts) do
    %Model{
      direction: Keyword.get(opts, :direction, :horizontal),
      panes: parse_panes(Keyword.get(opts, :panes, [])),
      divider: Keyword.get(opts, :divider, :single)
    }
  end

  @doc "Passes messages through unchanged. Phase 1 is a stateless layout."
  @impl Tinct.Component
  @spec update(Model.t(), term()) :: Model.t()
  def update(%Model{} = model, _msg), do: model

  @doc "Renders the split pane layout."
  @impl Tinct.Component
  @spec view(Model.t()) :: View.t()
  def view(%Model{} = model) do
    View.new(build_element(model.direction, model.panes, model.divider))
  end

  # --- Public API ---

  @doc """
  Creates a split pane element from options.

  This function builds the element tree directly, bypassing the component
  lifecycle. Useful for composing split panes inside other views or for
  nesting splits.

  Accepts the same options as `init/1`.

  ## Examples

      iex> alias Tinct.{Element, Widgets.SplitPane}
      iex> el = SplitPane.element(
      ...>   direction: :horizontal,
      ...>   panes: [
      ...>     {Element.text("A"), ratio: 0.5},
      ...>     {Element.text("B"), ratio: 0.5}
      ...>   ]
      ...> )
      iex> el.type
      :row
  """
  @spec element(keyword()) :: Element.t()
  def element(opts) when is_list(opts) do
    direction = Keyword.get(opts, :direction, :horizontal)
    panes = parse_panes(Keyword.get(opts, :panes, []))
    divider = Keyword.get(opts, :divider, :single)
    build_element(direction, panes, divider)
  end

  # --- Private helpers ---

  defp parse_panes(panes) when is_list(panes) do
    Enum.map(panes, fn {element, opts} ->
      %{
        element: element,
        ratio: Keyword.get(opts, :ratio, 0.5),
        min: Keyword.get(opts, :min, 0)
      }
    end)
  end

  defp build_element(:horizontal, panes, divider) do
    children = interleave_with_divider(panes, :horizontal, divider)
    Element.row([flex_grow: 1], children)
  end

  defp build_element(:vertical, panes, divider) do
    children = interleave_with_divider(panes, :vertical, divider)
    Element.column([flex_grow: 1], children)
  end

  defp interleave_with_divider(panes, direction, divider) do
    char = divider_char(direction, divider)

    panes
    |> Enum.map(&pane_element(&1, direction))
    |> Enum.intersperse(divider_element(direction, char))
  end

  defp pane_element(pane, :horizontal) do
    grow = ratio_to_grow(pane.ratio)
    opts = [width: 0, flex_grow: grow, flex_shrink: 0]
    opts = if pane.min > 0, do: [{:min_width, pane.min} | opts], else: opts
    Element.box(opts, [pane.element])
  end

  defp pane_element(pane, :vertical) do
    grow = ratio_to_grow(pane.ratio)
    opts = [height: 0, flex_grow: grow, flex_shrink: 0]
    opts = if pane.min > 0, do: [{:min_height, pane.min} | opts], else: opts
    Element.box(opts, [pane.element])
  end

  defp divider_element(:horizontal, char) do
    %Element{
      type: :box,
      style: Style.new(width: 1, flex_shrink: 0, flex_grow: 0),
      children: [],
      attrs: %{split_divider: char}
    }
  end

  defp divider_element(:vertical, char) do
    %Element{
      type: :box,
      style: Style.new(height: 1, flex_shrink: 0, flex_grow: 0),
      children: [],
      attrs: %{split_divider: char}
    }
  end

  defp divider_char(:horizontal, :single), do: "│"
  defp divider_char(:vertical, :single), do: "─"

  defp ratio_to_grow(ratio) when is_float(ratio), do: round(ratio * 1000)
  defp ratio_to_grow(ratio) when is_integer(ratio), do: ratio * 1000
end
