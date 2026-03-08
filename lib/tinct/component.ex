defmodule Tinct.Component do
  @moduledoc """
  Behaviour that all Tinct components implement.

  A component is a module that manages state (the model), responds to messages
  via `update/2`, and renders itself via `view/1`. This follows The Elm
  Architecture: init → update → view.

  ## Using this module

  Add `use Tinct.Component` to your module to declare it as a component:

      defmodule MyApp.Counter do
        use Tinct.Component

        @impl Tinct.Component
        def init(_opts), do: 0

        @impl Tinct.Component
        def update(count, :increment), do: count + 1
        def update(count, _msg), do: count

        @impl Tinct.Component
        def view(count) do
          Tinct.View.new(Tinct.Element.text("Count: \#{count}"))
        end
      end

  ## Required callbacks

    * `init/1` — initialize the model from options
    * `update/2` — handle a message and return the new model (optionally with a command)
    * `view/1` — render the model as a `Tinct.View.t()`

  ## Optional callbacks

    * `subscriptions/1` — return a list of subscriptions based on the current model (default: `[]`)
    * `handle_tick/1` — handle a tick event, return the updated model (default: identity)

  ## Update return types

  The `update/2` callback can return:

    * `model` — just the new model, no side effects
    * `{model, command}` — model with a `Tinct.Command.t()` to execute
  """

  @doc "Initialize the component model from the given options."
  @callback init(opts :: keyword()) :: model :: term()

  @doc "Handle a message and return the updated model, optionally with a command."
  @callback update(model :: term(), msg :: term()) ::
              model :: term() | {model :: term(), Tinct.Command.t()}

  @doc "Render the current model as a declarative view."
  @callback view(model :: term()) :: Tinct.View.t()

  @doc "Return a list of subscriptions based on the current model."
  @callback subscriptions(model :: term()) :: [subscription :: term()]

  @doc "Handle a tick event and return the updated model."
  @callback handle_tick(model :: term()) :: model :: term()

  @optional_callbacks subscriptions: 1, handle_tick: 1

  @doc """
  Normalizes the return value from `update/2` into a `{model, command}` tuple.

  If the callback returned just a model (not a tuple), wraps it as
  `{model, nil}`. If it returned `{model, command}`, passes it through.

  ## Examples

      iex> Tinct.Component.normalize_update_result(42)
      {42, nil}

      iex> Tinct.Component.normalize_update_result({42, :quit})
      {42, :quit}
  """
  @spec normalize_update_result(term()) :: {term(), Tinct.Command.t()}
  def normalize_update_result({model, cmd}), do: {model, cmd}
  def normalize_update_result(model), do: {model, nil}

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Tinct.Component

      @impl Tinct.Component
      def subscriptions(_model), do: []

      @impl Tinct.Component
      def handle_tick(model), do: model

      @doc false
      def __tinct_component__, do: true

      defoverridable subscriptions: 1, handle_tick: 1
    end
  end
end
