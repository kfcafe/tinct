defmodule Tinct.Widgets.Spinner do
  @moduledoc """
  Animated activity indicator component.

  The Spinner renders a single "frame" character (like `"⠋"` or `"/"`) and
  advances that frame on each tick.

  Spinner animation uses the `subscriptions/1` + `handle_tick/1` pattern:

    * `subscriptions/1` returns a tick subscription at the style's interval
    * `handle_tick/1` advances the frame index, wrapping back to 0

  ## Options

    * `:style` - built-in spinner style name (default: `:dots`)
    * `:label` - optional label displayed after the spinner (default: `nil`)
    * `:color` - spinner foreground color (default: `:cyan`)

  ## Examples

      iex> model = Tinct.Widgets.Spinner.init(style: :line)
      iex> view = Tinct.Widgets.Spinner.view(model)
      iex> Tinct.Test.render_view(view, {10, 1})
      "-"

  """

  use Tinct.Component

  alias Tinct.{Element, View}

  @typedoc "Built-in spinner style name."
  @type style_name :: :dots | :line | :arc | :bounce | :dots2 | :simple

  @typedoc "Spinner model."
  @type model :: %{
          style: style_name(),
          frame: non_neg_integer(),
          label: String.t() | nil,
          color: atom()
        }

  @typedoc "A subscription term returned from `subscriptions/1`."
  @type subscription :: {:tick, non_neg_integer()}

  @spinners %{
    dots:
      {[
         "⠋",
         "⠙",
         "⠹",
         "⠸",
         "⠼",
         "⠴",
         "⠦",
         "⠧",
         "⠇",
         "⠏"
       ], 80},
    line: {["-", "\\", "|", "/"], 130},
    arc: {["◜", "◠", "◝", "◞", "◡", "◟"], 100},
    bounce: {["⠁", "⠂", "⠄", "⠂"], 120},
    dots2: {["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"], 80},
    simple: {["◐", "◓", "◑", "◒"], 100}
  }

  # --- Public helpers ---

  @doc "Returns the list of built-in spinner styles."
  @spec styles() :: [style_name()]
  def styles do
    Map.keys(@spinners)
  end

  @doc "Returns the list of frames for a spinner style. Unknown styles fall back to `:dots`."
  @spec frames(atom()) :: [String.t()]
  def frames(style) when is_atom(style) do
    case Map.fetch(@spinners, style) do
      {:ok, {frames, _interval_ms}} -> frames
      :error -> frames(:dots)
    end
  end

  @doc "Returns the tick interval in milliseconds for a spinner style. Unknown styles fall back to `:dots`."
  @spec interval_ms(atom()) :: non_neg_integer()
  def interval_ms(style) when is_atom(style) do
    case Map.fetch(@spinners, style) do
      {:ok, {_frames, interval_ms}} -> interval_ms
      :error -> interval_ms(:dots)
    end
  end

  @doc "Returns how many frames a spinner style has. Unknown styles fall back to `:dots`."
  @spec frame_count(atom()) :: non_neg_integer()
  def frame_count(style) when is_atom(style) do
    style
    |> frames()
    |> length()
  end

  # --- Component callbacks ---

  @doc "Initializes the Spinner model from options."
  @impl true
  @spec init(keyword()) :: model()
  def init(opts) when is_list(opts) do
    style = normalize_style(Keyword.get(opts, :style, :dots))

    %{
      style: style,
      frame: 0,
      label: Keyword.get(opts, :label),
      color: Keyword.get(opts, :color, :cyan)
    }
  end

  @doc "Spinner does not handle messages; it only animates via ticks."
  @impl true
  @spec update(model(), term()) :: model()
  def update(model, _msg), do: model

  @doc "Returns a tick subscription at the style's interval."
  @impl true
  @spec subscriptions(model()) :: [subscription()]
  def subscriptions(model) do
    [{:tick, interval_ms(model.style)}]
  end

  @doc "Advances the spinner frame, wrapping around at the end of the sequence."
  @impl true
  @spec handle_tick(model()) :: model()
  def handle_tick(model) do
    count = frame_count(model.style)
    next_frame = advance_frame(model.frame, count)

    %{model | frame: next_frame}
  end

  @doc "Renders the current spinner frame, optionally followed by a label."
  @impl true
  @spec view(model()) :: View.t()
  def view(model) do
    frame = current_frame(model)

    spinner_el = Element.text(frame, fg: model.color)

    tree =
      case model.label do
        nil ->
          spinner_el

        label when is_binary(label) ->
          Element.row([gap: 1], [spinner_el, Element.text(label)])
      end

    View.new(tree)
  end

  # --- Private helpers ---

  defp normalize_style(style) when is_atom(style) do
    if Map.has_key?(@spinners, style), do: style, else: :dots
  end

  defp current_frame(model) do
    frames = frames(model.style)
    count = length(frames)

    index =
      case count do
        0 -> 0
        _ -> rem(model.frame, count)
      end

    Enum.at(frames, index, "")
  end

  defp advance_frame(_current, 0), do: 0

  defp advance_frame(current, count) when is_integer(current) and current >= 0 do
    rem(current + 1, count)
  end
end
