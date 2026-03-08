defmodule Tinct.Test do
  @moduledoc """
  Headless testing helpers for Tinct components.

  Renders components to in-memory buffers, simulates events, and provides
  assertion helpers — all without a real terminal.

  ## Usage

      defmodule MyComponentTest do
        use ExUnit.Case

        test "renders and responds to events" do
          state = Tinct.Test.render(MyComponent, [])
          assert Tinct.Test.contains?(state, "expected text")

          state = Tinct.Test.send_key(state, :enter)
          assert Tinct.Test.contains?(state, "after enter")
        end
      end
  """

  alias Tinct.{Buffer, Component, Event, Layout, Overlay, Theme, View}
  alias Tinct.Buffer.Cell

  defmodule State do
    @moduledoc """
    Opaque state returned by `Tinct.Test` render and event simulation functions.

    Wraps the component module, current model, rendered view, buffer, terminal
    size, and active theme.
    """

    @type t :: %__MODULE__{
            component: module(),
            model: term(),
            view: View.t(),
            buffer: Buffer.t(),
            size: {non_neg_integer(), non_neg_integer()},
            theme: Theme.t()
          }

    defstruct [:component, :model, :view, :buffer, :size, :theme]
  end

  @default_size {80, 24}

  # --- Rendering ---

  @doc """
  Renders a component to a headless buffer.

  Initializes the component with the given options, calls `view/1`, and renders
  the element tree to a buffer. Returns a `Tinct.Test.State` for use with other
  test helpers.

  Uses a default terminal size of 80×24.

  ## Examples

      state = Tinct.Test.render(Counter, start: 5)
      assert Tinct.Test.contains?(state, "Count: 5")
  """
  @spec render(module(), keyword()) :: State.t()
  def render(component, init_opts) when is_atom(component) and is_list(init_opts) do
    render(component, init_opts, [])
  end

  @doc """
  Renders a component to a headless buffer with options.

  ## Options

    * `:size` — `{cols, rows}` tuple (default: `{80, 24}`)
    * `:theme` — a `Tinct.Theme.t()` (default: `Theme.default()`)

  ## Examples

      state = Tinct.Test.render(Counter, [], size: {40, 10})
  """
  @spec render(module(), keyword(), keyword()) :: State.t()
  def render(component, init_opts, opts)
      when is_atom(component) and is_list(init_opts) and is_list(opts) do
    size = Keyword.get(opts, :size, @default_size)
    theme = Keyword.get(opts, :theme, Theme.default())
    model = component.init(init_opts)
    build_state(component, model, size, theme)
  end

  @doc """
  Renders a `Tinct.View` struct directly to a text string.

  Useful when you already have a view and want to see the text output without
  going through a full component lifecycle.

  ## Examples

      view = Tinct.View.new(Tinct.Element.text("hello"))
      text = Tinct.Test.render_view(view, {80, 24})
      assert text =~ "hello"
  """
  @spec render_view(View.t(), {non_neg_integer(), non_neg_integer()}) :: String.t()
  def render_view(%View{} = view, {_cols, _rows} = size) do
    view
    |> render_view_to_buffer(size, Theme.default())
    |> buffer_to_text()
  end

  # --- Event simulation ---

  @doc """
  Sends an event to the component and re-renders.

  Calls the component's `update/2` with the event, then re-renders with the
  new model. Returns the updated state. Commands returned by `update/2` are
  discarded — use `send_event_raw/2` to inspect them.

  ## Examples

      state = Tinct.Test.send_event(state, Tinct.Event.key(:enter))
  """
  @spec send_event(State.t(), term()) :: State.t()
  def send_event(%State{} = state, event) do
    {new_state, _cmd} = send_event_raw(state, event)
    new_state
  end

  @doc """
  Sends an event to the component and returns both the new state and the command.

  Like `send_event/2`, but also returns the command from `update/2` so you can
  assert on side effects like `:quit`.

  ## Examples

      {state, cmd} = Tinct.Test.send_event_raw(state, Tinct.Event.key("q"))
      assert cmd == :quit
  """
  @spec send_event_raw(State.t(), term()) :: {State.t(), Tinct.Command.t()}
  def send_event_raw(%State{component: component, model: model} = state, event) do
    {new_model, cmd} = Component.normalize_update_result(component.update(model, event))
    new_state = build_state(component, new_model, state.size, state.theme)
    {new_state, cmd}
  end

  @doc """
  Sends a key press event to the component and re-renders.

  Accepts a string for printable characters or an atom for special keys.

  ## Examples

      state = Tinct.Test.send_key(state, "q")
      state = Tinct.Test.send_key(state, :enter)
  """
  @spec send_key(State.t(), atom() | String.t()) :: State.t()
  def send_key(%State{} = state, key) do
    send_event(state, Event.key(key))
  end

  @doc """
  Sends a key press event with modifiers to the component and re-renders.

  ## Examples

      state = Tinct.Test.send_key(state, "c", [:ctrl])
  """
  @spec send_key(State.t(), atom() | String.t(), [atom()]) :: State.t()
  def send_key(%State{} = state, key, modifiers) when is_list(modifiers) do
    send_event(state, Event.key(key, modifiers))
  end

  @doc """
  Sends a key press event and returns both the new state and command.

  Like `send_key/2`, but also returns the command from `update/2`.

  ## Examples

      {state, cmd} = Tinct.Test.send_key_raw(state, "q")
      assert cmd == :quit
  """
  @spec send_key_raw(State.t(), atom() | String.t()) :: {State.t(), Tinct.Command.t()}
  def send_key_raw(%State{} = state, key) do
    send_event_raw(state, Event.key(key))
  end

  @doc """
  Sends a key press event with modifiers and returns both the new state and command.

  ## Examples

      {state, cmd} = Tinct.Test.send_key_raw(state, "c", [:ctrl])
  """
  @spec send_key_raw(State.t(), atom() | String.t(), [atom()]) :: {State.t(), Tinct.Command.t()}
  def send_key_raw(%State{} = state, key, modifiers) when is_list(modifiers) do
    send_event_raw(state, Event.key(key, modifiers))
  end

  # --- Assertions ---

  @doc """
  Returns `true` if the rendered output contains the given string.

  ## Examples

      state = Tinct.Test.render(Counter, [])
      assert Tinct.Test.contains?(state, "Count: 0")
  """
  @spec contains?(State.t(), String.t()) :: boolean()
  def contains?(%State{buffer: buffer}, text) when is_binary(text) do
    buffer
    |> buffer_to_text()
    |> String.contains?(text)
  end

  @doc """
  Returns the text content of a specific line (0-indexed) from the rendered output.

  Trailing whitespace is trimmed from the line. Returns `nil` if the line
  number is out of bounds.

  ## Examples

      state = Tinct.Test.render(Counter, [])
      Tinct.Test.line(state, 0)
  """
  @spec line(State.t(), non_neg_integer()) :: String.t() | nil
  def line(%State{buffer: buffer}, row) when is_integer(row) and row >= 0 do
    if row < buffer.height do
      extract_row_text(buffer, row)
    end
  end

  @doc """
  Returns the `Tinct.Buffer.Cell` at the given column and row.

  Useful for asserting on styles, colors, and individual characters.

  ## Examples

      cell = Tinct.Test.cell_at(state, 0, 0)
      assert cell.char == "C"
  """
  @spec cell_at(State.t(), non_neg_integer(), non_neg_integer()) :: Cell.t()
  def cell_at(%State{buffer: buffer}, col, row) do
    Buffer.get(buffer, col, row)
  end

  @doc """
  Asserts that the rendered output contains the given string.

  Raises an `ExUnit.AssertionError` with a helpful message showing the full
  rendered output if the text is not found.

  ## Examples

      Tinct.Test.assert_contains(state, "Count: 0")
  """
  @spec assert_contains(State.t(), String.t()) :: :ok
  def assert_contains(%State{} = state, text) when is_binary(text) do
    if contains?(state, text) do
      :ok
    else
      rendered = to_text(state)

      raise_assertion_error("""
      Expected rendered output to contain:

        #{inspect(text)}

      Rendered output:

      #{rendered}
      """)
    end
  end

  # --- Buffer access ---

  @doc """
  Converts the rendered state to a plain text string.

  Strips styles, joins rows with newlines, and trims trailing whitespace
  from each line.

  ## Examples

      text = Tinct.Test.to_text(state)
      assert text =~ "Count: 0"
  """
  @spec to_text(State.t()) :: String.t()
  def to_text(%State{buffer: buffer}) do
    buffer_to_text(buffer)
  end

  @doc """
  Returns the raw buffer from the render state.

  Use this for cell-level assertions when `to_text/1` isn't granular enough.

  ## Examples

      buffer = Tinct.Test.to_buffer(state)
      cell = Tinct.Buffer.get(buffer, 0, 0)
  """
  @spec to_buffer(State.t()) :: Buffer.t()
  def to_buffer(%State{buffer: buffer}) do
    buffer
  end

  # --- Private helpers ---

  defp build_state(component, model, size, theme) do
    view = component.view(model)
    buffer = render_view_to_buffer(view, size, theme)

    %State{
      component: component,
      model: model,
      view: view,
      buffer: buffer,
      size: size,
      theme: theme
    }
  end

  defp render_view_to_buffer(%View{content: nil, overlays: overlays}, {cols, rows}, theme) do
    Buffer.new(cols, rows)
    |> Overlay.render_overlays(overlays, theme)
  end

  defp render_view_to_buffer(%View{content: content, overlays: overlays}, {cols, rows}, theme) do
    Layout.render(content, {cols, rows}, theme)
    |> Overlay.render_overlays(overlays, theme)
  end

  @spec raise_assertion_error(String.t()) :: no_return()
  defp raise_assertion_error(message) when is_binary(message) do
    raise %ExUnit.AssertionError{message: message}
  end

  defp buffer_to_text(%Buffer{} = buffer) do
    0..(buffer.height - 1)//1
    |> Enum.map_join("\n", fn row -> extract_row_text(buffer, row) end)
    |> String.trim_trailing("\n")
  end

  defp extract_row_text(%Buffer{} = buffer, row) do
    0..(buffer.width - 1)//1
    |> Enum.map_join("", fn col -> Buffer.get(buffer, col, row).char end)
    |> String.trim_trailing()
  end
end
