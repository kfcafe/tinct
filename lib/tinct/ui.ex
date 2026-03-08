defmodule Tinct.UI do
  @moduledoc """
  DSL macros for building terminal UI element trees.

  Instead of manually constructing `Tinct.Element` structs, import this module
  and use its macros and functions for a cleaner syntax:

      import Tinct.UI

      column do
        text "Hello", color: :green
        row do
          text "A"
          text "B"
        end
      end

  ## Macros

    * `column/1` — vertical flex container
    * `row/1` — horizontal flex container
    * `box/1` — generic container
    * `view/1` — creates a `%Tinct.View{}` wrapping an element tree

  ## Functions

    * `text/1`, `text/2` — text leaf elements
    * `spacer/0` — flexible space filler

  ## Style Sugar

  Friendly style names are accepted in opts:

    * `color:` → `fg:`
    * `background:` → `bg:`
  """

  alias Tinct.Element
  alias Tinct.View
  alias Tinct.Widgets.Border

  # ── Container macros ──────────────────────────────────────────────────

  @doc """
  Creates a column element (vertical flex container) from a block of children.

  ## Examples

      import Tinct.UI

      column do
        text "line 1"
        text "line 2"
      end

      column padding: 1 do
        text "padded content"
      end
  """
  defmacro column(do: block) do
    children = extract_children(block)

    quote do
      Tinct.Element.column([], [unquote_splicing(children)])
    end
  end

  defmacro column(opts) do
    {block, opts} = Keyword.pop!(opts, :do)
    children = extract_children(block)

    quote do
      Tinct.Element.column(
        Tinct.UI.__normalize_opts__(unquote(opts)),
        [unquote_splicing(children)]
      )
    end
  end

  @doc false
  defmacro column(opts, do: block) do
    children = extract_children(block)

    quote do
      Tinct.Element.column(
        Tinct.UI.__normalize_opts__(unquote(opts)),
        [unquote_splicing(children)]
      )
    end
  end

  @doc """
  Creates a row element (horizontal flex container) from a block of children.

  ## Examples

      import Tinct.UI

      row do
        text "left"
        text "right"
      end
  """
  defmacro row(do: block) do
    children = extract_children(block)

    quote do
      Tinct.Element.row([], [unquote_splicing(children)])
    end
  end

  defmacro row(opts) do
    {block, opts} = Keyword.pop!(opts, :do)
    children = extract_children(block)

    quote do
      Tinct.Element.row(
        Tinct.UI.__normalize_opts__(unquote(opts)),
        [unquote_splicing(children)]
      )
    end
  end

  @doc false
  defmacro row(opts, do: block) do
    children = extract_children(block)

    quote do
      Tinct.Element.row(
        Tinct.UI.__normalize_opts__(unquote(opts)),
        [unquote_splicing(children)]
      )
    end
  end

  @doc """
  Creates a box element (generic container) from a block of children.

  ## Examples

      import Tinct.UI

      box do
        text "inside a box"
      end

      box padding: 2 do
        text "padded box"
      end
  """
  defmacro box(do: block) do
    children = extract_children(block)

    quote do
      Tinct.Element.box([], [unquote_splicing(children)])
    end
  end

  defmacro box(opts) do
    {block, opts} = Keyword.pop!(opts, :do)
    children = extract_children(block)

    quote do
      Tinct.Element.box(
        Tinct.UI.__normalize_opts__(unquote(opts)),
        [unquote_splicing(children)]
      )
    end
  end

  @doc false
  defmacro box(opts, do: block) do
    children = extract_children(block)

    quote do
      Tinct.Element.box(
        Tinct.UI.__normalize_opts__(unquote(opts)),
        [unquote_splicing(children)]
      )
    end
  end

  # ── Border macro ──────────────────────────────────────────────────────

  @doc """
  Creates a bordered column from a block of children.

  Wraps children in a `Tinct.Widgets.Border` element with configurable style,
  title, and color.

  ## Examples

      import Tinct.UI

      border do
        text "inside a border"
      end

      border title: "Section", style: :round do
        text "bordered content"
      end
  """
  defmacro border(do: block) do
    children = extract_children(block)

    quote do
      Border.element([], [unquote_splicing(children)])
    end
  end

  defmacro border(opts) do
    {block, opts} = Keyword.pop!(opts, :do)
    children = extract_children(block)

    quote do
      Border.element(unquote(opts), [unquote_splicing(children)])
    end
  end

  @doc false
  defmacro border(opts, do: block) do
    children = extract_children(block)

    quote do
      Border.element(unquote(opts), [unquote_splicing(children)])
    end
  end

  # ── View macro ────────────────────────────────────────────────────────

  @doc """
  Creates a `%Tinct.View{}` from a block of elements.

  If the block contains a single element, it becomes the view's content.
  If multiple elements are present, they are wrapped in a column.

  ## Examples

      import Tinct.UI

      view do
        column do
          text "hello"
        end
      end

      view alt_screen: false do
        text "inline view"
      end
  """
  defmacro view(do: block) do
    children = extract_children(block)

    quote do
      Tinct.UI.__wrap_view__([unquote_splicing(children)], [])
    end
  end

  defmacro view(opts) do
    {block, opts} = Keyword.pop!(opts, :do)
    children = extract_children(block)

    quote do
      Tinct.UI.__wrap_view__([unquote_splicing(children)], unquote(opts))
    end
  end

  @doc false
  defmacro view(opts, do: block) do
    children = extract_children(block)

    quote do
      Tinct.UI.__wrap_view__([unquote_splicing(children)], unquote(opts))
    end
  end

  # ── Functions ─────────────────────────────────────────────────────────

  @doc """
  Creates a text element with the given content.

  ## Examples

      iex> import Tinct.UI
      iex> el = text("hello")
      iex> el.attrs.content
      "hello"
  """
  @spec text(String.t()) :: Element.t()
  def text(content) when is_binary(content) do
    Element.text(content)
  end

  @doc """
  Creates a text element with the given content and style options.

  Accepts style sugar: `color:` maps to `fg:`, `background:` maps to `bg:`.

  ## Examples

      iex> import Tinct.UI
      iex> el = text("hello", color: :red)
      iex> el.style.fg
      :red
  """
  @spec text(String.t(), keyword()) :: Element.t()
  def text(content, opts) when is_binary(content) and is_list(opts) do
    Element.text(content, __normalize_opts__(opts))
  end

  @doc """
  Creates a spacer element that expands to fill available space.

  Uses `flex_grow: 1` to push siblings apart, similar to Ink's `<Spacer>`.

  ## Examples

      iex> import Tinct.UI
      iex> el = spacer()
      iex> el.style.flex_grow
      1
  """
  @spec spacer() :: Element.t()
  def spacer do
    Element.box([flex_grow: 1], [])
  end

  # ── Internal helpers (public for generated code) ──────────────────────

  @doc false
  @spec __wrap_view__([Element.t()], keyword()) :: View.t()
  def __wrap_view__([single], []), do: View.new(single)
  def __wrap_view__([single], opts), do: View.new(single, opts)
  def __wrap_view__(children, []), do: View.new(Element.column([], children))
  def __wrap_view__(children, opts), do: View.new(Element.column([], children), opts)

  @doc false
  @spec __normalize_opts__(keyword()) :: keyword()
  def __normalize_opts__(opts) do
    Enum.map(opts, fn
      {:color, val} -> {:fg, val}
      {:background, val} -> {:bg, val}
      other -> other
    end)
  end

  # ── Private helpers (compile-time) ────────────────────────────────────

  defp extract_children({:__block__, _, exprs}), do: exprs
  defp extract_children(nil), do: []
  defp extract_children(single), do: [single]
end
