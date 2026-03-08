defmodule TinctTest do
  use ExUnit.Case, async: true
  doctest Tinct

  defmodule RunComponent do
    @moduledoc false

    use Tinct.Component

    @impl true
    def init(_opts), do: %{}

    @impl true
    def update(model, %Tinct.Event.Key{key: "q"}), do: Tinct.quit(model)
    def update(model, _msg), do: model

    @impl true
    def view(_model) do
      Tinct.View.new(Tinct.Element.text("ok"))
    end
  end

  test "quit/1 returns model and :quit command" do
    {model, cmd} = Tinct.quit(%{count: 1})
    assert model == %{count: 1}
    assert cmd == :quit
  end

  test "run/2 (test_mode) starts a supervisor and unblocks on quit" do
    task =
      Task.async(fn ->
        Tinct.run(RunComponent, test_mode: true, size: {10, 2})
      end)

    app_pid = wait_for_registered!(Tinct.App.Supervisor.app_name(RunComponent))

    send(app_pid, {:event, Tinct.Event.key("q")})

    assert Task.await(task, 2_000) == :ok
  end

  defp wait_for_registered!(name) do
    case Enum.reduce_while(1..100, nil, fn _, _ ->
           case Process.whereis(name) do
             nil ->
               Process.sleep(10)
               {:cont, nil}

             pid ->
               {:halt, pid}
           end
         end) do
      nil ->
        flunk("Expected process #{inspect(name)} to be registered")

      pid ->
        pid
    end
  end
end
