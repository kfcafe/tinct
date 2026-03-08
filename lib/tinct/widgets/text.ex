defmodule Tinct.Widgets.Text do
  @moduledoc """
  A component for displaying styled text in the terminal.

  Supports plain text, multi-line text (with `\\n`), word wrapping, truncation
  with ellipsis, and text alignment.

  ## Wrapping modes

    * `:wrap` — wraps at word boundaries, overflowing to the next line (default)
    * `:truncate` / `:truncate_end` — truncates with "…" at the end
    * `:truncate_start` — truncates with "…" at the start
    * `:truncate_middle` — truncates with "…" in the middle

  ## Alignment

    * `:left` — left-aligned, no padding (default)
    * `:center` — centered with leading spaces
    * `:right` — right-aligned with leading spaces

  ## Component usage

      state = Tinct.Test.render(Tinct.Widgets.Text, content: "Hello, world!")

  ## Pure function usage

      lines = Tinct.Widgets.Text.render_text("Hello, world!", 10, wrap: :wrap)
  """

  use Tinct.Component

  alias Tinct.{Element, Style, View}

  @typedoc "Wrapping mode for text that exceeds the available width."
  @type wrap_mode :: :wrap | :truncate | :truncate_end | :truncate_start | :truncate_middle

  @typedoc "Horizontal text alignment."
  @type align_mode :: :left | :center | :right

  @typedoc "The Text widget model."
  @type model :: %{
          content: String.t(),
          style: Style.t(),
          wrap: wrap_mode(),
          align: align_mode()
        }

  @ellipsis "…"

  # --- Component callbacks ---

  @doc "Initializes the Text widget model from the given options."
  @impl true
  @spec init(keyword()) :: model()
  def init(opts) do
    %{
      content: Keyword.get(opts, :content, ""),
      style: Keyword.get(opts, :style, %Style{}),
      wrap: Keyword.get(opts, :wrap, :wrap),
      align: Keyword.get(opts, :align, :left)
    }
  end

  @doc "Handles messages. Supports `{:set_content, content}` to update the text."
  @impl true
  @spec update(model(), term()) :: model()
  def update(model, {:set_content, content}) when is_binary(content) do
    %{model | content: content}
  end

  def update(model, _msg), do: model

  @doc "Renders the text model as an element tree wrapped in a `Tinct.View`."
  @impl true
  @spec view(model()) :: View.t()
  def view(model) do
    lines = String.split(model.content, "\n")

    elements =
      Enum.map(lines, fn line ->
        %Element{type: :text, style: model.style, children: [], attrs: %{content: line}}
      end)

    tree =
      case elements do
        [] -> Element.text("")
        [single] -> single
        multiple -> Element.column([], multiple)
      end

    View.new(tree)
  end

  # --- Public helper ---

  @doc """
  Renders text content to a list of lines for the given width.

  A pure function useful for other widgets that need text rendering without
  going through the full component lifecycle.

  ## Options

    * `:wrap` — wrapping mode (default: `:wrap`)
    * `:align` — alignment (default: `:left`)

  ## Examples

      iex> Tinct.Widgets.Text.render_text("hello world", 8)
      ["hello", "world"]

      iex> Tinct.Widgets.Text.render_text("hello world", 5, wrap: :truncate)
      ["hell…"]

      iex> Tinct.Widgets.Text.render_text("hi", 10, align: :right)
      ["        hi"]
  """
  @spec render_text(String.t(), non_neg_integer(), keyword()) :: [String.t()]
  def render_text(content, width, opts \\ [])

  def render_text(_content, 0, _opts), do: []

  def render_text(content, width, opts) when is_binary(content) and width > 0 do
    wrap = Keyword.get(opts, :wrap, :wrap)
    align = Keyword.get(opts, :align, :left)

    content
    |> String.split("\n")
    |> Enum.flat_map(&format_line(&1, width, wrap))
    |> Enum.map(&align_line(&1, width, align))
  end

  # --- Private helpers ---

  defp format_line(line, width, :wrap), do: wrap_line(line, width)
  defp format_line(line, width, :truncate), do: [truncate_end(line, width)]
  defp format_line(line, width, :truncate_end), do: [truncate_end(line, width)]
  defp format_line(line, width, :truncate_start), do: [truncate_start(line, width)]
  defp format_line(line, width, :truncate_middle), do: [truncate_middle(line, width)]

  # --- Word wrapping ---

  defp wrap_line(line, width) do
    words = String.split(line)

    case words do
      [] -> [""]
      _ -> do_wrap(words, width, [], "")
    end
  end

  defp do_wrap([], _width, lines, current) do
    Enum.reverse([current | lines])
  end

  defp do_wrap([word | rest], width, lines, "") do
    if String.length(word) > width do
      {first, remaining} = String.split_at(word, width)
      do_wrap([remaining | rest], width, [first | lines], "")
    else
      do_wrap(rest, width, lines, word)
    end
  end

  defp do_wrap([word | rest], width, lines, current) do
    candidate = current <> " " <> word

    if String.length(candidate) <= width do
      do_wrap(rest, width, lines, candidate)
    else
      do_wrap([word | rest], width, [current | lines], "")
    end
  end

  # --- Truncation ---

  defp truncate_end(line, width) do
    if String.length(line) <= width do
      line
    else
      String.slice(line, 0, width - 1) <> @ellipsis
    end
  end

  defp truncate_start(line, width) do
    len = String.length(line)

    if len <= width do
      line
    else
      keep = width - 1
      @ellipsis <> String.slice(line, len - keep, keep)
    end
  end

  defp truncate_middle(line, width) do
    len = String.length(line)

    if len <= width do
      line
    else
      left_len = div(width - 1, 2)
      right_len = width - 1 - left_len
      left = String.slice(line, 0, left_len)

      right =
        if right_len > 0,
          do: String.slice(line, len - right_len, right_len),
          else: ""

      left <> @ellipsis <> right
    end
  end

  # --- Alignment ---

  defp align_line(line, _width, :left), do: line

  defp align_line(line, width, :center) do
    padding = max(width - String.length(line), 0)
    left_pad = div(padding, 2)
    String.duplicate(" ", left_pad) <> line
  end

  defp align_line(line, width, :right) do
    padding = max(width - String.length(line), 0)
    String.duplicate(" ", padding) <> line
  end
end
