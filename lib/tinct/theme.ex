defmodule Tinct.Theme do
  @moduledoc """
  Named themes and color palettes for terminal UI.

  A theme maps symbolic names (atoms) to `Tinct.Style` structs, allowing
  components to reference styles by name rather than by value. At render time,
  the framework resolves names through the active theme.

  Themes are plain data — structs and maps. No ETS, no processes.

  ## Usage

      theme = Theme.new(:my_app, %{
        error: Style.new(fg: :red, bold: true),
        success: Style.new(fg: :green)
      })

      Theme.get(theme, :error)
      # => %Style{fg: :red, bold: true, ...}

  ## Merging

  Themes can be merged, with the second theme's styles overriding the first:

      base = Theme.default()
      custom = Theme.new(:custom, %{error: Style.new(fg: :magenta)})
      merged = Theme.merge(base, custom)
  """

  alias Tinct.Style

  @typedoc "A theme struct mapping names to styles."
  @type t :: %__MODULE__{
          name: atom(),
          styles: %{atom() => Style.t()}
        }

  defstruct name: :default,
            styles: %{}

  @doc """
  Creates a new theme with the given name and style map.

  ## Examples

      iex> theme = Tinct.Theme.new(:app, %{bold: Tinct.Style.new(bold: true)})
      iex> theme.name
      :app
      iex> theme.styles[:bold].bold
      true
  """
  @spec new(atom(), %{atom() => Style.t()}) :: t()
  def new(name, styles) when is_atom(name) and is_map(styles) do
    %__MODULE__{name: name, styles: styles}
  end

  @doc """
  Looks up a style by name. Returns `nil` if the name is not found.

  ## Examples

      iex> theme = Tinct.Theme.new(:app, %{error: Tinct.Style.new(fg: :red)})
      iex> Tinct.Theme.get(theme, :error).fg
      :red

      iex> theme = Tinct.Theme.new(:app, %{})
      iex> Tinct.Theme.get(theme, :missing)
      nil
  """
  @spec get(t(), atom()) :: Style.t() | nil
  def get(%__MODULE__{styles: styles}, name) when is_atom(name) do
    Map.get(styles, name)
  end

  @doc """
  Looks up a style by name, returning `default` if the name is not found.

  ## Examples

      iex> theme = Tinct.Theme.new(:app, %{})
      iex> fallback = Tinct.Style.new(fg: :yellow)
      iex> Tinct.Theme.get(theme, :missing, fallback).fg
      :yellow
  """
  @spec get(t(), atom(), Style.t()) :: Style.t()
  def get(%__MODULE__{styles: styles}, name, default) when is_atom(name) do
    Map.get(styles, name, default)
  end

  @doc """
  Adds or updates a named style in the theme.

  ## Examples

      iex> theme = Tinct.Theme.new(:app, %{})
      iex> updated = Tinct.Theme.put(theme, :info, Tinct.Style.new(fg: :cyan))
      iex> Tinct.Theme.get(updated, :info).fg
      :cyan
  """
  @spec put(t(), atom(), Style.t()) :: t()
  def put(%__MODULE__{} = theme, name, %Style{} = style) when is_atom(name) do
    %{theme | styles: Map.put(theme.styles, name, style)}
  end

  @doc """
  Merges two themes. Styles from the second theme override those in the first.

  The merged theme takes the name from the `override` theme.

  ## Examples

      iex> base = Tinct.Theme.new(:base, %{error: Tinct.Style.new(fg: :red)})
      iex> over = Tinct.Theme.new(:over, %{error: Tinct.Style.new(fg: :magenta)})
      iex> merged = Tinct.Theme.merge(base, over)
      iex> merged.name
      :over
      iex> Tinct.Theme.get(merged, :error).fg
      :magenta
  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = base, %__MODULE__{} = override) do
    %__MODULE__{
      name: override.name,
      styles: Map.merge(base.styles, override.styles)
    }
  end

  @doc """
  Resolves a style name through the theme, returning the resolved `Style`.

  If the name exists in the theme, the corresponding style is returned
  with all `nil` visual attributes filled in via `Style.resolve/1`.
  Returns `nil` if the name is not found.

  ## Examples

      iex> theme = Tinct.Theme.new(:app, %{error: Tinct.Style.new(fg: :red)})
      iex> resolved = Tinct.Theme.resolve(theme, :error)
      iex> {resolved.fg, resolved.bg, resolved.bold}
      {:red, :default, false}

      iex> theme = Tinct.Theme.new(:app, %{})
      iex> Tinct.Theme.resolve(theme, :missing)
      nil
  """
  @spec resolve(t(), atom()) :: Style.t() | nil
  def resolve(%__MODULE__{} = theme, name) when is_atom(name) do
    case get(theme, name) do
      nil -> nil
      style -> Style.resolve(style)
    end
  end

  @doc """
  Returns the built-in default theme with sensible base styles.

  Includes styles for common UI elements: `:text`, `:bold`, `:dim`, `:error`,
  `:warning`, `:success`, `:info`, `:muted`, `:border`, `:title`, `:selected`,
  `:focused`, `:status_bar`, `:input`, and `:placeholder`.

  ## Examples

      iex> theme = Tinct.Theme.default()
      iex> theme.name
      :default
      iex> Tinct.Theme.get(theme, :error).fg
      :red
  """
  @spec default() :: t()
  def default do
    new(:default, %{
      text: Style.new(fg: :default, bg: :default),
      bold: Style.new(bold: true),
      dim: Style.new(dim: true),
      error: Style.new(fg: :red, bold: true),
      warning: Style.new(fg: :yellow),
      success: Style.new(fg: :green),
      info: Style.new(fg: :cyan),
      muted: Style.new(fg: :bright_black),
      border: Style.new(fg: :bright_black),
      title: Style.new(fg: :white, bold: true),
      selected: Style.new(bg: :blue, fg: :white),
      focused: Style.new(border: :round, fg: :cyan),
      status_bar: Style.new(bg: :bright_black, fg: :white),
      input: Style.new(bg: :bright_black),
      placeholder: Style.new(fg: :bright_black, italic: true)
    })
  end
end
