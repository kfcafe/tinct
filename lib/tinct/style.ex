defmodule Tinct.Style do
  @moduledoc """
  Style struct and builder for terminal elements.

  A `Style` combines visual text attributes (colors, bold, italic, etc.) with
  layout properties (padding, margin, dimensions, flex). Styles support three-valued
  logic for visual attributes: `true`, `false`, or `nil` (inherit from parent).

  ## Building styles

      Style.new(fg: :red, bold: true, padding: 1)
      Style.new(margin: {1, 2}, flex_grow: 1)

  ## Merging and inheritance

  Styles merge with `merge/2` — non-nil values in the child override the parent:

      parent = Style.new(fg: :blue, bold: true)
      child = Style.new(fg: :red)
      Style.merge(parent, child)
      # => %Style{fg: :red, bold: true, ...}

  ## Resolving for render

  Before rendering, call `resolve/1` to fill in defaults for any remaining `nil` values:

      Style.new(fg: :red) |> Style.resolve()
      # => %Style{fg: :red, bg: :default, bold: false, ...}
  """

  alias Tinct.Color

  @typedoc "A named style reference (resolved by the Theme module)."
  @type name :: atom()

  @typedoc "A style struct with visual and layout properties."
  @type t :: %__MODULE__{
          fg: Color.t() | nil,
          bg: Color.t() | nil,
          bold: boolean() | nil,
          italic: boolean() | nil,
          underline: boolean() | nil,
          strikethrough: boolean() | nil,
          dim: boolean() | nil,
          inverse: boolean() | nil,
          padding_top: non_neg_integer(),
          padding_right: non_neg_integer(),
          padding_bottom: non_neg_integer(),
          padding_left: non_neg_integer(),
          margin_top: non_neg_integer(),
          margin_right: non_neg_integer(),
          margin_bottom: non_neg_integer(),
          margin_left: non_neg_integer(),
          width: non_neg_integer() | nil,
          height: non_neg_integer() | nil,
          min_width: non_neg_integer() | nil,
          max_width: non_neg_integer() | nil,
          min_height: non_neg_integer() | nil,
          max_height: non_neg_integer() | nil,
          flex_grow: number(),
          flex_shrink: number(),
          gap: non_neg_integer(),
          justify_content: :start | :center | :end | :space_between | :space_around,
          align_items: :start | :center | :end | :stretch,
          border: nil | :none | :single | :double | :round | :bold
        }

  defstruct fg: nil,
            bg: nil,
            bold: nil,
            italic: nil,
            underline: nil,
            strikethrough: nil,
            dim: nil,
            inverse: nil,
            padding_top: 0,
            padding_right: 0,
            padding_bottom: 0,
            padding_left: 0,
            margin_top: 0,
            margin_right: 0,
            margin_bottom: 0,
            margin_left: 0,
            width: nil,
            height: nil,
            min_width: nil,
            max_width: nil,
            min_height: nil,
            max_height: nil,
            flex_grow: 0,
            flex_shrink: 1,
            gap: 0,
            justify_content: :start,
            align_items: :stretch,
            border: nil

  @visual_attrs [:fg, :bg, :bold, :italic, :underline, :strikethrough, :dim, :inverse]

  @doc """
  Creates an empty style with all visual attributes set to `nil` (inherit)
  and layout properties at their defaults.

  ## Examples

      iex> Tinct.Style.new()
      %Tinct.Style{}
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Creates a style from a keyword list.

  Supports shorthand keys for padding and margin:

    * `padding: n` — sets all four padding sides to `n`
    * `padding: {v, h}` — sets vertical padding to `v`, horizontal to `h`
    * `margin: n` — sets all four margin sides to `n`
    * `margin: {v, h}` — sets vertical margin to `v`, horizontal to `h`

  All other keys map directly to struct fields.

  ## Examples

      iex> style = Tinct.Style.new(fg: :red, bold: true)
      iex> style.fg
      :red
      iex> style.bold
      true

      iex> style = Tinct.Style.new(padding: 2)
      iex> {style.padding_top, style.padding_right, style.padding_bottom, style.padding_left}
      {2, 2, 2, 2}

      iex> style = Tinct.Style.new(margin: {1, 3})
      iex> {style.margin_top, style.margin_right, style.margin_bottom, style.margin_left}
      {1, 3, 1, 3}
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    opts
    |> expand_shorthands()
    |> then(&struct(__MODULE__, &1))
  end

  @doc """
  Merges two styles. Non-nil values in `override` replace values in `base`.

  This enables style inheritance: merge a parent style with a child style,
  and the child's explicit values win while inheriting the parent's values
  for anything left as `nil`.

  ## Examples

      iex> base = Tinct.Style.new(fg: :blue, bold: true)
      iex> override = Tinct.Style.new(fg: :red)
      iex> merged = Tinct.Style.merge(base, override)
      iex> {merged.fg, merged.bold}
      {:red, true}

      iex> base = Tinct.Style.new(fg: :blue, padding: 2)
      iex> override = Tinct.Style.new(fg: :red, padding: 4)
      iex> merged = Tinct.Style.merge(base, override)
      iex> {merged.fg, merged.padding_top}
      {:red, 4}
  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = base, %__MODULE__{} = override) do
    base
    |> Map.from_struct()
    |> Enum.map(fn {key, base_val} ->
      override_val = Map.fetch!(override, key)
      {key, merge_value(key, base_val, override_val)}
    end)
    |> then(&struct(__MODULE__, &1))
  end

  @doc """
  Resolves a style by replacing `nil` visual attributes with their defaults.

  Called at render time to ensure every attribute has a concrete value:

    * `fg` → `:default`
    * `bg` → `:default`
    * `bold`, `italic`, `underline`, `strikethrough`, `dim`, `inverse` → `false`

  Layout properties already have non-nil defaults and are unchanged.

  ## Examples

      iex> style = Tinct.Style.new(fg: :red)
      iex> resolved = Tinct.Style.resolve(style)
      iex> {resolved.fg, resolved.bg, resolved.bold}
      {:red, :default, false}
  """
  @spec resolve(t()) :: t()
  def resolve(%__MODULE__{} = style) do
    %{
      style
      | fg: style.fg || :default,
        bg: style.bg || :default,
        bold: resolve_bool(style.bold),
        italic: resolve_bool(style.italic),
        underline: resolve_bool(style.underline),
        strikethrough: resolve_bool(style.strikethrough),
        dim: resolve_bool(style.dim),
        inverse: resolve_bool(style.inverse)
    }
  end

  @doc """
  Extracts the visual attributes needed for a `Tinct.Buffer.Cell`.

  Returns a keyword list with `:fg`, `:bg`, `:bold`, `:italic`, `:underline`,
  `:strikethrough`, `:dim`, and `:inverse`. Values are taken as-is from the
  style (call `resolve/1` first if you need defaults filled in).

  ## Examples

      iex> style = Tinct.Style.new(fg: :red, bold: true, padding: 2)
      iex> Tinct.Style.to_cell_attrs(style)
      [fg: :red, bg: nil, bold: true, italic: nil, underline: nil, strikethrough: nil, dim: nil, inverse: nil]
  """
  @spec to_cell_attrs(t()) :: keyword()
  def to_cell_attrs(%__MODULE__{} = style) do
    Enum.map(@visual_attrs, fn attr -> {attr, Map.fetch!(style, attr)} end)
  end

  # --- Private helpers ---

  defp expand_shorthands(opts) do
    opts
    |> expand_padding()
    |> expand_margin()
  end

  defp expand_padding(opts) do
    case Keyword.pop(opts, :padding) do
      {nil, rest} -> rest
      {n, rest} when is_integer(n) -> merge_layout(rest, :padding, n, n, n, n)
      {{v, h}, rest} -> merge_layout(rest, :padding, v, h, v, h)
    end
  end

  defp expand_margin(opts) do
    case Keyword.pop(opts, :margin) do
      {nil, rest} -> rest
      {n, rest} when is_integer(n) -> merge_layout(rest, :margin, n, n, n, n)
      {{v, h}, rest} -> merge_layout(rest, :margin, v, h, v, h)
    end
  end

  defp merge_layout(opts, prefix, top, right, bottom, left) do
    top_key = :"#{prefix}_top"
    right_key = :"#{prefix}_right"
    bottom_key = :"#{prefix}_bottom"
    left_key = :"#{prefix}_left"

    opts
    |> Keyword.put_new(top_key, top)
    |> Keyword.put_new(right_key, right)
    |> Keyword.put_new(bottom_key, bottom)
    |> Keyword.put_new(left_key, left)
  end

  # For visual attributes: nil means "inherit" so it doesn't override.
  # For layout attributes (integers): 0 is a real value, not "unset",
  # so the override's value always wins.
  defp merge_value(key, base_val, override_val) when key in @visual_attrs do
    if override_val == nil, do: base_val, else: override_val
  end

  defp merge_value(_key, _base_val, override_val), do: override_val

  defp resolve_bool(nil), do: false
  defp resolve_bool(val), do: val
end
