defmodule Tinct.Terminal.Capabilities do
  @moduledoc """
  Detects terminal capabilities: color support, keyboard protocols,
  and rendering features.

  Reads from environment variables (`TERM`, `COLORTERM`, `TERM_PROGRAM`,
  `NO_COLOR`) and TTY status to determine what the terminal supports.

  For testing, pass a custom env map to `detect/1`:

      caps = Tinct.Terminal.Capabilities.detect(%{
        "COLORTERM" => "truecolor",
        "TERM" => "xterm-256color",
        tty: true
      })
      caps.color_profile
      #=> :true_color
  """

  @typedoc """
  Color profile indicating the terminal's color support level.

  - `:true_color` — 24-bit RGB (16 million colors)
  - `:ansi256` — 256-color palette
  - `:ansi16` — 16 standard ANSI colors
  - `:ascii` — no color (NO_COLOR is set)
  - `:no_tty` — not connected to a terminal
  """
  @type color_profile :: :true_color | :ansi256 | :ansi16 | :ascii | :no_tty

  @typedoc "Terminal capabilities struct."
  @type t :: %__MODULE__{
          color_profile: color_profile(),
          kitty_keyboard: boolean(),
          mouse: boolean(),
          bracketed_paste: boolean(),
          sync_rendering: boolean(),
          unicode_width: boolean(),
          term: String.t() | nil,
          term_program: String.t() | nil
        }

  defstruct color_profile: :ansi16,
            kitty_keyboard: false,
            mouse: true,
            bracketed_paste: true,
            sync_rendering: false,
            unicode_width: false,
            term: nil,
            term_program: nil

  @kitty_keyboard_terminals ~w(iTerm.app WezTerm ghostty rio contour foot kitty Alacritty)
  @sync_rendering_terminals ~w(iTerm.app WezTerm kitty foot contour ghostty)
  @unicode_width_terminals ~w(WezTerm kitty foot contour ghostty)

  # -------------------------------------------------------------------
  # Public API
  # -------------------------------------------------------------------

  @doc """
  Detects terminal capabilities from the current environment.

  Reads `TERM`, `COLORTERM`, `TERM_PROGRAM`, and `NO_COLOR` environment
  variables and checks TTY status via `Tinct.Terminal.tty?/0`.

  ## Example

      caps = Tinct.Terminal.Capabilities.detect()
      caps.color_profile
      #=> :true_color
  """
  @spec detect() :: t()
  def detect do
    detect(system_env())
  end

  @doc """
  Detects terminal capabilities from a custom environment map.

  String keys map to environment variable names. The atom key `:tty`
  overrides TTY detection (defaults to `Tinct.Terminal.tty?/0`).

  ## Examples

      iex> Tinct.Terminal.Capabilities.detect(%{"COLORTERM" => "truecolor", tty: true})
      %Tinct.Terminal.Capabilities{color_profile: :true_color, kitty_keyboard: false, mouse: true, bracketed_paste: true, sync_rendering: false, unicode_width: false, term: nil, term_program: nil}

      iex> Tinct.Terminal.Capabilities.detect(%{"NO_COLOR" => "1", tty: true})
      %Tinct.Terminal.Capabilities{color_profile: :ascii, kitty_keyboard: false, mouse: true, bracketed_paste: true, sync_rendering: false, unicode_width: false, term: nil, term_program: nil}
  """
  @spec detect(map()) :: t()
  def detect(env) when is_map(env) do
    tty? = Map.get_lazy(env, :tty, &Tinct.Terminal.tty?/0)
    term = Map.get(env, "TERM")
    term_program = Map.get(env, "TERM_PROGRAM")
    no_color = Map.get(env, "NO_COLOR")
    colorterm = Map.get(env, "COLORTERM")

    %__MODULE__{
      color_profile: detect_color_profile(no_color, colorterm, term, tty?),
      kitty_keyboard: kitty_keyboard?(term, term_program),
      mouse: mouse_supported?(term),
      bracketed_paste: bracketed_paste_supported?(term),
      sync_rendering: sync_rendering?(term, term_program),
      unicode_width: unicode_width?(term, term_program),
      term: term,
      term_program: term_program
    }
  end

  @doc """
  Detects and returns the terminal's color profile.

  Priority order:
  1. `NO_COLOR` env var set → `:ascii`
  2. `COLORTERM` is `"truecolor"` or `"24bit"` → `:true_color`
  3. `TERM` contains `"256color"` → `:ansi256`
  4. `TERM` is set and stdout is a TTY → `:ansi16`
  5. Otherwise → `:no_tty`

  ## Example

      Tinct.Terminal.Capabilities.color_profile()
      #=> :true_color
  """
  @spec color_profile() :: color_profile()
  def color_profile do
    detect().color_profile
  end

  @doc """
  Returns `true` if the terminal supports the Kitty keyboard protocol.

  Detected when `TERM` is `"xterm-kitty"` or `TERM_PROGRAM` is a known
  supporting terminal (kitty, iTerm.app, WezTerm, ghostty, rio, contour,
  foot, Alacritty).
  """
  @spec supports_kitty_keyboard?() :: boolean()
  def supports_kitty_keyboard? do
    detect().kitty_keyboard
  end

  @doc """
  Returns `true` if the terminal supports mouse events.

  Almost all modern terminals support mouse tracking. Returns `false`
  only for dumb terminals or when no `TERM` is set.
  """
  @spec supports_mouse?() :: boolean()
  def supports_mouse? do
    detect().mouse
  end

  @doc """
  Returns `true` if the terminal supports bracketed paste mode.

  Almost all modern terminals support bracketed paste. Returns `false`
  only for dumb terminals or when no `TERM` is set.
  """
  @spec supports_bracketed_paste?() :: boolean()
  def supports_bracketed_paste? do
    detect().bracketed_paste
  end

  @doc """
  Returns `true` if the terminal supports synchronized rendering (Mode 2026).

  Checked against known supporting terminals: kitty, iTerm.app, WezTerm,
  foot, contour, ghostty.
  """
  @spec supports_sync_rendering?() :: boolean()
  def supports_sync_rendering? do
    detect().sync_rendering
  end

  @doc """
  Returns `true` if the terminal supports Unicode width reporting (Mode 2027).

  Checked against known supporting terminals: kitty, WezTerm, foot,
  contour, ghostty.
  """
  @spec supports_unicode_width?() :: boolean()
  def supports_unicode_width? do
    detect().unicode_width
  end

  # -------------------------------------------------------------------
  # Private — environment
  # -------------------------------------------------------------------

  defp system_env do
    %{
      "TERM" => System.get_env("TERM"),
      "COLORTERM" => System.get_env("COLORTERM"),
      "TERM_PROGRAM" => System.get_env("TERM_PROGRAM"),
      "NO_COLOR" => System.get_env("NO_COLOR")
    }
  end

  # -------------------------------------------------------------------
  # Private — color profile detection
  # -------------------------------------------------------------------

  defp detect_color_profile(no_color, _colorterm, _term, _tty?) when is_binary(no_color) do
    :ascii
  end

  defp detect_color_profile(_no_color, colorterm, _term, _tty?)
       when colorterm in ["truecolor", "24bit"] do
    :true_color
  end

  defp detect_color_profile(_no_color, _colorterm, term, tty?) when is_binary(term) do
    if String.contains?(term, "256color"), do: :ansi256, else: tty_fallback(tty?)
  end

  defp detect_color_profile(_no_color, _colorterm, _term, _tty?), do: :no_tty

  defp tty_fallback(true), do: :ansi16
  defp tty_fallback(_), do: :no_tty

  # -------------------------------------------------------------------
  # Private — feature detection
  # -------------------------------------------------------------------

  defp kitty_keyboard?("xterm-kitty", _term_program), do: true
  defp kitty_keyboard?(_term, term_program), do: term_program in @kitty_keyboard_terminals

  defp mouse_supported?(nil), do: false
  defp mouse_supported?("dumb"), do: false
  defp mouse_supported?(_term), do: true

  defp bracketed_paste_supported?(nil), do: false
  defp bracketed_paste_supported?("dumb"), do: false
  defp bracketed_paste_supported?(_term), do: true

  defp sync_rendering?("xterm-kitty", _term_program), do: true
  defp sync_rendering?(_term, term_program), do: term_program in @sync_rendering_terminals

  defp unicode_width?("xterm-kitty", _term_program), do: true
  defp unicode_width?(_term, term_program), do: term_program in @unicode_width_terminals
end
