defmodule Tinct.Widgets.ProgressBar do
  @moduledoc """
  Determinate progress indicator widget.

  Renders a progress bar made up of a filled segment and an empty segment.
  Optionally prepends a label and/or appends a percentage like `"50%"`.

  The widget is determinate: `progress` is expected to be a float from `0.0`
  to `1.0`.

  ## Options

    * `:progress` - initial progress value (default: `0.0`)
    * `:width` - total width in columns for the entire widget (default: `nil`)
      When `nil`, the bar uses a default internal width of 20 characters and
      the overall widget width is computed from its content.
    * `:filled_char` - character used for the filled portion (default: `"█"`)
    * `:empty_char` - character used for the empty portion (default: `"░"`)
    * `:filled_color` - foreground color for filled portion (default: `:green`)
    * `:empty_color` - foreground color for empty portion (default: `:bright_black`)
    * `:show_percentage` - whether to show `"{n}%"` after the bar (default: `true`)
    * `:label` - optional text label shown before the bar (default: `nil`)

  ## Examples

      iex> model = Tinct.Widgets.ProgressBar.init(progress: 0.5, width: 14)
      iex> model |> Tinct.Widgets.ProgressBar.view() |> Tinct.Test.render_view({20, 1})
      "█████░░░░░ 50%"

  """

  use Tinct.Component

  alias Tinct.{Element, View}

  @default_bar_width 20

  @typedoc "Progress bar model."
  @type model :: %{
          progress: float(),
          width: pos_integer() | nil,
          filled_char: String.t(),
          empty_char: String.t(),
          filled_color: atom(),
          empty_color: atom(),
          show_percentage: boolean(),
          label: String.t() | nil
        }

  # --- Component callbacks ---

  @doc "Initializes the ProgressBar model from options."
  @impl true
  @spec init(keyword()) :: model()
  def init(opts) when is_list(opts) do
    progress = opts |> Keyword.get(:progress, 0.0) |> normalize_progress()

    %{
      progress: progress,
      width: Keyword.get(opts, :width),
      filled_char: Keyword.get(opts, :filled_char, "█"),
      empty_char: Keyword.get(opts, :empty_char, "░"),
      filled_color: Keyword.get(opts, :filled_color, :green),
      empty_color: Keyword.get(opts, :empty_color, :bright_black),
      show_percentage: Keyword.get(opts, :show_percentage, true),
      label: Keyword.get(opts, :label)
    }
  end

  @doc "Updates the progress bar. Supports `{:set_progress, progress}` and `{:increment, delta}` messages."
  @impl true
  @spec update(model(), term()) :: model()
  def update(model, {:set_progress, progress}) when is_number(progress) do
    set_progress(model, progress)
  end

  def update(model, {:increment, delta}) when is_number(delta) do
    increment(model, delta)
  end

  def update(model, {:set_progress, _progress}), do: model
  def update(model, {:increment, _delta}), do: model
  def update(model, _msg), do: model

  @doc "Renders the progress bar as a single line."
  @impl true
  @spec view(model()) :: View.t()
  def view(model) do
    {label, percent_text} = label_and_percent_text(model)
    bar_width = bar_width(model, label, percent_text)

    {filled_text, empty_text} = bar_segments(model, bar_width)

    filled_el = Element.text(filled_text, fg: model.filled_color)
    empty_el = Element.text(empty_text, fg: model.empty_color)

    bar_el =
      Element.row([gap: 0, width: bar_width, align_items: :start], [filled_el, empty_el])

    children =
      []
      |> maybe_append_label(label)
      |> Kernel.++([bar_el])
      |> maybe_append_percent(percent_text)

    View.new(
      Element.row(
        [gap: 1, width: widget_width(model, label, percent_text, bar_width), align_items: :start],
        children
      )
    )
  end

  # --- Public API ---

  @doc """
  Sets the progress to a specific value, clamped to `0.0..1.0`.

  ## Examples

      iex> model = Tinct.Widgets.ProgressBar.init([])
      iex> model = Tinct.Widgets.ProgressBar.set_progress(model, 2.0)
      iex> model.progress
      1.0

  """
  @spec set_progress(model(), number()) :: model()
  def set_progress(%{progress: _} = model, progress) when is_number(progress) do
    %{model | progress: normalize_progress(progress)}
  end

  @doc """
  Increments progress by `delta`, clamped to `0.0..1.0`.

  ## Examples

      iex> model = Tinct.Widgets.ProgressBar.init(progress: 0.9)
      iex> model = Tinct.Widgets.ProgressBar.increment(model, 0.5)
      iex> model.progress
      1.0

  """
  @spec increment(model(), number()) :: model()
  def increment(%{progress: progress} = model, delta) when is_number(delta) do
    set_progress(model, progress + delta)
  end

  # --- Rendering helpers ---

  defp label_and_percent_text(model) do
    label = model.label

    percent_text =
      if model.show_percentage do
        "#{percent(model.progress)}%"
      end

    {label, percent_text}
  end

  defp bar_width(%{width: nil}, _label, _percent_text), do: @default_bar_width

  defp bar_width(%{width: total_width}, label, percent_text) when is_integer(total_width) do
    reserved = reserved_width(label, percent_text)
    max(total_width - reserved, 0)
  end

  defp bar_width(%{width: _other}, _label, _percent_text), do: @default_bar_width

  defp reserved_width(label, percent_text) do
    parts =
      []
      |> maybe_add_part(label)
      |> Kernel.++([:bar])
      |> maybe_add_part(percent_text)

    gaps = max(length(parts) - 1, 0)

    label_width = if is_binary(label), do: String.length(label), else: 0
    percent_width = if is_binary(percent_text), do: String.length(percent_text), else: 0

    label_width + percent_width + gaps
  end

  defp widget_width(%{width: total_width}, _label, _percent_text, _bar_width)
       when is_integer(total_width) and total_width > 0 do
    total_width
  end

  defp widget_width(%{width: _other}, label, percent_text, bar_width) do
    reserved_width(label, percent_text) + bar_width
  end

  defp bar_segments(model, width) when is_integer(width) and width >= 0 do
    filled_width = filled_width(model.progress, width)

    {
      String.duplicate(model.filled_char, filled_width),
      String.duplicate(model.empty_char, width - filled_width)
    }
  end

  defp filled_width(progress, available_width) do
    progress
    |> Kernel.*(available_width)
    |> round()
    |> clamp_int(0, available_width)
  end

  # --- Child list helpers ---

  defp maybe_append_label(children, nil), do: children

  defp maybe_append_label(children, label) when is_binary(label),
    do: children ++ [Element.text(label)]

  defp maybe_append_percent(children, nil), do: children

  defp maybe_append_percent(children, percent_text) when is_binary(percent_text) do
    children ++ [Element.text(percent_text)]
  end

  defp maybe_add_part(parts, nil), do: parts
  defp maybe_add_part(parts, value) when is_binary(value), do: parts ++ [value]

  # --- Math helpers ---

  defp normalize_progress(progress) when is_integer(progress) do
    progress
    |> Kernel.*(1.0)
    |> normalize_progress()
  end

  defp normalize_progress(progress) when is_float(progress) do
    progress
    |> max(0.0)
    |> min(1.0)
  end

  defp percent(progress) do
    progress
    |> Kernel.*(100)
    |> round()
    |> clamp_int(0, 100)
  end

  defp clamp_int(value, min_val, max_val) when is_integer(value) do
    value |> max(min_val) |> min(max_val)
  end
end
