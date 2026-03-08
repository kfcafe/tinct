defmodule Tinct.Widgets.StatusBar do
  @moduledoc """
  A fixed-position status bar for displaying status information.

  The status bar is one row high and spans the full terminal width. It can be
  pinned to the top or bottom of the screen via `:position`.

  The bar is divided into *sections*. Each section has string content and an
  optional alignment:

      [
        {"main", [align: :left]},
        {"myapp v1.0", [align: :center]},
        {"Ln 42, Col 8", [align: :right]}
      ]

  Sections of the same alignment are joined with a divider (`" │ "`).

  ## Messages

    * `{:set_section, index, section}`
    * `{:set_sections, sections}`

  These mirror the public API functions.
  """

  use Tinct.Component

  alias Tinct.{Element, Style, View}

  @divider " │ "

  @typedoc "Section alignment within the bar."
  @type align :: :left | :center | :right

  @typedoc "Options for a status bar section."
  @type section_opts :: [align: align()]

  @typedoc "A single status bar section."
  @type section :: {String.t(), section_opts()}

  defmodule Model do
    @moduledoc """
    State struct for the StatusBar widget.
    """

    @type t :: %__MODULE__{
            sections: [Tinct.Widgets.StatusBar.section()],
            position: :top | :bottom,
            style: Style.t()
          }

    defstruct sections: [],
              position: :bottom,
              style: Style.new(bg: :bright_black, fg: :white)
  end

  # --- Component callbacks ---

  @doc "Initializes the status bar model from options."
  @impl true
  @spec init(keyword()) :: Model.t()
  def init(opts) when is_list(opts) do
    style =
      opts |> Keyword.get(:style, Style.new(bg: :bright_black, fg: :white)) |> normalize_style()

    %Model{
      sections: opts |> Keyword.get(:sections, []) |> normalize_sections(),
      position: opts |> Keyword.get(:position, :bottom) |> normalize_position(),
      style: style
    }
  end

  @doc "Updates the status bar model. Unknown messages are ignored."
  @impl true
  @spec update(Model.t(), term()) :: Model.t()
  def update(%Model{} = model, {:set_section, index, section})
      when is_integer(index) and index >= 0 do
    set_section(model, index, section)
  end

  def update(%Model{} = model, {:set_sections, sections}) when is_list(sections) do
    set_sections(model, sections)
  end

  def update(%Model{} = model, _msg), do: model

  @doc "Renders the status bar as a full-screen element tree with a fixed bar."
  @impl true
  @spec view(Model.t()) :: View.t()
  def view(%Model{} = model) do
    bar = render_bar(model)
    spacer = Element.box([flex_grow: 1], [])

    tree =
      case model.position do
        :top -> Element.column([], [bar, spacer])
        :bottom -> Element.column([], [spacer, bar])
      end

    View.new(tree)
  end

  # --- Public API ---

  @doc """
  Updates a single section by index.

  If `index` is out of range, the model is returned unchanged.

  ## Examples

      iex> model = Tinct.Widgets.StatusBar.init(sections: [{"a", [align: :left]}])
      iex> model = Tinct.Widgets.StatusBar.set_section(model, 0, {"b", [align: :left]})
      iex> model.sections
      [{"b", [align: :left]}]
  """
  @spec set_section(Model.t(), non_neg_integer(), section() | String.t()) :: Model.t()
  def set_section(%Model{sections: sections} = model, index, section)
      when is_integer(index) and index >= 0 do
    normalized_section = normalize_section(section)

    if index < length(sections) do
      %{model | sections: List.replace_at(sections, index, normalized_section)}
    else
      model
    end
  end

  @doc """
  Replaces all sections.

  ## Examples

      iex> model = Tinct.Widgets.StatusBar.init(sections: [])
      iex> model = Tinct.Widgets.StatusBar.set_sections(model, [{"x", [align: :right]}])
      iex> model.sections
      [{"x", [align: :right]}]
  """
  @spec set_sections(Model.t(), [section() | String.t()]) :: Model.t()
  def set_sections(%Model{} = model, sections) when is_list(sections) do
    %{model | sections: normalize_sections(sections)}
  end

  # --- Rendering ---

  defp render_bar(%Model{} = model) do
    {left, center, right} = group_section_strings(model.sections)

    children = bar_children(left, center, right, model.style)

    %Element{
      type: :row,
      style: Style.merge(model.style, Style.new(height: 1)),
      children: children,
      attrs: %{}
    }
  end

  defp bar_children(left, center, right, %Style{} = style) do
    left_el = if is_binary(left), do: bar_text(left, style), else: nil
    center_el = if is_binary(center), do: bar_text(center, style), else: nil
    right_el = if is_binary(right), do: bar_text(right, style), else: nil
    fill_el = fn -> bar_fill(style) end

    children = if left_el, do: [left_el], else: []

    children =
      if center_el do
        children ++ [fill_el.(), center_el, fill_el.()]
      else
        children ++ [fill_el.()]
      end

    if right_el do
      children ++ [right_el]
    else
      children
    end
  end

  defp bar_text(content, %Style{} = style) when is_binary(content) do
    %Element{
      type: :text,
      style: style,
      children: [],
      attrs: %{content: content, preserve_whitespace: true, pad_to_width: true}
    }
  end

  defp bar_fill(%Style{} = style) do
    %Element{
      type: :text,
      style: Style.merge(style, Style.new(flex_grow: 1)),
      children: [],
      attrs: %{content: "", preserve_whitespace: true, pad_to_width: true}
    }
  end

  defp group_section_strings(sections) do
    {left, center, right} =
      Enum.reduce(sections, {[], [], []}, fn section, {l, c, r} ->
        {content, opts} = normalize_section(section)
        align = Keyword.get(opts, :align, :left)

        case align do
          :left -> {[content | l], c, r}
          :center -> {l, [content | c], r}
          :right -> {l, c, [content | r]}
        end
      end)

    {
      join_or_nil(Enum.reverse(left)),
      join_or_nil(Enum.reverse(center)),
      join_or_nil(Enum.reverse(right))
    }
  end

  defp join_or_nil([]), do: nil
  defp join_or_nil(parts), do: Enum.join(parts, @divider)

  # --- Normalization ---

  defp normalize_position(:top), do: :top
  defp normalize_position(:bottom), do: :bottom
  defp normalize_position(_), do: :bottom

  defp normalize_style(%Style{} = style), do: style
  defp normalize_style(opts) when is_list(opts), do: Style.new(opts)
  defp normalize_style(_), do: Style.new(bg: :bright_black, fg: :white)

  defp normalize_sections(sections) when is_list(sections) do
    Enum.map(sections, &normalize_section/1)
  end

  defp normalize_section({content, opts}) when is_list(opts) do
    content = content |> to_string() |> String.replace("\n", " ")
    align = opts |> Keyword.get(:align, :left) |> normalize_align()
    {content, [align: align]}
  end

  defp normalize_section(content) do
    normalize_section({content, []})
  end

  defp normalize_align(:left), do: :left
  defp normalize_align(:center), do: :center
  defp normalize_align(:right), do: :right
  defp normalize_align(_), do: :left
end
