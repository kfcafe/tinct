defmodule Tinct.Command do
  @moduledoc """
  Commands represent side effects returned from component `update/2` callbacks.

  Instead of performing side effects directly, components return commands
  alongside their updated model. The runtime executes these commands and
  delivers results back as messages.

  ## Command Types

    * `nil` — no side effect (returned by `none/0`)
    * `{:async, fun, reply_tag}` — run a zero-arity function asynchronously,
      wrap the result in `{reply_tag, result}` and send it back as a message
    * `{:batch, commands}` — execute multiple commands
    * `:quit` — signal the runtime to shut down

  ## Examples

      # No side effect
      {model, Command.none()}

      # Async HTTP request
      {model, Command.async(fn -> HTTPClient.get(url) end, :http_response)}

      # Multiple commands
      {model, Command.batch([
        Command.async(fn -> fetch_data() end, :data),
        Command.async(fn -> fetch_config() end, :config)
      ])}

      # Quit the application
      {model, Command.quit()}
  """

  @typedoc "A command describing a side effect for the runtime to execute."
  @type t ::
          nil
          | {:async, (-> term()), reply_tag :: term()}
          | {:batch, [t()]}
          | :quit

  @doc """
  Creates an async command that runs `fun` in the background.

  When the function completes, its return value is wrapped as
  `{reply_tag, result}` and delivered to the component's `update/2`.

  ## Examples

      iex> cmd = Tinct.Command.async(fn -> 42 end, :answer)
      iex> match?({:async, _fun, :answer}, cmd)
      true
  """
  @spec async((-> term()), reply_tag :: term()) :: t()
  def async(fun, reply_tag) when is_function(fun, 0) do
    {:async, fun, reply_tag}
  end

  @doc """
  Returns a no-op command (nil). Indicates no side effects.

  ## Examples

      iex> Tinct.Command.none()
      nil
  """
  @spec none() :: nil
  def none, do: nil

  @doc """
  Batches multiple commands into a single command, filtering out nils.

  ## Examples

      iex> Tinct.Command.batch([nil, nil])
      {:batch, []}

      iex> cmd = Tinct.Command.batch([Tinct.Command.quit(), nil, Tinct.Command.quit()])
      iex> cmd
      {:batch, [:quit, :quit]}
  """
  @spec batch([t()]) :: t()
  def batch(commands) when is_list(commands) do
    {:batch, Enum.reject(commands, &is_nil/1)}
  end

  @doc """
  Returns a quit command, signaling the runtime to shut down.

  ## Examples

      iex> Tinct.Command.quit()
      :quit
  """
  @spec quit() :: t()
  def quit, do: :quit
end
