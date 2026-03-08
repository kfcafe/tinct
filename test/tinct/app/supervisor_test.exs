defmodule Tinct.App.SupervisorTest do
  use ExUnit.Case, async: true

  alias Tinct.App.Supervisor, as: AppSupervisor

  defmodule Counter do
    @moduledoc false
    use Tinct.Component

    @impl true
    def init(_opts), do: %{count: 0}

    @impl true
    def update(model, _msg), do: model

    @impl true
    def view(_model), do: Tinct.View.new(Tinct.Element.text("test"))
  end

  defmodule RunCounter do
    @moduledoc false
    use Tinct.Component

    @impl true
    def init(_opts), do: %{count: 0}

    @impl true
    def update(model, _msg), do: model

    @impl true
    def view(_model), do: Tinct.View.new(Tinct.Element.text("run test"))
  end

  describe "start_link/1" do
    test "starts all children in test mode" do
      {:ok, sup} =
        AppSupervisor.start_link(component: Counter, test_mode: true, size: {80, 24})

      children = Supervisor.which_children(sup)
      assert length(children) == 4

      for {_id, pid, _type, _modules} <- children do
        assert is_pid(pid)
        assert Process.alive?(pid)
      end

      Supervisor.stop(sup)
    end

    test "stops cleanly" do
      {:ok, sup} =
        AppSupervisor.start_link(component: Counter, test_mode: true, size: {80, 24})

      app_pid = Process.whereis(AppSupervisor.app_name(Counter))
      assert is_pid(app_pid)
      assert Process.alive?(sup)

      Supervisor.stop(sup)

      refute Process.alive?(sup)
      Process.sleep(50)
      refute Process.alive?(app_pid)
    end
  end

  describe "rest_for_one strategy" do
    test "killing reader restarts app" do
      {:ok, sup} =
        AppSupervisor.start_link(component: Counter, test_mode: true, size: {80, 24})

      app_name = AppSupervisor.app_name(Counter)
      original_app_pid = Process.whereis(app_name)
      assert is_pid(original_app_pid)
      ref = Process.monitor(original_app_pid)

      children = Supervisor.which_children(sup)

      {_, reader_pid, _, _} =
        Enum.find(children, fn {id, _, _, _} -> id == Tinct.Event.Reader end)

      Process.exit(reader_pid, :kill)

      assert_receive {:DOWN, ^ref, :process, ^original_app_pid, _reason}, 1000
      Process.sleep(50)

      new_app_pid = Process.whereis(app_name)
      assert is_pid(new_app_pid)
      assert new_app_pid != original_app_pid

      Supervisor.stop(sup)
    end
  end

  describe "Tinct.run/2" do
    test "starts with test mode and stops when supervisor terminates" do
      task =
        Task.async(fn ->
          Tinct.run(RunCounter, test_mode: true, size: {80, 24}, name: __MODULE__.RunSup)
        end)

      Process.sleep(100)

      app_pid = Process.whereis(AppSupervisor.app_name(RunCounter))
      assert is_pid(app_pid)

      sup = Process.whereis(__MODULE__.RunSup)
      assert is_pid(sup)

      Supervisor.stop(sup)

      assert Task.await(task, 1000) == :ok
    end
  end

  describe "Tinct.quit/1" do
    test "returns model with quit command" do
      model = %{count: 42}
      assert {%{count: 42}, :quit} = Tinct.quit(model)
    end
  end
end
