defmodule Tinct.Color do
  @moduledoc """
  Color types and downsampling for terminal rendering.

  Supports named ANSI colors, 256-color indexed, and 24-bit true color RGB.
  Colors are automatically downsampled to match terminal capabilities.

  ## Color Types

    * Named atoms: `:black`, `:red`, `:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white`
    * Bright variants: `:bright_black`, `:bright_red`, `:bright_green`, etc.
    * Alias: `:dark_gray` (same as `:bright_black`)
    * Indexed: `{:index, 0..255}`
    * True color: `{:rgb, 0..255, 0..255, 0..255}`
    * Default: `:default` (terminal's default color)

  ## Color Profiles

    * `:true_color` — full 24-bit RGB
    * `:ansi256` — 256-color palette
    * `:ansi16` — 16 standard ANSI colors
    * `:ascii` — no color
    * `:no_tty` — no color (not a terminal)
  """

  @typedoc "A terminal color value."
  @type t ::
          :default
          | :black
          | :red
          | :green
          | :yellow
          | :blue
          | :magenta
          | :cyan
          | :white
          | :bright_black
          | :bright_red
          | :bright_green
          | :bright_yellow
          | :bright_blue
          | :bright_magenta
          | :bright_cyan
          | :bright_white
          | :dark_gray
          | {:index, 0..255}
          | {:rgb, 0..255, 0..255, 0..255}

  @typedoc "Terminal color capability profile."
  @type profile :: :true_color | :ansi256 | :ansi16 | :ascii | :no_tty

  # Named ANSI color to index (0-15)
  @named_to_index %{
    black: 0,
    red: 1,
    green: 2,
    yellow: 3,
    blue: 4,
    magenta: 5,
    cyan: 6,
    white: 7,
    bright_black: 8,
    dark_gray: 8,
    bright_red: 9,
    bright_green: 10,
    bright_yellow: 11,
    bright_blue: 12,
    bright_magenta: 13,
    bright_cyan: 14,
    bright_white: 15
  }

  # Index (0-15) to canonical named color
  @index_to_named %{
    0 => :black,
    1 => :red,
    2 => :green,
    3 => :yellow,
    4 => :blue,
    5 => :magenta,
    6 => :cyan,
    7 => :white,
    8 => :bright_black,
    9 => :bright_red,
    10 => :bright_green,
    11 => :bright_yellow,
    12 => :bright_blue,
    13 => :bright_magenta,
    14 => :bright_cyan,
    15 => :bright_white
  }

  # Approximate RGB values for the 16 ANSI colors (xterm defaults)
  @ansi16_rgb %{
    0 => {0, 0, 0},
    1 => {128, 0, 0},
    2 => {0, 128, 0},
    3 => {128, 128, 0},
    4 => {0, 0, 128},
    5 => {128, 0, 128},
    6 => {0, 128, 128},
    7 => {192, 192, 192},
    8 => {128, 128, 128},
    9 => {255, 0, 0},
    10 => {0, 255, 0},
    11 => {255, 255, 0},
    12 => {0, 0, 255},
    13 => {255, 0, 255},
    14 => {0, 255, 255},
    15 => {255, 255, 255}
  }

  # --- Public API ---

  @doc """
  Convert a named color to its ANSI index (0-15).

  ## Examples

      iex> Tinct.Color.named_to_index(:black)
      0

      iex> Tinct.Color.named_to_index(:bright_red)
      9

      iex> Tinct.Color.named_to_index(:dark_gray)
      8
  """
  @spec named_to_index(atom()) :: 0..15
  def named_to_index(name) when is_map_key(@named_to_index, name) do
    Map.fetch!(@named_to_index, name)
  end

  @doc """
  Convert a color to ANSI foreground escape code parameters.

  Returns a list of integers for SGR (Select Graphic Rendition) sequences.

  ## Examples

      iex> Tinct.Color.to_ansi_fg(:red)
      [31]

      iex> Tinct.Color.to_ansi_fg(:bright_red)
      [91]

      iex> Tinct.Color.to_ansi_fg({:index, 42})
      [38, 5, 42]

      iex> Tinct.Color.to_ansi_fg({:rgb, 255, 0, 0})
      [38, 2, 255, 0, 0]

      iex> Tinct.Color.to_ansi_fg(:default)
      [39]
  """
  @spec to_ansi_fg(t()) :: [non_neg_integer()]
  def to_ansi_fg(:default), do: [39]
  def to_ansi_fg({:rgb, r, g, b}), do: [38, 2, r, g, b]
  def to_ansi_fg({:index, n}) when n in 0..255, do: [38, 5, n]

  def to_ansi_fg(name) when is_map_key(@named_to_index, name) do
    index = Map.fetch!(@named_to_index, name)
    if index < 8, do: [30 + index], else: [82 + index]
  end

  @doc """
  Convert a color to ANSI background escape code parameters.

  Returns a list of integers for SGR (Select Graphic Rendition) sequences.

  ## Examples

      iex> Tinct.Color.to_ansi_bg(:red)
      [41]

      iex> Tinct.Color.to_ansi_bg(:bright_red)
      [101]

      iex> Tinct.Color.to_ansi_bg({:index, 42})
      [48, 5, 42]

      iex> Tinct.Color.to_ansi_bg({:rgb, 255, 0, 0})
      [48, 2, 255, 0, 0]

      iex> Tinct.Color.to_ansi_bg(:default)
      [49]
  """
  @spec to_ansi_bg(t()) :: [non_neg_integer()]
  def to_ansi_bg(:default), do: [49]
  def to_ansi_bg({:rgb, r, g, b}), do: [48, 2, r, g, b]
  def to_ansi_bg({:index, n}) when n in 0..255, do: [48, 5, n]

  def to_ansi_bg(name) when is_map_key(@named_to_index, name) do
    index = Map.fetch!(@named_to_index, name)
    if index < 8, do: [40 + index], else: [92 + index]
  end

  @doc """
  Downsample a color to fit within a color profile.

  Converts colors to the closest representation supported by the target profile:

    * `:true_color` — pass through unchanged
    * `:ansi256` — RGB maps to nearest 256-color index
    * `:ansi16` — RGB and indexed colors map to nearest named color
    * `:ascii` — all colors become `:default`
    * `:no_tty` — all colors become `:default`

  ## Examples

      iex> Tinct.Color.downsample({:rgb, 255, 0, 0}, :true_color)
      {:rgb, 255, 0, 0}

      iex> Tinct.Color.downsample({:rgb, 0, 0, 0}, :ansi256)
      {:index, 16}

      iex> Tinct.Color.downsample({:index, 1}, :ansi16)
      :red

      iex> Tinct.Color.downsample(:red, :ascii)
      :default
  """
  @spec downsample(t(), profile()) :: t()
  def downsample(color, :true_color), do: color
  def downsample(_color, :ascii), do: :default
  def downsample(_color, :no_tty), do: :default
  def downsample(:default, _profile), do: :default

  # ANSI 256: named and indexed pass through, RGB converts to index
  def downsample(color, :ansi256) when is_atom(color), do: color
  def downsample({:index, _} = color, :ansi256), do: color
  def downsample({:rgb, r, g, b}, :ansi256), do: {:index, rgb_to_index256(r, g, b)}

  # ANSI 16: everything converts to a named color
  def downsample(color, :ansi16) when is_atom(color), do: color

  def downsample({:index, n}, :ansi16) when n in 0..15 do
    Map.fetch!(@index_to_named, n)
  end

  def downsample({:index, n}, :ansi16) do
    {r, g, b} = index_to_rgb(n)
    Map.fetch!(@index_to_named, nearest_ansi16(r, g, b))
  end

  def downsample({:rgb, r, g, b}, :ansi16) do
    Map.fetch!(@index_to_named, nearest_ansi16(r, g, b))
  end

  # --- Private helpers ---

  # Convert RGB to nearest 256-color index.
  # Checks both the 6x6x6 color cube (16-231) and the grayscale ramp (232-255),
  # returning whichever is closer.
  @spec rgb_to_index256(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: 0..255
  defp rgb_to_index256(r, g, b) do
    # Color cube candidate
    ri = round(r / 255 * 5)
    gi = round(g / 255 * 5)
    bi = round(b / 255 * 5)
    cube_index = 16 + 36 * ri + 6 * gi + bi
    {cr, cg, cb} = {cube_value(ri), cube_value(gi), cube_value(bi)}
    cube_dist = color_distance_sq(r, g, b, cr, cg, cb)

    # Grayscale ramp candidate
    gray_avg = div(r + g + b, 3)
    gray_step = max(0, min(23, round((gray_avg - 8) / 10)))
    gray_val = 8 + 10 * gray_step
    gray_index = 232 + gray_step
    gray_dist = color_distance_sq(r, g, b, gray_val, gray_val, gray_val)

    if cube_dist <= gray_dist, do: cube_index, else: gray_index
  end

  # Convert a 256-color index to its approximate RGB values.
  defp index_to_rgb(n) when n in 0..15 do
    Map.fetch!(@ansi16_rgb, n)
  end

  defp index_to_rgb(n) when n in 16..231 do
    adjusted = n - 16
    ri = div(adjusted, 36)
    gi = div(rem(adjusted, 36), 6)
    bi = rem(adjusted, 6)
    {cube_value(ri), cube_value(gi), cube_value(bi)}
  end

  defp index_to_rgb(n) when n in 232..255 do
    gray = 8 + 10 * (n - 232)
    {gray, gray, gray}
  end

  # Find the nearest ANSI 16 color index for an RGB value.
  defp nearest_ansi16(r, g, b) do
    Enum.min_by(0..15, fn i ->
      {ar, ag, ab} = Map.fetch!(@ansi16_rgb, i)
      color_distance_sq(r, g, b, ar, ag, ab)
    end)
  end

  # Xterm color cube channel value (0-5 → actual RGB component).
  # Level 0 = 0, levels 1-5 = 55 + 40*n (giving 95, 135, 175, 215, 255).
  defp cube_value(0), do: 0
  defp cube_value(n), do: 55 + 40 * n

  # Squared Euclidean distance in RGB space (avoids sqrt for comparison).
  defp color_distance_sq(r1, g1, b1, r2, g2, b2) do
    dr = r1 - r2
    dg = g1 - g2
    db = b1 - b2
    dr * dr + dg * dg + db * db
  end
end
