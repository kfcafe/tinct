defmodule Tinct.Event.Reader do
  @moduledoc """
  GenServer that reads terminal input and emits parsed events.

  Continuously reads from stdin (or a test source) and sends parsed
  `Tinct.Event.*` structs to a target process. Handles buffering of
  incomplete escape sequences across reads.

  ## Usage

      {:ok, reader} = Tinct.Event.Reader.start_link(target: self())

  Events are sent as `{:event, event}` messages to the target process.

  ## Testing

  For tests, use `input_mode: {:test, self()}` and send simulated input:

      {:ok, reader} = Tinct.Event.Reader.start_link(
        target: self(),
        input_mode: {:test, self()}
      )
      send(reader, {:test_input, "\\e[A"})
      assert_receive {:event, %Tinct.Event.Key{key: :up}}
  """

  use GenServer

  alias Tinct.Event.Parser

  @type t :: %__MODULE__{
          target: pid() | atom(),
          remainder: binary(),
          input_mode: :stdio | {:test, pid()},
          active: boolean(),
          port: port() | nil
        }

  defstruct target: nil,
            remainder: <<>>,
            input_mode: :stdio,
            active: true,
            port: nil

  # --- Client API ---

  @doc """
  Starts the event reader.

  ## Options

    * `:target` (required) — pid to send `{:event, event}` messages to
    * `:input_mode` — `:stdio` (default) or `{:test, pid}` for testing

  ## Examples

      {:ok, reader} = Tinct.Event.Reader.start_link(target: self())
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Stops the reader gracefully.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(reader) do
    GenServer.stop(reader)
  end

  # --- Server callbacks ---

  @impl true
  def init(opts) do
    target = Keyword.fetch!(opts, :target)
    mode = Keyword.get(opts, :input_mode, :stdio)
    state = %__MODULE__{target: target, input_mode: mode}

    case mode do
      :stdio ->
        # Open stdin (fd 0) as a Port to bypass Erlang's IO protocol server.
        # The IO server has its own line-buffering that ignores stty raw mode.
        # A Port on fd 0 delivers raw bytes asynchronously via messages.
        port = Port.open({:fd, 0, 1}, [:binary, :eof])
        {:ok, %{state | port: port}}

      {:test, _pid} ->
        {:ok, state}
    end
  end

  # Port delivers stdin data asynchronously as messages
  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    state = process_input(state, data)
    {:noreply, state}
  end

  def handle_info({port, :eof}, %{port: port} = state) do
    {:noreply, %{state | active: false}}
  end

  @impl true
  def handle_info({:test_input, data}, %{input_mode: {:test, _}} = state) do
    state = process_input(state, data)
    {:noreply, state}
  end

  def handle_info(:eof, state) do
    {:noreply, %{state | active: false}}
  end

  # --- Private ---

  @spec process_input(t(), binary()) :: t()
  defp process_input(state, data) do
    {events, remainder} = Parser.parse(state.remainder <> data)
    for event <- events, do: send(state.target, {:event, event})
    %{state | remainder: remainder}
  end

  @impl true
  def terminate(_reason, %{port: port}) when port != nil do
    try do
      Port.close(port)
    catch
      _, _ -> :ok
    end

    :ok
  end

  def terminate(_reason, _state), do: :ok
end
