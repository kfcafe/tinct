defmodule Tinct.App.Supervisor do
  @moduledoc """
  OTP Supervisor that starts and manages all framework processes.

  Starts children in dependency order using `:rest_for_one` strategy:

  1. `Task.Supervisor` — for async command execution
  2. `Tinct.Terminal.Writer` — buffered terminal output
  3. `Tinct.Event.Reader` — terminal input parsing
  4. `Tinct.App` — the component event loop

  If an earlier child crashes, all later children are restarted too,
  ensuring the App always has valid Writer and Reader references.

  ## Options

    * `:component` (required) — the component module
    * `:test_mode` — if `true`, use test writer and reader (default `false`)
    * `:size` — fixed terminal size as `{cols, rows}` (default `{80, 24}`)
    * `:name` — optional supervisor name for registration
  """

  use Supervisor

  @doc """
  Starts the application supervisor.

  ## Options

    * `:component` (required) — the component module implementing `Tinct.Component`
    * `:test_mode` — use test writer and reader (default `false`)
    * `:size` — fixed terminal dimensions `{cols, rows}` (no terminal query)
    * `:name` — optional supervisor name for registration
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    sup_opts = if name, do: [name: name], else: []
    Supervisor.start_link(__MODULE__, opts, sup_opts)
  end

  @impl true
  def init(opts) do
    component = Keyword.fetch!(opts, :component)
    test_mode = Keyword.get(opts, :test_mode, false)
    size = Keyword.get(opts, :size, {80, 24})

    children = [
      {Task.Supervisor, name: task_sup_name(component)},
      {Tinct.Terminal.Writer, writer_opts(component, test_mode)},
      {Tinct.Event.Reader, reader_opts(component, test_mode)},
      {Tinct.App, app_opts(component, size)}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  @doc """
  Returns the registered name for the App GenServer for the given component.

  Used internally and in tests to locate the running App process.

  ## Examples

      iex> Tinct.App.Supervisor.app_name(MyApp.Counter)
      MyApp.Counter.App
  """
  @spec app_name(module()) :: module()
  def app_name(component), do: Module.concat(component, App)

  # --- Private helpers ---

  @spec writer_name(module()) :: module()
  defp writer_name(component), do: Module.concat(component, Writer)

  @spec task_sup_name(module()) :: module()
  defp task_sup_name(component), do: Module.concat(component, TaskSupervisor)

  @spec writer_opts(module(), boolean()) :: keyword()
  defp writer_opts(component, true = _test_mode) do
    [output: :discard, name: writer_name(component)]
  end

  defp writer_opts(component, false = _test_mode) do
    [name: writer_name(component)]
  end

  @spec reader_opts(module(), boolean()) :: keyword()
  defp reader_opts(component, true = _test_mode) do
    [target: app_name(component), input_mode: {:test, self()}]
  end

  defp reader_opts(component, false = _test_mode) do
    [target: app_name(component)]
  end

  @spec app_opts(module(), {pos_integer(), pos_integer()}) :: keyword()
  defp app_opts(component, size) do
    [
      component: component,
      name: app_name(component),
      writer: writer_name(component),
      task_supervisor: task_sup_name(component),
      size: size
    ]
  end
end
