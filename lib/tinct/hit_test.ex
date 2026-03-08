defmodule Tinct.HitTest do
  @moduledoc """
  Mouse hit testing — maps click coordinates to tagged elements.

  A `HitTest` is a lightweight registry of tagged rectangles built during
  layout/view and consumed during update to resolve which element the user
  clicked. It's a plain data structure — no processes — and resolves hits via
  a simple linear scan.

  Nested regions are supported: when multiple rects contain the click point,
  the last-registered (deepest/most-specific) match wins. Register outer
  containers first, then inner children.

  ## Usage

      # Build a hit map during view
      hit_map =
        HitTest.new()
        |> HitTest.register(:task_list, {0, 0, 30, 20})
        |> HitTest.register({:task, 1}, {1, 1, 28, 3})
        |> HitTest.register({:task, 2}, {1, 4, 28, 3})

      # Resolve a click in update
      case HitTest.resolve(hit_map, mouse_x, mouse_y) do
        {:task, id} -> select_task(model, id)
        :task_list  -> focus_pane(model, :tasks)
        nil         -> model
      end

      # Or integrate with FocusGroup for click-to-focus
      case HitTest.handle_click(hit_map, mouse_event, focus_group) do
        {:hit, tag, updated_fg} -> handle_tag(model, tag, updated_fg)
        {:miss, focus_group}    -> model
      end
  """

  alias Tinct.Event.Mouse
  alias Tinct.FocusGroup

  @typedoc """
  A rectangle as `{x, y, width, height}`.

  Coordinates are zero-indexed with `{0, 0}` at the top-left. A point is
  inside a rect when `x <= px < x + width` and `y <= py < y + height`.
  """
  @type rect :: {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}

  @typedoc "An arbitrary tag identifying an element — atom, tuple, string, etc."
  @type tag :: term()

  @typedoc "Hit test map — an ordered list of tagged rectangles."
  @type t :: %__MODULE__{
          entries: [{tag(), rect()}]
        }

  defstruct entries: []

  @doc """
  Creates an empty hit test map.

  ## Examples

      iex> Tinct.HitTest.new()
      %Tinct.HitTest{entries: []}
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Registers a tagged rectangle in the hit map.

  Later registrations take priority over earlier ones when regions overlap,
  so register parent containers before their children. The rect is a
  `{x, y, width, height}` tuple.

  ## Examples

      iex> hm = Tinct.HitTest.new()
      iex> hm = Tinct.HitTest.register(hm, :sidebar, {0, 0, 20, 40})
      iex> length(hm.entries)
      1
  """
  @spec register(t(), tag(), rect()) :: t()
  def register(%__MODULE__{entries: entries} = hit_map, tag, {x, y, w, h} = rect)
      when is_integer(x) and is_integer(y) and is_integer(w) and is_integer(h) and
             x >= 0 and y >= 0 and w >= 0 and h >= 0 do
    %{hit_map | entries: entries ++ [{tag, rect}]}
  end

  @doc """
  Resolves a click at `(mouse_x, mouse_y)` to the deepest matching tag.

  Scans all registered rects and returns the tag of the last (deepest) rect
  that contains the point. Returns `nil` if no rect matches.

  A point is inside a rect `{x, y, w, h}` when:
  - `mouse_x >= x` and `mouse_x < x + w`
  - `mouse_y >= y` and `mouse_y < y + h`

  ## Examples

      iex> hm = Tinct.HitTest.new() |> Tinct.HitTest.register(:panel, {0, 0, 10, 10})
      iex> Tinct.HitTest.resolve(hm, 5, 5)
      :panel

      iex> hm = Tinct.HitTest.new() |> Tinct.HitTest.register(:panel, {0, 0, 10, 10})
      iex> Tinct.HitTest.resolve(hm, 15, 15)
      nil
  """
  @spec resolve(t(), non_neg_integer(), non_neg_integer()) :: tag() | nil
  def resolve(%__MODULE__{entries: entries}, mouse_x, mouse_y)
      when is_integer(mouse_x) and is_integer(mouse_y) do
    entries
    |> Enum.filter(fn {_tag, {x, y, w, h}} ->
      mouse_x >= x and mouse_x < x + w and mouse_y >= y and mouse_y < y + h
    end)
    |> List.last()
    |> case do
      nil -> nil
      {tag, _rect} -> tag
    end
  end

  @doc """
  Resolves a mouse event against the hit map and updates a `FocusGroup`.

  Combines `resolve/3` with `FocusGroup.focus/2` for click-to-focus workflows.
  Returns `{:hit, tag, updated_focus_group}` when a rect matches, or
  `{:miss, focus_group}` when the click lands on empty space.

  When the resolved tag matches a registered pane in the focus group, focus
  moves to that pane. When it doesn't (e.g., a `{:task, id}` tuple),
  the focus group is returned unchanged.

  ## Examples

      iex> hm = Tinct.HitTest.new() |> Tinct.HitTest.register(:sidebar, {0, 0, 20, 40})
      iex> fg = Tinct.FocusGroup.new([:sidebar, :main])
      iex> mouse = %Tinct.Event.Mouse{type: :click, button: :left, x: 5, y: 5}
      iex> {:hit, :sidebar, updated_fg} = Tinct.HitTest.handle_click(hm, mouse, fg)
      iex> updated_fg.active
      :sidebar
  """
  @spec handle_click(t(), Mouse.t(), FocusGroup.t()) ::
          {:hit, tag(), FocusGroup.t()} | {:miss, FocusGroup.t()}
  def handle_click(%__MODULE__{} = hit_map, %Mouse{x: mx, y: my}, %FocusGroup{} = fg) do
    case resolve(hit_map, mx, my) do
      nil -> {:miss, fg}
      tag -> {:hit, tag, FocusGroup.focus(fg, tag)}
    end
  end

  @doc """
  Returns the number of registered rectangles.

  ## Examples

      iex> Tinct.HitTest.new() |> Tinct.HitTest.size()
      0
  """
  @spec size(t()) :: non_neg_integer()
  def size(%__MODULE__{entries: entries}), do: length(entries)

  @doc """
  Clears all registered rectangles, returning an empty hit map.

  Useful at the start of each view pass to rebuild the map from scratch.

  ## Examples

      iex> hm = Tinct.HitTest.new() |> Tinct.HitTest.register(:a, {0, 0, 10, 10})
      iex> Tinct.HitTest.clear(hm)
      %Tinct.HitTest{entries: []}
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{}), do: %__MODULE__{}
end
