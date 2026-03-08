defmodule Tinct.AppTest do
  use ExUnit.Case, async: true

  alias Tinct.App
  alias Tinct.Command
  alias Tinct.Cursor
  alias Tinct.Event
  alias Tinct.Event.Key
  alias Tinct.Event.Reader
  alias Tinct.Event.Resize
  alias Tinct.Terminal.Capabilities

  defmodule CounterComponent do
    @moduledoc false
    use Tinct.Component

    @impl true
    def init(opts) do
      start = Keyword.get(opts, :start, 0)

      default_view_opts = %{
        content_nil: false,
        alt_screen: true,
        mouse_mode: nil,
        bracketed_paste: true,
        report_focus: false,
        title: nil,
        cursor: nil
      }

      %{
        count: start,
        async_value: nil,
        async_errors: [],
        view_opts: Map.merge(default_view_opts, Keyword.get(opts, :view_opts, %{}))
      }
    end

    @impl true
    def update(model, %Key{key: "+"}) do
      %{model | count: model.count + 1}
    end

    def update(model, %Key{key: "a"}) do
      {model, Command.async(fn -> 42 end, :answer)}
    end

    def update(model, {:answer, value}) do
      %{model | async_value: value}
    end

    def update(model, :run_async_failures) do
      {model,
       {:batch,
        [
          Command.async(fn -> raise "boom" end, :raised),
          Command.async(fn -> throw(:thrown) end, :thrown),
          :unknown_command
        ]}}
    end

    def update(model, {:raised, result}) do
      %{model | async_errors: [{:raised, result} | model.async_errors]}
    end

    def update(model, {:thrown, result}) do
      %{model | async_errors: [{:thrown, result} | model.async_errors]}
    end

    def update(model, {:set_view_opts, opts}) when is_list(opts) do
      %{model | view_opts: Map.merge(model.view_opts, Map.new(opts))}
    end

    def update(model, :unknown_command_event) do
      {model, :mystery}
    end

    def update(model, %Key{key: "q"}) do
      Tinct.quit(model)
    end

    def update(model, _msg), do: model

    @impl true
    def view(model) do
      content =
        if model.view_opts.content_nil do
          nil
        else
          Tinct.Element.text("Count: #{model.count} Async: #{inspect(model.async_value)}")
        end

      %Tinct.View{
        content: content,
        cursor: model.view_opts.cursor,
        alt_screen: model.view_opts.alt_screen,
        mouse_mode: model.view_opts.mouse_mode,
        title: model.view_opts.title,
        report_focus: model.view_opts.report_focus,
        bracketed_paste: model.view_opts.bracketed_paste,
        keyboard_enhancements: []
      }
    end
  end

  defp receive_initial_render! do
    assert_receive {:terminal_output, output}, 500
    output
  end

  defp receive_output! do
    assert_receive {:terminal_output, output}, 500
    output
  end

  describe "runtime loop" do
    setup do
      writer = start_supervised!({Tinct.Terminal.Writer, output: self()})
      task_supervisor = start_supervised!({Task.Supervisor, []})

      app =
        start_supervised!(
          {App,
           component: CounterComponent,
           init_opts: [start: 0],
           writer: writer,
           task_supervisor: task_supervisor,
           reader_mode: {:test, self()},
           size: {20, 3}}
        )

      %{app: app}
    end

    test "initial render produces output", %{app: _app} do
      output = receive_initial_render!()
      assert is_binary(output)
      assert byte_size(output) > 0
    end

    test "initial render hides cursor when view does not set one", %{app: _app} do
      output = receive_initial_render!()
      assert output =~ "\e[?25l"
    end

    test "initial render enables unicode width mode when supported" do
      writer =
        start_supervised!(%{
          id: :unicode_writer,
          start: {Tinct.Terminal.Writer, :start_link, [[output: self()]]}
        })

      task_supervisor =
        start_supervised!(%{
          id: :unicode_task_supervisor,
          start: {Task.Supervisor, :start_link, [[]]}
        })

      capabilities =
        Capabilities.detect(%{"TERM_PROGRAM" => "ghostty", "TERM" => "xterm-256color", tty: true})

      _app =
        start_supervised!(%{
          id: :unicode_app,
          start:
            {App, :start_link,
             [
               [
                 component: CounterComponent,
                 init_opts: [start: 0],
                 writer: writer,
                 task_supervisor: task_supervisor,
                 capabilities: capabilities,
                 size: {20, 3}
               ]
             ]}
        })

      output = receive_initial_render!()
      assert output =~ "\e[?2027h"
    end

    test "sending a key event triggers update + re-render", %{app: app} do
      _output = receive_initial_render!()

      send(app, {:event, Event.key("+")})
      _output = receive_output!()

      assert %{model: %{count: 1}} = :sys.get_state(app)
    end

    test "async command result triggers update", %{app: app} do
      _output = receive_initial_render!()

      send(app, {:event, Event.key("a")})
      _output = receive_output!()

      _output = receive_output!()

      assert %{model: %{async_value: 42}} = :sys.get_state(app)
    end

    test "batch commands safely handle raised and thrown async functions", %{app: app} do
      _output = receive_initial_render!()

      send(app, {:event, :run_async_failures})

      _output = receive_output!()
      _output = receive_output!()
      _output = receive_output!()

      assert %{model: %{async_errors: async_errors}} = :sys.get_state(app)

      assert Enum.any?(async_errors, fn
               {:raised, {:error, {:exception, %RuntimeError{message: "boom"}, _stacktrace}}} ->
                 true

               _ ->
                 false
             end)

      assert Enum.any?(async_errors, fn
               {:thrown, {:error, {:throw, :thrown}}} -> true
               _ -> false
             end)
    end

    test "quit command stops the app", %{app: app} do
      _output = receive_initial_render!()

      ref = Process.monitor(app)

      send(app, {:event, Event.key("q")})

      assert_receive {:DOWN, ^ref, :process, ^app, :normal}, 1000
      refute Process.alive?(app)
    end

    test "stop/1 stops the app", %{app: app} do
      _output = receive_initial_render!()
      ref = Process.monitor(app)

      assert :ok = App.stop(app)

      assert_receive {:DOWN, ^ref, :process, ^app, :normal}, 1000
    end

    test "resize event tuple updates size", %{app: app} do
      _output = receive_initial_render!()

      send(app, {:resize, 77, 22})
      _output = receive_output!()

      assert %{size: {77, 22}} = :sys.get_state(app)
    end

    test "resize struct triggers re-render at new size", %{app: app} do
      _output = receive_initial_render!()

      send(app, {:event, %Resize{width: 100, height: 50}})
      _output = receive_output!()

      assert %{size: {100, 50}} = :sys.get_state(app)
    end

    test "unknown messages are ignored", %{app: app} do
      _output = receive_initial_render!()

      send(app, :this_message_is_ignored)

      refute_receive {:terminal_output, _}, 100
      assert Process.alive?(app)
    end

    test "view state transitions emit expected terminal control sequences", %{app: app} do
      _output = receive_initial_render!()

      send(
        app,
        {:event,
         {:set_view_opts,
          [
            alt_screen: false,
            mouse_mode: :cell_motion,
            bracketed_paste: false,
            report_focus: true,
            title: "Branch coverage",
            cursor: Cursor.new(2, 1, shape: :bar)
          ]}}
      )

      output = receive_output!()
      assert output =~ "\e[?1049l"
      assert output =~ "\e[?1002h\e[?1006h"
      assert output =~ "\e[?2004l"
      assert output =~ "\e[?1004h"
      assert output =~ "\e]0;Branch coverage\a"
      assert output =~ "\e[?25h"
      assert output =~ "\e[6 q"
      assert output =~ "\e[2;3H"

      send(
        app,
        {:event,
         {:set_view_opts, [mouse_mode: :all_motion, cursor: Cursor.new(2, 1, blink: true)]}}
      )

      output = receive_output!()
      assert output =~ "\e[?1003h\e[?1006h"

      send(
        app,
        {:event,
         {:set_view_opts,
          [
            mouse_mode: nil,
            report_focus: false,
            title: nil,
            cursor: Cursor.new(2, 1, visible: false)
          ]}}
      )

      output = receive_output!()
      assert output =~ "\e[?1002l\e[?1006l"
      assert output =~ "\e[?1004l"
      assert output =~ "\e[?25l"
    end

    test "views with nil content render an empty buffer", %{app: app} do
      _output = receive_initial_render!()

      send(app, {:event, {:set_view_opts, [content_nil: true]}})
      output = receive_output!()

      assert is_binary(output)
      assert byte_size(output) > 0
      assert %{model: %{view_opts: %{content_nil: true}}} = :sys.get_state(app)
    end

    test "multiple rapid events are all processed", %{app: app} do
      _output = receive_initial_render!()

      for _ <- 1..10 do
        send(app, {:event, Event.key("+")})
      end

      for _ <- 1..10 do
        _output = receive_output!()
      end

      assert %{model: %{count: 10}} = :sys.get_state(app)
    end
  end

  describe "boot behavior and callbacks" do
    test "starts internal writer and task supervisor when not provided" do
      capabilities = %Capabilities{unicode_width: false, mouse: true, bracketed_paste: true}

      app =
        start_supervised!(
          {App,
           component: CounterComponent,
           init_opts: [start: 0],
           writer_output: self(),
           start_reader: false,
           capabilities: capabilities,
           size: {20, 3}}
        )

      output = receive_initial_render!()
      refute output =~ "\e[?2027h"

      assert %{writer: writer, task_supervisor: task_supervisor, reader: nil} =
               :sys.get_state(app)

      assert is_pid(writer)
      assert is_pid(task_supervisor)
    end

    test "starts reader when start_reader is explicitly true" do
      writer =
        start_supervised!(%{
          id: :forced_reader_writer,
          start: {Tinct.Terminal.Writer, :start_link, [[output: self()]]}
        })

      task_supervisor =
        start_supervised!(%{
          id: :forced_reader_task_supervisor,
          start: {Task.Supervisor, :start_link, [[]]}
        })

      app =
        start_supervised!(%{
          id: :forced_reader_app,
          start:
            {App, :start_link,
             [
               [
                 component: CounterComponent,
                 writer: writer,
                 task_supervisor: task_supervisor,
                 reader_mode: {:test, self()},
                 start_reader: true,
                 size: {20, 3}
               ]
             ]}
        })

      _output = receive_initial_render!()

      assert %{reader: reader} = :sys.get_state(app)
      assert is_pid(reader)
      assert Process.alive?(reader)
    end

    test "reuses provided reader process" do
      writer =
        start_supervised!(%{
          id: :provided_reader_writer,
          start: {Tinct.Terminal.Writer, :start_link, [[output: self()]]}
        })

      task_supervisor =
        start_supervised!(%{
          id: :provided_reader_task_supervisor,
          start: {Task.Supervisor, :start_link, [[]]}
        })

      {:ok, reader} = Reader.start_link(target: self(), input_mode: {:test, self()})

      app =
        start_supervised!(%{
          id: :provided_reader_app,
          start:
            {App, :start_link,
             [
               [
                 component: CounterComponent,
                 writer: writer,
                 task_supervisor: task_supervisor,
                 reader: reader,
                 size: {20, 3}
               ]
             ]}
        })

      _output = receive_initial_render!()

      assert %{reader: ^reader} = :sys.get_state(app)
      assert Process.alive?(reader)
    end

    test "callbacks are safe for manual invocation" do
      state = %App{}

      assert {:stop, :normal, ^state} = App.handle_info(:quit, state)
      assert {:noreply, ^state} = App.handle_info(:unexpected_message, state)

      assert :ok = App.terminate(:normal, state)
      assert :ok = App.terminate(:normal, %App{writer: :missing_writer})
    end
  end
end
