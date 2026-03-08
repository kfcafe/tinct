defmodule Tinct.Terminal do
  @moduledoc """
  Low-level terminal control for raw mode, screen management, and size detection.

  Handles entering/exiting raw mode (disabling line buffering and echo),
  switching between primary and alternate screen buffers, and detecting
  terminal properties like size and TTY status.

  Terminal restoration is guaranteed even on crash via `with_raw_mode/1`.

  ## Example

      Tinct.Terminal.with_raw_mode(fn ->
        Tinct.Terminal.enter_alt_screen()
        # ... run your TUI ...
        Tinct.Terminal.exit_alt_screen()
      end)
  """

  @typedoc "Terminal state tracking struct."
  @type state :: %__MODULE__.State{
          raw_mode: boolean(),
          alt_screen: boolean(),
          original_opts: keyword() | nil
        }

  defmodule State do
    @moduledoc """
    Tracks the current terminal state.

    Fields:
    - `raw_mode` — whether raw mode is currently active
    - `alt_screen` — whether the alternate screen buffer is active
    - `original_opts` — the original `:io.setopts` options before raw mode was entered
    """

    @type t :: %__MODULE__{
            raw_mode: boolean(),
            alt_screen: boolean(),
            original_opts: keyword() | nil
          }

    defstruct raw_mode: false,
              alt_screen: false,
              original_opts: nil
  end

  # ANSI escape sequences for alternate screen buffer
  @enter_alt_screen "\e[?1049h"
  @exit_alt_screen "\e[?1049l"

  # -------------------------------------------------------------------
  # State management via Agent
  # -------------------------------------------------------------------

  @doc """
  Starts the terminal state agent.

  Called automatically by functions that need state tracking.
  Returns `{:ok, pid}` if started, or `{:error, {:already_started, pid}}`
  if already running.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    case Agent.start_link(fn -> %State{} end, name: __MODULE__) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  @doc """
  Returns the current terminal state.

  ## Example

      iex> Tinct.Terminal.ensure_started()
      iex> Tinct.Terminal.get_state()
      %Tinct.Terminal.State{raw_mode: false, alt_screen: false, original_opts: nil}
  """
  @spec get_state() :: State.t()
  def get_state do
    ensure_started()
    Agent.get(__MODULE__, & &1)
  end

  @spec update_state((State.t() -> State.t())) :: :ok
  defp update_state(fun) do
    ensure_started()
    Agent.update(__MODULE__, fun)
  end

  # -------------------------------------------------------------------
  # TTY and environment detection
  # -------------------------------------------------------------------

  @doc """
  Detects if stdout is connected to a TTY.

  Uses `:io.columns/0` — success means a TTY is present,
  failure means stdout is piped or redirected.

  ## Example

      Tinct.Terminal.tty?()
      #=> true
  """
  @spec tty?() :: boolean()
  def tty? do
    match?({:ok, _}, :io.columns())
  end

  @doc """
  Detects if the code is running inside IEx.

  Returns `true` only when the `IEx` module is loaded AND
  exposes `started?/0` returning `true`.

  ## Example

      Tinct.Terminal.iex?()
      #=> false
  """
  @spec iex?() :: boolean()
  def iex? do
    Code.ensure_loaded?(IEx) and function_exported?(IEx, :started?, 0) and iex_started?()
  end

  @spec iex_started?() :: boolean()
  defp iex_started? do
    :erlang.apply(IEx, :started?, [])
  end

  # -------------------------------------------------------------------
  # Terminal size
  # -------------------------------------------------------------------

  @doc """
  Returns the terminal dimensions as `{:ok, {cols, rows}}`.

  Falls back to `{:error, :enotsup}` when not connected to a TTY
  (e.g., in CI or piped output).

  ## Example

      Tinct.Terminal.size()
      #=> {:ok, {120, 40}}
  """
  @spec size() :: {:ok, {pos_integer(), pos_integer()}} | {:error, atom()}
  def size do
    with {:ok, cols} <- :io.columns(),
         {:ok, rows} <- :io.rows() do
      {:ok, {cols, rows}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # -------------------------------------------------------------------
  # Raw mode
  # -------------------------------------------------------------------

  @doc """
  Enters raw mode — disables line buffering and echo for character-at-a-time input.

  Sets `:standard_io` to binary mode with latin1 encoding, then uses
  `stty` to disable echo and canonical mode.

  Returns `:ok` on success, `{:error, reason}` on failure.

  ## Example

      Tinct.Terminal.enable_raw_mode()
      #=> :ok
  """
  @spec enable_raw_mode() :: :ok | {:error, term()}
  def enable_raw_mode do
    if get_state().raw_mode do
      :ok
    else
      do_enable_raw_mode()
    end
  end

  defp do_enable_raw_mode do
    original_opts = capture_original_opts()

    case set_stty_raw() do
      :ok ->
        :io.setopts(:standard_io, binary: true, encoding: :unicode, echo: false)
        update_state(fn state -> %{state | raw_mode: true, original_opts: original_opts} end)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Exits raw mode — restores the original terminal settings.

  Restores echo and canonical mode via `stty`, and resets `:standard_io`
  options to their pre-raw-mode values.

  Returns `:ok` on success, `{:error, reason}` on failure.

  ## Example

      Tinct.Terminal.disable_raw_mode()
      #=> :ok
  """
  @spec disable_raw_mode() :: :ok | {:error, term()}
  def disable_raw_mode do
    state = get_state()

    if state.raw_mode do
      do_disable_raw_mode(state)
    else
      :ok
    end
  end

  defp do_disable_raw_mode(state) do
    result = restore_stty()

    if state.original_opts do
      :io.setopts(:standard_io, state.original_opts)
    end

    update_state(fn s -> %{s | raw_mode: false, original_opts: nil} end)
    result
  end

  # -------------------------------------------------------------------
  # Alternate screen buffer
  # -------------------------------------------------------------------

  @doc """
  Switches to the alternate screen buffer.

  Writes the ANSI escape sequence to enter the alternate screen.
  The primary screen content is preserved and restored when
  `exit_alt_screen/0` is called.

  ## Example

      Tinct.Terminal.enter_alt_screen()
      #=> :ok
  """
  @spec enter_alt_screen() :: :ok
  def enter_alt_screen do
    :io.put_chars(:standard_io, @enter_alt_screen)
    update_state(fn state -> %{state | alt_screen: true} end)
    :ok
  end

  @doc """
  Switches back to the primary screen buffer.

  Writes the ANSI escape sequence to exit the alternate screen,
  restoring the original screen content.

  ## Example

      Tinct.Terminal.exit_alt_screen()
      #=> :ok
  """
  @spec exit_alt_screen() :: :ok
  def exit_alt_screen do
    :io.put_chars(:standard_io, @exit_alt_screen)
    update_state(fn state -> %{state | alt_screen: false} end)
    :ok
  end

  # -------------------------------------------------------------------
  # with_raw_mode/1 — guaranteed cleanup
  # -------------------------------------------------------------------

  @doc """
  Enters raw mode, runs the given function, and guarantees cleanup.

  Raw mode is always disabled after the function completes, even if
  it raises an exception. This is the recommended way to use raw mode.

  ## Example

      Tinct.Terminal.with_raw_mode(fn ->
        Tinct.Terminal.enter_alt_screen()
        # ... your TUI logic ...
        Tinct.Terminal.exit_alt_screen()
      end)
  """
  @spec with_raw_mode((-> result)) :: result | {:error, term()} when result: term()
  def with_raw_mode(fun) when is_function(fun, 0) do
    case enable_raw_mode() do
      :ok ->
        try do
          fun.()
        after
          disable_raw_mode()
        end

      {:error, _reason} = error ->
        error
    end
  end

  # -------------------------------------------------------------------
  # stty helpers (Port-based)
  # -------------------------------------------------------------------

  defp capture_original_opts do
    case :io.getopts(:standard_io) do
      opts when is_list(opts) -> opts
      _ -> nil
    end
  end

  defp set_stty_raw do
    # Use :nouse_stdio so the spawned stty inherits the BEAM's actual
    # terminal file descriptors. Both System.cmd and :os.cmd give the
    # child process a pipe as stdin, so stty would configure the pipe
    # (doing nothing) instead of the real terminal.
    run_stty(["raw", "-echo", "-icanon", "min", "1"])
  end

  defp restore_stty do
    run_stty(["-raw", "echo", "icanon"])
  end

  defp run_stty(args) do
    if tty?() do
      try do
        port =
          Port.open(
            {:spawn_executable, stty_path()},
            [:nouse_stdio, :exit_status, {:args, args}]
          )

        receive do
          {^port, {:exit_status, 0}} -> :ok
          {^port, {:exit_status, code}} -> {:error, {:stty_exit, code}}
        after
          2000 -> {:error, :stty_timeout}
        end
      rescue
        e -> {:error, {:stty_error, Exception.message(e)}}
      end
    else
      {:error, :not_a_tty}
    end
  end

  defp stty_path do
    case System.find_executable("stty") do
      nil -> "/bin/stty"
      path -> path
    end
  end
end
