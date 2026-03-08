defmodule Tinct.Examples.Chat do
  @moduledoc """
  A fake coding agent chat UI to exercise Tinct's core features.

  Demonstrates: Static (history), TextInput, Border, Spinner-like streaming,
  layout (column/row), commands (async), and keyboard handling.

  Run with:

      mix run examples/chat.ex
  """

  use Tinct.Component

  alias Tinct.{Command, Element, Event, View}
  alias Tinct.Widgets.TextInput

  # -- Model ------------------------------------------------------------------

  defmodule Model do
    @moduledoc false
    defstruct messages: [],
              input: nil,
              streaming: false,
              stream_buffer: ""
  end

  @fake_responses [
    "I'll help you with that! Let me look at the code...\n\nThe issue is in `lib/app.ex` on line 42. You're calling `String.to_atom/1` on user input, which is a security risk. Replace it with `String.to_existing_atom/1` or use a map lookup instead.",
    "Sure! Here's a simple GenServer for that:\n\n```elixir\ndefmodule MyCache do\n  use GenServer\n\n  def start_link(opts), do: GenServer.start_link(__MODULE__, %{}, opts)\n  def get(pid, key), do: GenServer.call(pid, {:get, key})\n  def put(pid, key, val), do: GenServer.cast(pid, {:put, key, val})\nend\n```\n\nThis gives you a basic key-value cache with sync reads and async writes.",
    "Looking at your test failures... The problem is that `ExUnit.Case` defaults to `async: false`. Your tests are sharing database state. Add `async: true` to each test module, or use `Ecto.Adapters.SQL.Sandbox` for isolation.",
    "That's a great question. In Elixir, processes are cheap — about 2KB each. So yes, spawning 10,000 processes is totally fine. The BEAM scheduler will handle it. Use `Task.async_stream/3` for concurrent work with backpressure.",
    "I don't know the answer to that off the top of my head. Let me check the docs... Actually, I think you'd want `Enum.chunk_every/4` with the `:discard` option for that use case."
  ]

  # -- Component callbacks ----------------------------------------------------

  @impl true
  def init(_opts) do
    input = TextInput.init(placeholder: "Ask me anything...", focused: true)
    %Model{input: input}
  end

  @impl true
  def update(%Model{} = model, %Event.Key{key: "c", mod: [:ctrl]}) do
    {model, Command.quit()}
  end

  def update(%Model{streaming: true} = model, %Event.Key{}) do
    # Ignore keyboard input while streaming
    model
  end

  def update(%Model{} = model, %Event.Key{key: :enter}) do
    value = model.input.value

    if String.trim(value) == "" do
      model
    else
      messages = model.messages ++ [{:user, value}]
      input = TextInput.clear(model.input)
      model = %{model | messages: messages, input: input, streaming: true, stream_buffer: ""}

      response = Enum.random(@fake_responses)

      cmd =
        Command.async(fn ->
          # Simulate streaming: yield chunks with delays
          stream_response(response)
        end, :stream_result)

      {model, cmd}
    end
  end

  def update(%Model{} = model, %Event.Key{} = key) do
    new_input = TextInput.update(model.input, key)
    new_input = normalize_input(new_input)
    %{model | input: new_input}
  end

  def update(%Model{} = model, %Event.Paste{} = paste) do
    new_input = TextInput.update(model.input, paste)
    new_input = normalize_input(new_input)
    %{model | input: new_input}
  end

  def update(%Model{} = model, {:stream_result, response}) when is_binary(response) do
    messages = model.messages ++ [{:assistant, response}]
    %{model | messages: messages, streaming: false, stream_buffer: ""}
  end

  def update(%Model{} = model, _msg), do: model

  # -- View -------------------------------------------------------------------

  @impl true
  def view(%Model{} = model) do
    import Tinct.UI

    content =
      column do
        # Header
        box border: :round, flex_grow: 0 do
          text " Tinct Chat — ctrl+c to quit ", color: :cyan, bold: true
        end

        # Message history
        box flex_grow: 1 do
          render_messages(model)
        end

        # Streaming area
        render_stream(model)

        # Input area
        box border: :single, flex_grow: 0 do
          render_input(model)
        end
      end

    View.new(content)
  end

  # -- Render helpers ---------------------------------------------------------

  defp render_messages(%Model{messages: []}) do
    import Tinct.UI
    text("No messages yet. Type something and press Enter!", color: :bright_black)
  end

  defp render_messages(%Model{messages: messages}) do
    elements =
      Enum.flat_map(messages, fn
        {:user, content} ->
          [
            Element.text("You", fg: :green, bold: true),
            Element.text("  " <> content),
            Element.text("")
          ]

        {:assistant, content} ->
          [
            Element.text("Agent", fg: :cyan, bold: true),
            Element.text("  " <> content),
            Element.text("")
          ]
      end)

    Element.column([], elements)
  end

  defp render_stream(%Model{streaming: false}), do: Element.text("")

  defp render_stream(%Model{streaming: true, stream_buffer: buffer}) do
    import Tinct.UI

    column do
      text("Agent", fg: :cyan, bold: true)
      text("  " <> buffer <> "▌", color: :bright_black)
    end
  end

  defp render_input(%Model{input: input}) do
    # Render the text input's view content directly
    view = Tinct.Widgets.TextInput.view(input)
    view.content
  end

  # -- Async streaming simulation ---------------------------------------------

  defp stream_response(full_text) do
    # Simulate a slow response by sleeping, then return the whole thing.
    # True streaming would use a separate process sending chunks.
    # For this demo, just add a delay to feel "real".
    Process.sleep(Enum.random(500..1500))
    full_text
  end

  # -- Helpers ----------------------------------------------------------------

  defp normalize_input({%TextInput.Model{} = model, _cmd}), do: model
  defp normalize_input(%TextInput.Model{} = model), do: model
end

# --- Entry point ---
Tinct.run(Tinct.Examples.Chat)
