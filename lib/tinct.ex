defmodule Tinct do
  @moduledoc """
  A terminal UI framework for Elixir.

  Tinct brings the Elm Architecture to terminal interfaces — declarative views,
  CSS-like styling, flexbox layout, and OTP supervision. Build terminal apps
  the same way you'd build a LiveView.

  ## Quick Start

      defmodule MyApp do
        use Tinct.Component

        def init(_opts), do: %{count: 0}

        def update(model, :increment), do: %{model | count: model.count + 1}
        def update(model, :decrement), do: %{model | count: model.count - 1}
        def update(model, {:key, "q"}), do: Tinct.quit(model)
        def update(model, _msg), do: model

        def view(model) do
          import Tinct.UI

          column do
            text "Count: \#{model.count}", bold: true
            text "↑/↓ to change, q to quit", color: :dark_gray
          end
        end
      end

      Tinct.run(MyApp)
  """

  @doc """
  Runs a Tinct component as a full-screen terminal application.

  Enters raw mode, starts the application supervisor, and blocks until
  the application shuts down. Terminal state is always restored on exit.

  In test mode, raw mode is skipped and test I/O backends are used.

  ## Options

    * `:test_mode` — skip raw mode and use test I/O (default `false`)
    * `:size` — fixed terminal size as `{cols, rows}` (default `{80, 24}`)
    * `:name` — optional name for the supervisor

  ## Examples

      Tinct.run(MyApp)
      Tinct.run(MyApp, size: {120, 40})
  """
  @spec run(module(), keyword()) :: :ok
  def run(component, opts \\ []) do
    test_mode = Keyword.get(opts, :test_mode, false)

    unless test_mode do
      suppress_fd_driver_warnings()
      Tinct.Terminal.enable_raw_mode()
    end

    # Detect actual terminal size unless explicitly provided
    opts =
      if Keyword.has_key?(opts, :size) do
        opts
      else
        case Tinct.Terminal.size() do
          {:ok, size} -> Keyword.put(opts, :size, size)
          _ -> opts
        end
      end

    try do
      {:ok, sup} = Tinct.App.Supervisor.start_link([{:component, component} | opts])
      ref = Process.monitor(sup)

      receive do
        {:DOWN, ^ref, :process, ^sup, _reason} -> :ok
      end
    after
      unless test_mode do
        Tinct.Terminal.disable_raw_mode()
        restore_fd_driver_warnings()
      end
    end
  end

  @doc """
  Returns the model paired with a quit command.

  Use this in `update/2` to signal the application should shut down:

      def update(model, {:key, "q"}), do: Tinct.quit(model)

  ## Examples

      iex> {model, cmd} = Tinct.quit(%{count: 42})
      iex> model
      %{count: 42}
      iex> cmd
      :quit
  """
  @spec quit(term()) :: {term(), Tinct.Command.t()}
  def quit(model) do
    {model, Tinct.Command.quit()}
  end

  # The Event.Reader opens Port.open({:fd, 0, 1}, ...) to read raw stdin.
  # On OTP 26+, prim_tty already owns fd 0, so the fd driver "steals" it
  # and the runtime logs a noisy warning. Suppress it during the TUI session.

  @filter_id :tinct_suppress_fd_driver_steal

  defp suppress_fd_driver_warnings do
    :logger.add_primary_filter(@filter_id, {&filter_fd_driver_steal/2, []})
  rescue
    _ -> :ok
  end

  defp restore_fd_driver_warnings do
    :logger.remove_primary_filter(@filter_id)
  rescue
    _ -> :ok
  end

  defp filter_fd_driver_steal(%{msg: {format, args}}, _extra)
       when is_list(format) and is_list(args) do
    if stealing_control_message?(args), do: :stop, else: :ignore
  end

  defp filter_fd_driver_steal(%{msg: {:string, chardata}}, _extra) do
    if IO.chardata_to_string(chardata) |> String.contains?("stealing control"),
      do: :stop,
      else: :ignore
  end

  defp filter_fd_driver_steal(_event, _extra), do: :ignore

  defp stealing_control_message?(args) do
    Enum.any?(args, fn
      arg when is_list(arg) -> :string.find(arg, ~c"stealing control") != :nomatch
      arg when is_binary(arg) -> String.contains?(arg, "stealing control")
      _ -> false
    end)
  end
end
