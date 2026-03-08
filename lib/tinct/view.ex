defmodule Tinct.View do
  @moduledoc """
  Declarative view struct returned by component `view/1` functions.

  A `View` describes the entire desired terminal state: the element tree to
  render, cursor position, alternate screen mode, mouse tracking, and other
  terminal capabilities. The framework compares the previous `View` to the
  current `View` to determine the minimal set of terminal state changes needed.

  Inspired by Bubble Tea v2's declarative view approach.

  ## Examples

      view = View.new(my_element_tree)
      view = View.new(my_element_tree, alt_screen: false, title: "My App")

      view
      |> View.set_cursor(Cursor.new(0, 0, shape: :bar))
      |> View.set_content(updated_tree)
  """

  alias Tinct.Cursor
  alias Tinct.Element
  alias Tinct.Overlay

  @typedoc "Mouse tracking mode."
  @type mouse_mode :: nil | :cell_motion | :all_motion

  @typedoc "A declarative view of the entire terminal state."
  @type t :: %__MODULE__{
          content: Element.t() | nil,
          cursor: Cursor.t() | nil,
          alt_screen: boolean(),
          mouse_mode: mouse_mode(),
          title: String.t() | nil,
          report_focus: boolean(),
          bracketed_paste: boolean(),
          keyboard_enhancements: [atom()],
          overlays: [Overlay.t()]
        }

  defstruct content: nil,
            cursor: nil,
            alt_screen: true,
            mouse_mode: nil,
            title: nil,
            report_focus: false,
            bracketed_paste: true,
            keyboard_enhancements: [],
            overlays: []

  @doc """
  Creates a view from an element tree with default options.

  The view defaults to alternate screen mode with bracketed paste enabled.

  ## Examples

      iex> tree = Tinct.Element.text("hello")
      iex> view = Tinct.View.new(tree)
      iex> view.content.attrs.content
      "hello"
      iex> view.alt_screen
      true
  """
  @spec new(Element.t()) :: t()
  def new(%Element{} = content) do
    %__MODULE__{content: content}
  end

  @doc """
  Creates a view from an element tree with options.

  ## Options

    * `:alt_screen` — use alternate screen buffer (default `true`)
    * `:cursor` — a `Tinct.Cursor.t()` or `nil` (default `nil`)
    * `:mouse_mode` — `nil`, `:cell_motion`, or `:all_motion` (default `nil`)
    * `:title` — window title string (default `nil`)
    * `:report_focus` — receive focus/blur events (default `false`)
    * `:bracketed_paste` — receive paste as single event (default `true`)
    * `:keyboard_enhancements` — list of enhancements to request (default `[]`)
    * `:overlays` — list of `Tinct.Overlay.t()` to render on top (default `[]`)

  ## Examples

      iex> tree = Tinct.Element.text("hello")
      iex> view = Tinct.View.new(tree, alt_screen: false, title: "My App")
      iex> {view.alt_screen, view.title}
      {false, "My App"}
  """
  @spec new(Element.t(), keyword()) :: t()
  def new(%Element{} = content, opts) when is_list(opts) do
    %__MODULE__{
      content: content,
      cursor: Keyword.get(opts, :cursor, nil),
      alt_screen: Keyword.get(opts, :alt_screen, true),
      mouse_mode: Keyword.get(opts, :mouse_mode, nil),
      title: Keyword.get(opts, :title, nil),
      report_focus: Keyword.get(opts, :report_focus, false),
      bracketed_paste: Keyword.get(opts, :bracketed_paste, true),
      keyboard_enhancements: Keyword.get(opts, :keyboard_enhancements, []),
      overlays: Keyword.get(opts, :overlays, [])
    }
  end

  @doc """
  Updates the element tree content of the view.

  ## Examples

      iex> view = Tinct.View.new(Tinct.Element.text("old"))
      iex> updated = Tinct.View.set_content(view, Tinct.Element.text("new"))
      iex> updated.content.attrs.content
      "new"
  """
  @spec set_content(t(), Element.t()) :: t()
  def set_content(%__MODULE__{} = view, %Element{} = content) do
    %{view | content: content}
  end

  @doc """
  Sets the cursor state, or `nil` to hide the cursor.

  ## Examples

      iex> view = Tinct.View.new(Tinct.Element.text("hi"))
      iex> cursor = Tinct.Cursor.new(5, 3)
      iex> updated = Tinct.View.set_cursor(view, cursor)
      iex> {updated.cursor.x, updated.cursor.y}
      {5, 3}

      iex> view = Tinct.View.new(Tinct.Element.text("hi"))
      iex> updated = Tinct.View.set_cursor(view, nil)
      iex> updated.cursor
      nil
  """
  @spec set_cursor(t(), Cursor.t() | nil) :: t()
  def set_cursor(%__MODULE__{} = view, nil) do
    %{view | cursor: nil}
  end

  def set_cursor(%__MODULE__{} = view, %Cursor{} = cursor) do
    %{view | cursor: cursor}
  end

  @doc """
  Sets the view to fullscreen mode (alternate screen buffer).

  ## Examples

      iex> view = Tinct.View.new(Tinct.Element.text("hi"), alt_screen: false)
      iex> Tinct.View.fullscreen(view).alt_screen
      true
  """
  @spec fullscreen(t()) :: t()
  def fullscreen(%__MODULE__{} = view) do
    %{view | alt_screen: true}
  end

  @doc """
  Sets the view to inline mode (renders in terminal flow, no alternate screen).

  ## Examples

      iex> view = Tinct.View.new(Tinct.Element.text("hi"))
      iex> Tinct.View.inline(view).alt_screen
      false
  """
  @spec inline(t()) :: t()
  def inline(%__MODULE__{} = view) do
    %{view | alt_screen: false}
  end

  @doc """
  Adds a centered modal overlay with backdrop dimming.

  A convenience wrapper around `Overlay.new/2` for the common case of a
  centered, dimmed modal dialog.

  ## Options

    * `:width` (required) — modal width in columns
    * `:height` (required) — modal height in rows

  ## Examples

      iex> main = Tinct.Element.text("background")
      iex> modal = Tinct.Element.text("dialog")
      iex> view = Tinct.View.with_modal(main, modal, width: 40, height: 10)
      iex> length(view.overlays)
      1
      iex> hd(view.overlays).backdrop
      :dim
  """
  @spec with_modal(Element.t(), Element.t(), keyword()) :: t()
  def with_modal(%Element{} = content, %Element{} = modal, opts) when is_list(opts) do
    overlay =
      Overlay.new(modal,
        anchor: :center,
        width: Keyword.fetch!(opts, :width),
        height: Keyword.fetch!(opts, :height),
        backdrop: :dim
      )

    new(content, overlays: [overlay])
  end
end
