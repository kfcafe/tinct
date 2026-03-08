defmodule Tinct.Widgets.Border do
  @moduledoc """
  A container widget that wraps children in a border.

  Renders border characters around a rectangular area with optional title
  and color. Children render inside the border, inset by one cell on each side.

  ## Usage as a component

      state = Tinct.Test.render(Tinct.Widgets.Border,
        style: :round,
        title: "My Section",
        children: [Tinct.Element.text("Hello")]
      )

  ## Usage via UI DSL

      import Tinct.UI

      border title: "My Section", style: :round do
        text "Hello world"
        text "Another line"
      end

  ## Border styles

    * `:single` — light box drawing (default)
    * `:double` — double-line box drawing
    * `:round` — rounded corners
    * `:bold` — heavy box drawing
  """

  use Tinct.Component

  alias Tinct.{Element, Style, View}

  @typedoc "Border widget model."
  @type model :: %{
          style: Tinct.Layout.Border.border_style(),
          title: String.t() | nil,
          color: Tinct.Color.t() | nil,
          children: [Element.t()]
        }

  @doc """
  Initializes the border widget from the given options.

  ## Options

    * `:style` — border style: `:single`, `:double`, `:round`, or `:bold` (default `:single`)
    * `:title` — text to display in the top border (default `nil`)
    * `:color` — foreground color for border characters (default `nil`)
    * `:children` — list of child elements to render inside the border (default `[]`)

  ## Examples

      iex> model = Tinct.Widgets.Border.init([])
      iex> model.style
      :single

      iex> model = Tinct.Widgets.Border.init(style: :round, title: "Hello")
      iex> {model.style, model.title}
      {:round, "Hello"}
  """
  @impl Tinct.Component
  @spec init(keyword()) :: model()
  def init(opts) do
    %{
      style: Keyword.get(opts, :style, :single),
      title: Keyword.get(opts, :title, nil),
      color: Keyword.get(opts, :color, nil),
      children: Keyword.get(opts, :children, [])
    }
  end

  @doc """
  Passes messages through unchanged. The border is a stateless wrapper.
  """
  @impl Tinct.Component
  @spec update(model(), term()) :: model()
  def update(model, _msg), do: model

  @doc """
  Renders the border with children inside.

  Creates a bordered column element containing the children. The border style,
  title, and color are applied based on the current model state.
  """
  @impl Tinct.Component
  @spec view(model()) :: View.t()
  def view(model) do
    View.new(element(model_to_opts(model), model.children))
  end

  @doc """
  Creates a bordered column element with the given options and children.

  This function is used by the UI DSL `border` macro and can also be called
  directly to build border elements without the component lifecycle.

  ## Options

    * `:style` — border style (default `:single`)
    * `:title` — title text for the top border (default `nil`)
    * `:color` — foreground color for border characters (default `nil`)
    * `:id` — optional panel identifier stored as `attrs.panel_id`
    * `:attrs` — additional attrs map merged into element attrs

  Any other options are forwarded into the element style, so width/height/flex
  values can be applied directly to the bordered container.

  ## Examples

      iex> el = Tinct.Widgets.Border.element([style: :round], [])
      iex> el.style.border
      :round
  """
  @spec element(keyword(), [Element.t()]) :: Element.t()
  def element(opts, children) when is_list(opts) and is_list(children) do
    border_style = Keyword.get(opts, :style, :single)
    title = Keyword.get(opts, :title)
    color = Keyword.get(opts, :color)

    extra_attrs =
      opts
      |> Keyword.get(:attrs, %{})
      |> normalize_attrs()
      |> maybe_put_panel_id(Keyword.get(opts, :id))

    style_opts = Keyword.drop(opts, [:style, :title, :color, :id, :attrs])

    %Element{
      type: :column,
      style: Style.new([border: border_style] ++ style_opts),
      children: children,
      attrs: build_attrs(title, color, extra_attrs)
    }
  end

  # --- Private helpers ---

  defp model_to_opts(model) do
    opts = [style: model.style]
    opts = if model.title, do: [{:title, model.title} | opts], else: opts
    if model.color, do: [{:color, model.color} | opts], else: opts
  end

  defp build_attrs(title, color, extra_attrs) when is_map(extra_attrs) do
    extra_attrs
    |> maybe_put_title(title)
    |> maybe_put_border_color(color)
  end

  defp maybe_put_title(attrs, nil), do: attrs
  defp maybe_put_title(attrs, title), do: Map.put(attrs, :title, title)

  defp maybe_put_border_color(attrs, nil), do: attrs
  defp maybe_put_border_color(attrs, color), do: Map.put(attrs, :border_color, color)

  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
  defp normalize_attrs(_), do: %{}

  defp maybe_put_panel_id(attrs, nil), do: attrs
  defp maybe_put_panel_id(attrs, panel_id), do: Map.put(attrs, :panel_id, panel_id)
end
