defmodule Tinct.FocusGroup do
  @moduledoc """
  Pane-level focus management for multi-pane layouts.

  A `FocusGroup` tracks which pane in a layout is currently focused and provides
  helpers for cycling focus, querying focus state, and consuming Tab/Shift+Tab
  keys. It is a plain data structure — no processes — consistent with Tinct's
  "components are modules, not processes" principle.

  Focus state lives in the parent component's model and is threaded through
  `update/2` like any other state.

  ## Usage

      # Initialize with pane identifiers
      focus = FocusGroup.new([:tasks, :detail, :logs])

      # Cycle focus
      focus = FocusGroup.next(focus)   # :tasks → :detail
      focus = FocusGroup.prev(focus)   # :detail → :tasks

      # Jump to a specific pane
      focus = FocusGroup.focus(focus, :logs)

      # Query for styling decisions
      FocusGroup.focused?(focus, :logs)  # true

      # Handle keyboard — consumes Tab/Shift+Tab, passes other keys through
      case FocusGroup.handle_key(focus, key_event) do
        {:consumed, new_focus} -> new_focus
        :passthrough -> # forward key to the focused pane
      end

  ## Dynamic panes

  Panes can be added or removed at any time:

      focus = FocusGroup.add_pane(focus, :search)
      focus = FocusGroup.remove_pane(focus, :detail)
  """

  alias Tinct.Event.Key

  defstruct panes: [], active: nil

  @typedoc "A pane identifier — any atom that names a pane in the layout."
  @type pane_id :: atom()

  @typedoc "Focus group state tracking which pane is active."
  @type t :: %__MODULE__{
          panes: [pane_id()],
          active: pane_id() | nil
        }

  @doc """
  Creates a new focus group with the given pane identifiers.

  The first pane in the list receives initial focus. An empty list creates a
  group with no active pane.

  ## Examples

      iex> fg = Tinct.FocusGroup.new([:tasks, :detail, :logs])
      iex> fg.active
      :tasks

      iex> fg = Tinct.FocusGroup.new([])
      iex> fg.active
      nil
  """
  @spec new([pane_id()]) :: t()
  def new([]), do: %__MODULE__{panes: [], active: nil}

  def new(panes) when is_list(panes) do
    %__MODULE__{panes: panes, active: hd(panes)}
  end

  @doc """
  Moves focus to the next pane, wrapping around at the end.

  With zero or one pane, returns the group unchanged.

  ## Examples

      iex> fg = Tinct.FocusGroup.new([:a, :b, :c])
      iex> fg = Tinct.FocusGroup.next(fg)
      iex> fg.active
      :b
      iex> fg = Tinct.FocusGroup.next(fg)
      iex> fg.active
      :c
      iex> fg = Tinct.FocusGroup.next(fg)
      iex> fg.active
      :a
  """
  @spec next(t()) :: t()
  def next(%__MODULE__{panes: panes} = fg) when length(panes) <= 1, do: fg

  def next(%__MODULE__{panes: panes, active: active} = fg) do
    index = Enum.find_index(panes, &(&1 == active))
    next_index = rem(index + 1, length(panes))
    %{fg | active: Enum.at(panes, next_index)}
  end

  @doc """
  Moves focus to the previous pane, wrapping around at the beginning.

  With zero or one pane, returns the group unchanged.

  ## Examples

      iex> fg = Tinct.FocusGroup.new([:a, :b, :c])
      iex> fg = Tinct.FocusGroup.prev(fg)
      iex> fg.active
      :c
      iex> fg = Tinct.FocusGroup.prev(fg)
      iex> fg.active
      :b
  """
  @spec prev(t()) :: t()
  def prev(%__MODULE__{panes: panes} = fg) when length(panes) <= 1, do: fg

  def prev(%__MODULE__{panes: panes, active: active} = fg) do
    index = Enum.find_index(panes, &(&1 == active))
    prev_index = rem(index - 1 + length(panes), length(panes))
    %{fg | active: Enum.at(panes, prev_index)}
  end

  @doc """
  Sets focus directly to the given pane.

  The pane must already be registered in the group. If it isn't, the group
  is returned unchanged.

  ## Examples

      iex> fg = Tinct.FocusGroup.new([:a, :b, :c])
      iex> fg = Tinct.FocusGroup.focus(fg, :c)
      iex> fg.active
      :c

      iex> fg = Tinct.FocusGroup.new([:a, :b])
      iex> fg = Tinct.FocusGroup.focus(fg, :unknown)
      iex> fg.active
      :a
  """
  @spec focus(t(), pane_id()) :: t()
  def focus(%__MODULE__{panes: panes} = fg, pane_id) do
    if pane_id in panes do
      %{fg | active: pane_id}
    else
      fg
    end
  end

  @doc """
  Returns `true` if the given pane is currently focused.

  ## Examples

      iex> fg = Tinct.FocusGroup.new([:a, :b, :c])
      iex> Tinct.FocusGroup.focused?(fg, :a)
      true
      iex> Tinct.FocusGroup.focused?(fg, :b)
      false
  """
  @spec focused?(t(), pane_id()) :: boolean()
  def focused?(%__MODULE__{active: active}, pane_id) do
    active == pane_id
  end

  @doc """
  Returns the currently focused pane identifier, or `nil` if no pane is focused.

  ## Examples

      iex> fg = Tinct.FocusGroup.new([:a, :b])
      iex> Tinct.FocusGroup.active(fg)
      :a

      iex> fg = Tinct.FocusGroup.new([])
      iex> Tinct.FocusGroup.active(fg)
      nil
  """
  @spec active(t()) :: pane_id() | nil
  def active(%__MODULE__{active: active}), do: active

  @doc """
  Handles a key event, consuming Tab and Shift+Tab for focus cycling.

  Returns `{:consumed, updated_focus_group}` if the key was Tab or Shift+Tab,
  or `:passthrough` for any other key. The parent component uses this to decide
  whether to forward the key to the focused pane.

  ## Examples

      iex> fg = Tinct.FocusGroup.new([:a, :b, :c])
      iex> tab = %Tinct.Event.Key{key: :tab, mod: [], type: :press}
      iex> {:consumed, fg} = Tinct.FocusGroup.handle_key(fg, tab)
      iex> fg.active
      :b

      iex> fg = Tinct.FocusGroup.new([:a, :b, :c])
      iex> shift_tab = %Tinct.Event.Key{key: :tab, mod: [:shift], type: :press}
      iex> {:consumed, fg} = Tinct.FocusGroup.handle_key(fg, shift_tab)
      iex> fg.active
      :c

      iex> fg = Tinct.FocusGroup.new([:a, :b])
      iex> other = %Tinct.Event.Key{key: "q", mod: [], type: :press}
      iex> Tinct.FocusGroup.handle_key(fg, other)
      :passthrough
  """
  @spec handle_key(t(), Key.t()) :: {:consumed, t()} | :passthrough
  def handle_key(%__MODULE__{} = fg, %Key{key: :tab, mod: [], type: :press}) do
    {:consumed, next(fg)}
  end

  def handle_key(%__MODULE__{} = fg, %Key{key: :tab, mod: [:shift], type: :press}) do
    {:consumed, prev(fg)}
  end

  def handle_key(%__MODULE__{}, %Key{}) do
    :passthrough
  end

  @doc """
  Adds a pane to the end of the focus group.

  If the group was empty, the new pane becomes active.

  ## Examples

      iex> fg = Tinct.FocusGroup.new([:a, :b])
      iex> fg = Tinct.FocusGroup.add_pane(fg, :c)
      iex> fg.panes
      [:a, :b, :c]
      iex> fg.active
      :a

      iex> fg = Tinct.FocusGroup.new([])
      iex> fg = Tinct.FocusGroup.add_pane(fg, :first)
      iex> fg.active
      :first
  """
  @spec add_pane(t(), pane_id()) :: t()
  def add_pane(%__MODULE__{panes: [], active: nil}, pane_id) do
    %__MODULE__{panes: [pane_id], active: pane_id}
  end

  def add_pane(%__MODULE__{panes: panes} = fg, pane_id) do
    %{fg | panes: panes ++ [pane_id]}
  end

  @doc """
  Removes a pane from the focus group.

  If the removed pane was active, focus moves to the next pane (or the first
  pane if the removed pane was last). If the group becomes empty, active is `nil`.

  ## Examples

      iex> fg = Tinct.FocusGroup.new([:a, :b, :c])
      iex> fg = Tinct.FocusGroup.remove_pane(fg, :b)
      iex> fg.panes
      [:a, :c]
      iex> fg.active
      :a

      iex> fg = Tinct.FocusGroup.new([:a, :b, :c])
      iex> fg = Tinct.FocusGroup.focus(fg, :b)
      iex> fg = Tinct.FocusGroup.remove_pane(fg, :b)
      iex> fg.active
      :c

      iex> fg = Tinct.FocusGroup.new([:only])
      iex> fg = Tinct.FocusGroup.remove_pane(fg, :only)
      iex> fg.active
      nil
  """
  @spec remove_pane(t(), pane_id()) :: t()
  def remove_pane(%__MODULE__{panes: panes, active: active} = fg, pane_id) do
    new_panes = List.delete(panes, pane_id)

    new_active =
      cond do
        new_panes == [] ->
          nil

        active != pane_id ->
          active

        true ->
          # Removed the active pane — pick the next one in the original order
          old_index = Enum.find_index(panes, &(&1 == pane_id))
          # If it was the last pane, wrap to the first of the remaining panes
          Enum.at(new_panes, min(old_index, length(new_panes) - 1))
      end

    %{fg | panes: new_panes, active: new_active}
  end

  @doc """
  Returns the list of registered pane identifiers.

  ## Examples

      iex> fg = Tinct.FocusGroup.new([:a, :b, :c])
      iex> Tinct.FocusGroup.panes(fg)
      [:a, :b, :c]
  """
  @spec panes(t()) :: [pane_id()]
  def panes(%__MODULE__{panes: panes}), do: panes
end
