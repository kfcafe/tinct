defmodule Tinct.Element do
  @moduledoc """
  An element tree node for terminal UI layout.

  Elements are the building blocks returned by `view/1` functions. Each element
  has a type, a style, children, and arbitrary attributes. The layout engine
  walks this tree to compute positioned rectangles, and the renderer paints
  them into a buffer.

  ## Element types

    * `:box` — a generic container (like HTML `<div>`), has children, styled
    * `:text` — a text leaf node, `attrs.content` holds the string, no children
    * `:row` — horizontal flex container (shorthand for box with `flex_direction: :row`)
    * `:column` — vertical flex container (shorthand for box with `flex_direction: :column`)

  ## Builder functions

  Use the builder functions to construct element trees:

      column([], [
        text("Hello", fg: :green, bold: true),
        row([gap: 1], [
          text("Left"),
          text("Right")
        ])
      ])
  """

  alias Tinct.Style

  @typedoc "The kind of element."
  @type element_type :: :box | :text | :rich_text | :row | :column

  @typedoc "A single styled span within a rich text element."
  @type span :: {String.t(), keyword()}

  @typedoc "An element tree node."
  @type t :: %__MODULE__{
          type: element_type(),
          style: Style.t(),
          children: [t()],
          attrs: map()
        }

  defstruct type: :box,
            style: %Style{},
            children: [],
            attrs: %{}

  # --- Builder functions ---

  @doc """
  Creates a `:box` element with the given style options and children.

  ## Examples

      iex> el = Tinct.Element.box([padding: 1], [Tinct.Element.text("hi")])
      iex> el.type
      :box
      iex> length(el.children)
      1
  """
  @spec box(keyword(), [t()]) :: t()
  def box(opts \\ [], children \\ []) do
    %__MODULE__{
      type: :box,
      style: Style.new(opts),
      children: List.wrap(children)
    }
  end

  @doc """
  Creates a `:row` element (horizontal flex container) with the given style options and children.

  ## Examples

      iex> el = Tinct.Element.row([gap: 1], [Tinct.Element.text("a"), Tinct.Element.text("b")])
      iex> el.type
      :row
  """
  @spec row(keyword(), [t()]) :: t()
  def row(opts \\ [], children \\ []) do
    %__MODULE__{
      type: :row,
      style: Style.new(opts),
      children: List.wrap(children)
    }
  end

  @doc """
  Creates a `:column` element (vertical flex container) with the given style options and children.

  ## Examples

      iex> el = Tinct.Element.column([], [Tinct.Element.text("line 1"), Tinct.Element.text("line 2")])
      iex> el.type
      :column
  """
  @spec column(keyword(), [t()]) :: t()
  def column(opts \\ [], children \\ []) do
    %__MODULE__{
      type: :column,
      style: Style.new(opts),
      children: List.wrap(children)
    }
  end

  @doc """
  Creates a `:text` element with default style.

  ## Examples

      iex> el = Tinct.Element.text("hello")
      iex> el.type
      :text
      iex> el.attrs.content
      "hello"
  """
  @spec text(String.t()) :: t()
  def text(content) when is_binary(content) do
    %__MODULE__{
      type: :text,
      style: %Style{},
      children: [],
      attrs: %{content: content}
    }
  end

  @doc """
  Creates a `:text` element with style overrides.

  ## Examples

      iex> el = Tinct.Element.text("hello", fg: :red, bold: true)
      iex> el.attrs.content
      "hello"
      iex> el.style.fg
      :red
      iex> el.style.bold
      true
  """
  @spec text(String.t(), keyword()) :: t()
  def text(content, opts) when is_binary(content) and is_list(opts) do
    %__MODULE__{
      type: :text,
      style: Style.new(opts),
      children: [],
      attrs: %{content: content}
    }
  end

  @doc """
  Creates a `:rich_text` element from a list of styled spans.

  Each span is a `{content, style_opts}` tuple where `content` is a string and
  `style_opts` is a keyword list of style overrides (same options as `text/2`).

  All spans render on a single line with no breaks between them. Each span
  carries its own independent style.

  ## Examples

      iex> el = Tinct.Element.rich([{"hello ", []}, {"world", [fg: :red]}])
      iex> el.type
      :rich_text
      iex> length(el.attrs.spans)
      2
  """
  @spec rich([span()]) :: t()
  def rich(spans) when is_list(spans) do
    validated_spans =
      Enum.map(spans, fn {content, opts} when is_binary(content) and is_list(opts) ->
        {content, opts}
      end)

    %__MODULE__{
      type: :rich_text,
      style: %Style{},
      children: [],
      attrs: %{spans: validated_spans}
    }
  end

  @doc """
  Creates a `:rich_text` element from a list of styled spans with element-level style options.

  The element-level style applies layout properties (padding, flex, etc.) while
  each span retains its own visual style.

  ## Examples

      iex> el = Tinct.Element.rich([{"hello", [fg: :blue]}], flex_grow: 1)
      iex> el.type
      :rich_text
      iex> el.style.flex_grow
      1
  """
  @spec rich([span()], keyword()) :: t()
  def rich(spans, opts) when is_list(spans) and is_list(opts) do
    validated_spans =
      Enum.map(spans, fn {content, opts_inner} when is_binary(content) and is_list(opts_inner) ->
        {content, opts_inner}
      end)

    %__MODULE__{
      type: :rich_text,
      style: Style.new(opts),
      children: [],
      attrs: %{spans: validated_spans}
    }
  end

  # --- Query functions ---

  @doc """
  Returns `true` if the element is a `:text` element.

  ## Examples

      iex> Tinct.Element.text?(%Tinct.Element{type: :text})
      true

      iex> Tinct.Element.text?(%Tinct.Element{type: :box})
      false
  """
  @spec text?(t()) :: boolean()
  def text?(%__MODULE__{type: :text}), do: true
  def text?(%__MODULE__{}), do: false

  @doc """
  Returns `true` if the element is a `:rich_text` element.

  ## Examples

      iex> Tinct.Element.rich_text?(%Tinct.Element{type: :rich_text, attrs: %{spans: []}})
      true

      iex> Tinct.Element.rich_text?(%Tinct.Element{type: :text})
      false
  """
  @spec rich_text?(t()) :: boolean()
  def rich_text?(%__MODULE__{type: :rich_text}), do: true
  def rich_text?(%__MODULE__{}), do: false

  @doc """
  Returns `true` if the element is a container (`:box`, `:row`, or `:column`).

  ## Examples

      iex> Tinct.Element.container?(%Tinct.Element{type: :box})
      true

      iex> Tinct.Element.container?(%Tinct.Element{type: :row})
      true

      iex> Tinct.Element.container?(%Tinct.Element{type: :text})
      false
  """
  @spec container?(t()) :: boolean()
  def container?(%__MODULE__{type: type}) when type in [:box, :row, :column], do: true
  def container?(%__MODULE__{}), do: false

  # --- Mutation functions ---

  @doc """
  Appends a child element to a container element.

  ## Examples

      iex> parent = Tinct.Element.box([], [Tinct.Element.text("first")])
      iex> updated = Tinct.Element.add_child(parent, Tinct.Element.text("second"))
      iex> length(updated.children)
      2
  """
  @spec add_child(t(), t()) :: t()
  def add_child(%__MODULE__{children: children} = element, %__MODULE__{} = child) do
    %{element | children: children ++ [child]}
  end

  @doc """
  Updates the element's style by merging in keyword overrides.

  Builds a new `Tinct.Style` from the keyword list and merges it on top of
  the element's existing style.

  ## Examples

      iex> el = Tinct.Element.text("hi", fg: :blue)
      iex> updated = Tinct.Element.set_style(el, fg: :red, bold: true)
      iex> {updated.style.fg, updated.style.bold}
      {:red, true}
  """
  @spec set_style(t(), keyword()) :: t()
  def set_style(%__MODULE__{style: current_style} = element, opts) when is_list(opts) do
    override = Style.new(opts)
    %{element | style: Style.merge(current_style, override)}
  end
end
