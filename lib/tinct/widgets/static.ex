defmodule Tinct.Widgets.Static do
  @moduledoc """
  A log-style output widget that renders items above the live area.

  Inspired by Ink's `<Static>` component. Items are rendered once when added
  and become permanent output. Already-rendered items are never re-rendered —
  only new items trigger output.

  Useful for coding agent UIs where completed messages, tool results, and past
  conversation turns scroll up as permanent output while a live area at the
  bottom shows the current streaming response.

  ## Init Options

    * `:render_fn` — function to render each item: `(item, index) -> Element.t()`
      (default: converts strings to text elements, non-strings via `inspect/1`)
    * `:items` — initial list of items (default: `[]`)

  ## Messages

    * `{:add_item, item}` — add a single item
    * `{:add_items, items}` — add multiple items at once

  ## Rendered tracking

  The widget tracks how many items have been rendered via `rendered_count`.
  Use `new_items/1` to get unrendered items and `mark_rendered/1` to advance
  the count after processing them. This supports future "write above live area"
  integration with the App, where only new items are written to the terminal.

  ## Examples

      state = Tinct.Test.render(Tinct.Widgets.Static,
        render_fn: fn item, _idx -> Tinct.Element.text(item) end
      )
  """

  use Tinct.Component

  alias Tinct.{Element, View}

  defmodule Model do
    @moduledoc """
    State struct for the Static widget.
    """

    @type render_fn :: (term(), non_neg_integer() -> Element.t())

    @type t :: %__MODULE__{
            items: [term()],
            rendered_count: non_neg_integer(),
            render_fn: render_fn()
          }

    defstruct items: [],
              rendered_count: 0,
              render_fn: nil
  end

  # --- Component callbacks ---

  @doc "Initializes the Static widget model from the given options."
  @impl true
  @spec init(keyword()) :: Model.t()
  def init(opts) do
    %Model{
      items: Keyword.get(opts, :items, []),
      rendered_count: 0,
      render_fn: Keyword.get(opts, :render_fn, &default_render_fn/2)
    }
  end

  @doc "Handles messages to add items. Ignores unknown messages."
  @impl true
  @spec update(Model.t(), term()) :: Model.t()
  def update(%Model{} = model, {:add_item, item}) do
    add_item(model, item)
  end

  def update(%Model{} = model, {:add_items, items}) when is_list(items) do
    add_items(model, items)
  end

  def update(%Model{} = model, _msg), do: model

  @doc "Renders all items as a vertical column with the oldest items at the top."
  @impl true
  @spec view(Model.t()) :: View.t()
  def view(%Model{items: []} = _model) do
    View.new(Element.text(""))
  end

  def view(%Model{items: items, render_fn: render_fn} = _model) do
    elements =
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, index} -> render_fn.(item, index) end)

    tree =
      case elements do
        [single] -> single
        multiple -> Element.column([], multiple)
      end

    View.new(tree)
  end

  # --- Public API ---

  @doc """
  Adds a single item to the static output.

  The item is appended to the end of the items list.

  ## Examples

      iex> model = Tinct.Widgets.Static.init(render_fn: fn item, _idx -> Tinct.Element.text(item) end)
      iex> model = Tinct.Widgets.Static.add_item(model, "hello")
      iex> model.items
      ["hello"]
  """
  @spec add_item(Model.t(), term()) :: Model.t()
  def add_item(%Model{items: items} = model, item) do
    %{model | items: items ++ [item]}
  end

  @doc """
  Adds multiple items to the static output at once.

  Items are appended in order to the end of the items list.

  ## Examples

      iex> model = Tinct.Widgets.Static.init(render_fn: fn item, _idx -> Tinct.Element.text(item) end)
      iex> model = Tinct.Widgets.Static.add_items(model, ["hello", "world"])
      iex> model.items
      ["hello", "world"]
  """
  @spec add_items(Model.t(), [term()]) :: Model.t()
  def add_items(%Model{items: existing} = model, new_items) when is_list(new_items) do
    %{model | items: existing ++ new_items}
  end

  @doc """
  Returns items that have not yet been rendered.

  These are items at index >= `rendered_count`. Use `mark_rendered/1` after
  processing them to advance the rendered count.

  ## Examples

      iex> model = Tinct.Widgets.Static.init([])
      iex> model = Tinct.Widgets.Static.add_item(model, "a")
      iex> model = Tinct.Widgets.Static.add_item(model, "b")
      iex> Tinct.Widgets.Static.new_items(model)
      ["a", "b"]
  """
  @spec new_items(Model.t()) :: [term()]
  def new_items(%Model{items: items, rendered_count: rendered_count}) do
    Enum.drop(items, rendered_count)
  end

  @doc """
  Marks all current items as rendered, advancing `rendered_count` to the
  current length of the items list.

  ## Examples

      iex> model = Tinct.Widgets.Static.init([])
      iex> model = Tinct.Widgets.Static.add_item(model, "a")
      iex> model = Tinct.Widgets.Static.mark_rendered(model)
      iex> Tinct.Widgets.Static.new_items(model)
      []
  """
  @spec mark_rendered(Model.t()) :: Model.t()
  def mark_rendered(%Model{items: items} = model) do
    %{model | rendered_count: length(items)}
  end

  # --- Private helpers ---

  defp default_render_fn(item, _index) when is_binary(item) do
    Element.text(item)
  end

  defp default_render_fn(item, _index) do
    Element.text(inspect(item))
  end
end
