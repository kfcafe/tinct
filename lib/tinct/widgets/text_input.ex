defmodule Tinct.Widgets.TextInput do
  @moduledoc """
  A single-line text input widget with cursor.

  Implements the `Tinct.Component` behaviour for use as a standalone terminal
  text input. Handles printable character insertion, cursor movement,
  backspace/delete, and submit/change callbacks.

  ## Init Options

    * `:value` — initial text value (default `""`)
    * `:placeholder` — placeholder text shown when empty (default `""`)
    * `:focused` — whether the input starts focused (default `false`)
    * `:on_change` — atom tag emitted as `{tag, value}` when text changes (default `nil`)
    * `:on_submit` — atom tag emitted as `{tag, value}` on Enter (default `nil`)
    * `:style` — a `Tinct.Style.t()` for the input (default `Style.new()`)
    * `:cursor_pos` — initial cursor position (default: end of value)

  ## Key Bindings

    * Printable character — insert at cursor, advance cursor
    * Backspace — delete character before cursor
    * Delete — delete character at cursor
    * Left / Right — move cursor
    * Home / Ctrl+A — cursor to start
    * End / Ctrl+E — cursor to end
    * Enter — emit `{on_submit, value}` if configured

  ## Examples

      state = Tinct.Test.render(Tinct.Widgets.TextInput, placeholder: "Type here...")
      state = Tinct.Test.send_key(state, "h")
      state.model.value
      #=> "h"
  """

  use Tinct.Component

  alias Tinct.{Cursor, Element, Event, Style, View}

  defmodule Model do
    @moduledoc """
    State struct for the TextInput widget.
    """

    @type t :: %__MODULE__{
            value: String.t(),
            cursor_pos: non_neg_integer(),
            placeholder: String.t(),
            style: Style.t(),
            focused: boolean(),
            on_change: atom() | nil,
            on_submit: atom() | nil
          }

    defstruct value: "",
              cursor_pos: 0,
              placeholder: "",
              style: %Style{},
              focused: false,
              on_change: nil,
              on_submit: nil
  end

  # --- Component callbacks ---

  @impl Tinct.Component
  def init(opts) do
    value = Keyword.get(opts, :value, "")

    %Model{
      value: value,
      cursor_pos: Keyword.get(opts, :cursor_pos, String.length(value)),
      placeholder: Keyword.get(opts, :placeholder, ""),
      style: Keyword.get(opts, :style, Style.new()),
      focused: Keyword.get(opts, :focused, false),
      on_change: Keyword.get(opts, :on_change, nil),
      on_submit: Keyword.get(opts, :on_submit, nil)
    }
  end

  @impl Tinct.Component
  def update(%Model{} = model, %Event.Key{type: :press} = key) do
    handle_key(model, key)
  end

  def update(%Model{} = model, %Event.Paste{content: content}) do
    insert_text(model, content)
  end

  def update(%Model{} = model, _msg), do: model

  @impl Tinct.Component
  def view(%Model{} = model) do
    content = render_content(model)

    if model.focused do
      cursor = Cursor.new(model.cursor_pos, 0, shape: :bar)
      View.new(content, cursor: cursor)
    else
      View.new(content)
    end
  end

  # --- Public API ---

  @doc """
  Programmatically sets the input value and moves cursor to the end.

  ## Examples

      iex> model = Tinct.Widgets.TextInput.init([])
      iex> model = Tinct.Widgets.TextInput.set_value(model, "hello")
      iex> {model.value, model.cursor_pos}
      {"hello", 5}
  """
  @spec set_value(Model.t(), String.t()) :: Model.t()
  def set_value(%Model{} = model, value) when is_binary(value) do
    %{model | value: value, cursor_pos: String.length(value)}
  end

  @doc """
  Clears the input value and resets cursor to position 0.

  ## Examples

      iex> model = Tinct.Widgets.TextInput.init(value: "hello")
      iex> model = Tinct.Widgets.TextInput.clear(model)
      iex> {model.value, model.cursor_pos}
      {"", 0}
  """
  @spec clear(Model.t()) :: Model.t()
  def clear(%Model{} = model) do
    %{model | value: "", cursor_pos: 0}
  end

  @doc """
  Inserts text at the current cursor position.

  Strips newlines (single-line input). Useful for handling paste events.

  ## Examples

      iex> model = Tinct.Widgets.TextInput.init(value: "ab")
      iex> model = Tinct.Widgets.TextInput.insert_text(model, "XY")
      iex> {model.value, model.cursor_pos}
      {"abXY", 4}
  """
  @spec insert_text(Model.t(), String.t()) :: Model.t()
  def insert_text(%Model{} = model, text) when is_binary(text) do
    # Strip newlines — this is a single-line input
    clean = text |> String.replace(~r/[\r\n]/, " ") |> String.trim()
    {before, after_cursor} = String.split_at(model.value, model.cursor_pos)
    new_value = before <> clean <> after_cursor
    new_model = %{model | value: new_value, cursor_pos: model.cursor_pos + String.length(clean)}
    maybe_emit_change(new_model, model)
  end

  @doc """
  Sets the input to focused state, enabling cursor display.

  ## Examples

      iex> model = Tinct.Widgets.TextInput.init([])
      iex> model = Tinct.Widgets.TextInput.focus(model)
      iex> model.focused
      true
  """
  @spec focus(Model.t()) :: Model.t()
  def focus(%Model{} = model) do
    %{model | focused: true}
  end

  @doc """
  Sets the input to unfocused state, hiding the cursor.

  ## Examples

      iex> model = Tinct.Widgets.TextInput.init(focused: true)
      iex> model = Tinct.Widgets.TextInput.blur(model)
      iex> model.focused
      false
  """
  @spec blur(Model.t()) :: Model.t()
  def blur(%Model{} = model) do
    %{model | focused: false}
  end

  # --- Rendering ---

  defp render_content(%Model{value: "", placeholder: placeholder, style: style})
       when byte_size(placeholder) > 0 do
    placeholder_style = Style.merge(style, Style.new(dim: true, italic: true))
    el = Element.text(placeholder)
    %{el | style: placeholder_style}
  end

  defp render_content(%Model{value: value, style: style}) do
    el = Element.text(value)
    %{el | style: style}
  end

  # --- Key handling ---

  # Ctrl+A — cursor to start
  defp handle_key(model, %Event.Key{key: "a", mod: [:ctrl]}) do
    %{model | cursor_pos: 0}
  end

  # Ctrl+E — cursor to end
  defp handle_key(model, %Event.Key{key: "e", mod: [:ctrl]}) do
    %{model | cursor_pos: String.length(model.value)}
  end

  # Printable character — insert at cursor position
  defp handle_key(model, %Event.Key{key: key, mod: []}) when is_binary(key) do
    {before, after_cursor} = String.split_at(model.value, model.cursor_pos)
    new_value = before <> key <> after_cursor
    new_model = %{model | value: new_value, cursor_pos: model.cursor_pos + String.length(key)}
    maybe_emit_change(new_model, model)
  end

  # Backspace — delete character before cursor
  defp handle_key(model, %Event.Key{key: :backspace}) do
    if model.cursor_pos > 0 do
      {before, after_cursor} = String.split_at(model.value, model.cursor_pos)
      new_before = String.slice(before, 0, String.length(before) - 1)
      new_value = new_before <> after_cursor
      new_model = %{model | value: new_value, cursor_pos: model.cursor_pos - 1}
      maybe_emit_change(new_model, model)
    else
      model
    end
  end

  # Delete — delete character at cursor
  defp handle_key(model, %Event.Key{key: :delete}) do
    if model.cursor_pos < String.length(model.value) do
      {before, after_cursor} = String.split_at(model.value, model.cursor_pos)
      new_after = String.slice(after_cursor, 1, String.length(after_cursor))
      new_value = before <> new_after
      new_model = %{model | value: new_value}
      maybe_emit_change(new_model, model)
    else
      model
    end
  end

  # Left arrow — move cursor left
  defp handle_key(model, %Event.Key{key: :left}) do
    %{model | cursor_pos: max(0, model.cursor_pos - 1)}
  end

  # Right arrow — move cursor right
  defp handle_key(model, %Event.Key{key: :right}) do
    %{model | cursor_pos: min(String.length(model.value), model.cursor_pos + 1)}
  end

  # Home — cursor to start
  defp handle_key(model, %Event.Key{key: :home}) do
    %{model | cursor_pos: 0}
  end

  # End — cursor to end
  defp handle_key(model, %Event.Key{key: :end}) do
    %{model | cursor_pos: String.length(model.value)}
  end

  # Enter — emit on_submit
  defp handle_key(model, %Event.Key{key: :enter}) do
    if model.on_submit do
      {model, {model.on_submit, model.value}}
    else
      model
    end
  end

  # Unknown keys — pass through unchanged
  defp handle_key(model, _key), do: model

  defp maybe_emit_change(new_model, old_model) do
    if new_model.on_change && new_model.value != old_model.value do
      {new_model, {new_model.on_change, new_model.value}}
    else
      new_model
    end
  end
end
