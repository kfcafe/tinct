defmodule Tinct.Terminal.Writer do
  @moduledoc """
  Buffered ANSI output with synchronized rendering.

  Batches terminal writes into frames and flushes them as a single
  atomic operation, eliminating flicker. When sync rendering is enabled,
  output is wrapped in Mode 2026 begin/end markers so the terminal
  holds display updates until the full frame is ready.

  ## Testing

  Pass `output: self()` to receive `{:terminal_output, binary}` messages
  instead of writing to stdio:

      {:ok, writer} = Tinct.Terminal.Writer.start_link(output: self())
      Tinct.Terminal.Writer.write(writer, "hello")
      Tinct.Terminal.Writer.flush(writer)
      assert_receive {:terminal_output, "hello"}
  """

  use GenServer

  defstruct output: :stdio,
            sync_rendering: false,
            buffer: []

  @type t :: %__MODULE__{
          output: :stdio | :discard | pid(),
          sync_rendering: boolean(),
          buffer: list()
        }

  # --- Client API ---

  @doc """
  Starts the writer process.

  ## Options

  - `:output` — where to send output. `:stdio` (default) writes to standard output;
    `:discard` silently drops all output; a pid receives `{:terminal_output, binary}`
    messages (for testing).
  - `:sync_rendering` — whether to wrap flushes in Mode 2026 sync markers. Default `false`.
  - `:name` — optional GenServer name for registration.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {output, opts} = Keyword.pop(opts, :output, :stdio)
    {sync_rendering, opts} = Keyword.pop(opts, :sync_rendering, false)

    init_arg = %__MODULE__{
      output: output,
      sync_rendering: sync_rendering
    }

    GenServer.start_link(__MODULE__, init_arg, opts)
  end

  @doc """
  Queues iodata to the current frame buffer without sending it.

  Data accumulates until `flush/1` is called.
  """
  @spec write(GenServer.server(), iodata()) :: :ok
  def write(server, data) do
    GenServer.call(server, {:write, data})
  end

  @doc """
  Flushes all buffered output to the terminal in one operation.

  When sync rendering is enabled, the output is wrapped in
  `Tinct.ANSI.begin_sync/0` and `Tinct.ANSI.end_sync/0` markers.
  Clears the buffer after writing.

  Does nothing if the buffer is empty.
  """
  @spec flush(GenServer.server()) :: :ok
  def flush(server) do
    GenServer.call(server, :flush)
  end

  @doc """
  Writes iodata and immediately flushes.

  Convenience function combining `write/2` and `flush/1` in a single call.
  """
  @spec write_and_flush(GenServer.server(), iodata()) :: :ok
  def write_and_flush(server, data) do
    GenServer.call(server, {:write_and_flush, data})
  end

  # --- GenServer Callbacks ---

  @impl true
  @spec init(t()) :: {:ok, t()}
  def init(%__MODULE__{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:write, data}, _from, state) do
    {:reply, :ok, %{state | buffer: [state.buffer, data]}}
  end

  def handle_call(:flush, _from, state) do
    state = do_flush(state)
    {:reply, :ok, state}
  end

  def handle_call({:write_and_flush, data}, _from, state) do
    state = %{state | buffer: [state.buffer, data]}
    state = do_flush(state)
    {:reply, :ok, state}
  end

  # --- Private ---

  defp do_flush(%{buffer: []} = state), do: state

  defp do_flush(state) do
    output =
      if state.sync_rendering do
        [Tinct.ANSI.begin_sync(), state.buffer, Tinct.ANSI.end_sync()]
      else
        state.buffer
      end

    do_write(state.output, output)
    %{state | buffer: []}
  end

  defp do_write(:stdio, data) do
    :io.put_chars(:standard_io, data)
  end

  defp do_write(:discard, _data), do: :ok

  defp do_write(pid, data) when is_pid(pid) do
    send(pid, {:terminal_output, IO.iodata_to_binary(data)})
    :ok
  end
end
