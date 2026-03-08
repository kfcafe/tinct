defmodule Tinct.App do
  @moduledoc """
  Central GenServer that runs a component's update → view → render loop.

  The App receives `{:event, event}` messages (typically from `Tinct.Event.Reader`),
  calls the component's `update/2`, executes any returned `Tinct.Command`, and
  re-renders the component's `Tinct.View` to the terminal via
  `Tinct.Terminal.Writer`.

  ## Process topology

  In normal operation, `Tinct.App` is started by `Tinct.App.Supervisor`, which
  starts a `Task.Supervisor`, `Tinct.Terminal.Writer`, and `Tinct.Event.Reader`
  as siblings.

  For direct usage (and tests), `Tinct.App` can also start its own Writer,
  Reader, and Task supervisor when they are not provided.

  ## Testing

  Provide:

    * `writer: writer_pid` — a `Tinct.Terminal.Writer` configured with
      `output: self()`
    * `task_supervisor: task_sup_pid` — a `Task.Supervisor`
    * `reader_mode: {:test, self()}` — to have the App start a Reader in test
      mode (optional)

  This avoids real terminal I/O.
  """

  use GenServer

  alias Tinct.ANSI
  alias Tinct.Buffer
  alias Tinct.Buffer.Diff
  alias Tinct.Component
  alias Tinct.Cursor
  alias Tinct.Event.Reader
  alias Tinct.Event.Resize
  alias Tinct.Layout
  alias Tinct.Overlay
  alias Tinct.Terminal.Capabilities
  alias Tinct.Terminal.Writer
  alias Tinct.Theme
  alias Tinct.View

  @typedoc "Terminal dimensions as {cols, rows}."
  @type size :: {pos_integer(), pos_integer()}

  @typedoc "App GenServer state."
  @type t :: %__MODULE__{
          component: module(),
          model: term(),
          previous_view: View.t() | nil,
          previous_buffer: Buffer.t() | nil,
          theme: Theme.t(),
          capabilities: Capabilities.t(),
          writer: GenServer.server(),
          reader: pid() | nil,
          task_supervisor: GenServer.server(),
          size: size()
        }

  defstruct component: nil,
            model: nil,
            previous_view: nil,
            previous_buffer: nil,
            theme: nil,
            capabilities: nil,
            writer: nil,
            reader: nil,
            task_supervisor: nil,
            size: {80, 24}

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the App GenServer.

  ## Options

    * `:component` (required) — a module implementing `Tinct.Component`
    * `:init_opts` — options passed to `component.init/1` (default `[]`)
    * `:name` — optional registered name

    * `:size` — fixed terminal size `{cols, rows}` (default `{80, 24}`)
    * `:theme` — `Tinct.Theme.t()` (default `Tinct.Theme.default/0`)
    * `:capabilities` — override detected capabilities (useful for tests)

    * `:writer` — an existing `Tinct.Terminal.Writer` server (pid/name). If not
      provided, a writer is started.
    * `:writer_output` — when starting an internal writer, where it writes:
      `:stdio` (default) or a pid (for tests)

    * `:task_supervisor` — an existing `Task.Supervisor` (pid/name). If not
      provided, one is started.

    * `:reader` — an existing `Tinct.Event.Reader` pid. If not provided, a
      reader may be started depending on `:reader_mode` / `:start_reader`.
    * `:reader_mode` — passed as `input_mode` when starting an internal reader
      (`:stdio` or `{:test, pid}`)
    * `:start_reader` — force starting an internal reader (default: `true` only
      when neither `:writer` nor `:task_supervisor` were provided)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) when is_list(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Stops the App GenServer.

  This does not attempt to stop externally-managed Writer/Reader/Task supervisor
  processes.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(app) do
    GenServer.stop(app, :normal)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    component = Keyword.fetch!(opts, :component)
    init_opts = Keyword.get(opts, :init_opts, [])

    size = Keyword.get(opts, :size, {80, 24})
    theme = Keyword.get(opts, :theme, Theme.default())

    capabilities =
      case Keyword.get(opts, :capabilities) do
        %Capabilities{} = caps -> caps
        nil -> Capabilities.detect()
      end

    model = component.init(init_opts)

    state = %__MODULE__{
      component: component,
      model: model,
      previous_view: nil,
      previous_buffer: nil,
      theme: theme,
      capabilities: capabilities,
      writer: Keyword.get(opts, :writer),
      reader: Keyword.get(opts, :reader),
      task_supervisor: Keyword.get(opts, :task_supervisor),
      size: size
    }

    {:ok, state, {:continue, {:boot, opts}}}
  end

  @impl true
  def handle_continue({:boot, opts}, state) do
    state = ensure_task_supervisor_started(state)
    state = ensure_writer_started(state, opts)
    state = ensure_reader_started(state, opts)

    state = render(state)

    {:noreply, state}
  end

  @impl true
  def handle_info(:quit, state) do
    # Stop the entire supervision tree so Tinct.run unblocks.
    # $ancestors is set by OTP — the first entry is our immediate supervisor.
    # Spawn the stop call so we don't block our own shutdown.
    case Process.get(:"$ancestors", []) do
      [supervisor | _] ->
        spawn(fn -> Supervisor.stop(supervisor, :normal) end)

      [] ->
        :ok
    end

    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:resize, width, height}, state)
      when is_integer(width) and is_integer(height) and width >= 0 and height >= 0 do
    resize = %Resize{width: width, height: height}
    state = process_message(state, resize)
    {:noreply, state}
  end

  @impl true
  def handle_info({:event, %Resize{width: width, height: height} = resize}, state)
      when is_integer(width) and is_integer(height) and width >= 0 and height >= 0 do
    state = process_message(state, resize)
    {:noreply, state}
  end

  @impl true
  def handle_info({:event, event}, state) do
    state = process_message(state, event)
    {:noreply, state}
  end

  @impl true
  def handle_info({:async_result, tag, result}, state) do
    state = process_message(state, {tag, result})
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %__MODULE__{} = state) do
    reset_terminal_state(state)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Boot helpers
  # ---------------------------------------------------------------------------

  defp ensure_task_supervisor_started(%__MODULE__{task_supervisor: nil} = state) do
    {:ok, pid} = Task.Supervisor.start_link([])
    %{state | task_supervisor: pid}
  end

  defp ensure_task_supervisor_started(%__MODULE__{} = state), do: state

  defp ensure_writer_started(%__MODULE__{writer: nil} = state, opts) do
    output = Keyword.get(opts, :writer_output, :stdio)

    {:ok, pid} =
      Writer.start_link(
        output: output,
        sync_rendering: state.capabilities.sync_rendering
      )

    %{state | writer: pid}
  end

  defp ensure_writer_started(%__MODULE__{} = state, _opts), do: state

  defp ensure_reader_started(%__MODULE__{reader: nil} = state, opts) do
    if should_start_reader?(opts) do
      input_mode = Keyword.get(opts, :reader_mode, :stdio)
      {:ok, pid} = Reader.start_link(target: self(), input_mode: input_mode)
      %{state | reader: pid}
    else
      state
    end
  end

  defp ensure_reader_started(%__MODULE__{} = state, _opts), do: state

  defp should_start_reader?(opts) do
    cond do
      Keyword.get(opts, :start_reader) == true ->
        true

      Keyword.get(opts, :start_reader) == false ->
        false

      Keyword.has_key?(opts, :reader_mode) ->
        true

      true ->
        Keyword.get(opts, :writer) == nil and Keyword.get(opts, :task_supervisor) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Event/update/render pipeline
  # ---------------------------------------------------------------------------

  defp process_message(%__MODULE__{} = state, %Resize{width: width, height: height} = msg) do
    # Update size first so component.update/2 can react based on the new size.
    state = %{state | size: {width, height}}
    process_message(state, {:component_msg, msg})
  end

  defp process_message(%__MODULE__{} = state, {:component_msg, msg}) do
    {model, cmd} = Component.normalize_update_result(state.component.update(state.model, msg))

    state = %{state | model: model}

    execute_command(cmd, state)

    render(state)
  end

  defp process_message(%__MODULE__{} = state, msg) do
    {model, cmd} = Component.normalize_update_result(state.component.update(state.model, msg))

    state = %{state | model: model}

    execute_command(cmd, state)

    render(state)
  end

  # ---------------------------------------------------------------------------
  # Command execution
  # ---------------------------------------------------------------------------

  defp execute_command(nil, _state), do: :ok

  defp execute_command(:quit, _state) do
    send(self(), :quit)
    :ok
  end

  defp execute_command({:batch, commands}, state) when is_list(commands) do
    Enum.each(commands, &execute_command(&1, state))
    :ok
  end

  defp execute_command({:async, fun, tag}, %__MODULE__{} = state)
       when is_function(fun, 0) do
    app_pid = self()

    Task.Supervisor.start_child(state.task_supervisor, fn ->
      result = safe_call(fun)
      send(app_pid, {:async_result, tag, result})
    end)

    :ok
  end

  defp execute_command(_unknown, _state), do: :ok

  defp safe_call(fun) do
    fun.()
  rescue
    e -> {:error, {:exception, e, __STACKTRACE__}}
  catch
    kind, value -> {:error, {kind, value}}
  end

  # ---------------------------------------------------------------------------
  # Rendering
  # ---------------------------------------------------------------------------

  defp render(%__MODULE__{} = state) do
    view = state.component.view(state.model)
    buffer = render_view_to_buffer(view, state.size, state.theme)

    output =
      state.previous_buffer
      |> diff_output(buffer)
      |> wrap_with_view_state_changes(state.previous_view, view, state.capabilities)

    if state.writer do
      :ok = Writer.write_and_flush(state.writer, output)
    end

    %{state | previous_view: view, previous_buffer: buffer}
  end

  defp render_view_to_buffer(%View{content: nil, overlays: overlays}, {cols, rows}, theme) do
    Buffer.new(cols, rows)
    |> Overlay.render_overlays(overlays, theme)
  end

  defp render_view_to_buffer(
         %View{content: content, overlays: overlays},
         {cols, rows},
         %Theme{} = theme
       ) do
    Layout.render(content, {cols, rows}, theme)
    |> Overlay.render_overlays(overlays, theme)
  end

  defp diff_output(nil, %Buffer{} = buffer), do: Diff.full_render(buffer)

  defp diff_output(%Buffer{} = previous, %Buffer{} = buffer) do
    Diff.diff(previous, buffer)
  end

  defp wrap_with_view_state_changes(render_output, previous_view, %View{} = view, capabilities) do
    state_changes = view_state_changes(previous_view, view, capabilities)
    [state_changes, render_output]
  end

  defp view_state_changes(nil, %View{} = view, %Capabilities{} = capabilities) do
    # On the first frame, assume the terminal is in a "baseline" state
    # (no alt screen, no mouse tracking, no bracketed paste, cursor visible).
    baseline = %View{
      alt_screen: false,
      mouse_mode: nil,
      bracketed_paste: false,
      cursor: Cursor.new(0, 0)
    }

    [
      maybe_enable_unicode_width(capabilities),
      view_state_changes(baseline, view, capabilities)
    ]
  end

  defp view_state_changes(%View{} = previous, %View{} = current, %Capabilities{} = capabilities) do
    [
      alt_screen_changes(previous, current),
      mouse_changes(previous, current, capabilities),
      bracketed_paste_changes(previous, current, capabilities),
      focus_changes(previous, current),
      title_changes(previous, current),
      cursor_changes(previous, current)
    ]
  end

  defp alt_screen_changes(%View{alt_screen: false}, %View{alt_screen: true}) do
    [ANSI.enter_alt_screen(), ANSI.clear_screen(), ANSI.move_to(0, 0)]
  end

  defp alt_screen_changes(%View{alt_screen: true}, %View{alt_screen: false}) do
    [ANSI.exit_alt_screen(), ANSI.clear_screen(), ANSI.move_to(0, 0)]
  end

  defp alt_screen_changes(_previous, _current), do: []

  defp mouse_changes(%View{mouse_mode: prev}, %View{mouse_mode: prev}, _capabilities), do: []

  defp mouse_changes(_previous, %View{mouse_mode: nil}, %Capabilities{mouse: true}) do
    ANSI.disable_mouse()
  end

  defp mouse_changes(_previous, %View{mouse_mode: :cell_motion}, %Capabilities{mouse: true}) do
    [ANSI.disable_mouse(), ANSI.enable_mouse_cell()]
  end

  defp mouse_changes(_previous, %View{mouse_mode: :all_motion}, %Capabilities{mouse: true}) do
    [ANSI.disable_mouse(), ANSI.enable_mouse_all()]
  end

  defp mouse_changes(_previous, _current, %Capabilities{mouse: false}), do: []

  defp bracketed_paste_changes(%View{bracketed_paste: prev}, %View{bracketed_paste: prev}, _caps),
    do: []

  defp bracketed_paste_changes(_previous, %View{bracketed_paste: true}, %Capabilities{
         bracketed_paste: true
       }),
       do: ANSI.enable_bracketed_paste()

  defp bracketed_paste_changes(_previous, %View{bracketed_paste: false}, %Capabilities{
         bracketed_paste: true
       }),
       do: ANSI.disable_bracketed_paste()

  defp bracketed_paste_changes(_previous, _current, %Capabilities{bracketed_paste: false}), do: []

  defp maybe_enable_unicode_width(%Capabilities{unicode_width: true}) do
    ANSI.enable_unicode_width()
  end

  defp maybe_enable_unicode_width(%Capabilities{unicode_width: false}), do: []

  defp focus_changes(%View{report_focus: prev}, %View{report_focus: prev}), do: []
  defp focus_changes(_previous, %View{report_focus: true}), do: "\e[?1004h"
  defp focus_changes(_previous, %View{report_focus: false}), do: "\e[?1004l"

  defp title_changes(%View{title: prev}, %View{title: prev}), do: []
  defp title_changes(_previous, %View{title: nil}), do: []
  defp title_changes(_previous, %View{title: title}) when is_binary(title), do: set_title(title)

  defp set_title(title) when is_binary(title) do
    # OSC 0 ; title BEL
    ["\e]0;", title, "\a"]
  end

  defp cursor_changes(%View{cursor: prev_cursor}, %View{cursor: prev_cursor}), do: []

  defp cursor_changes(_previous, %View{cursor: nil}) do
    ANSI.hide_cursor()
  end

  defp cursor_changes(_previous, %View{cursor: %{visible: false}}) do
    ANSI.hide_cursor()
  end

  defp cursor_changes(%View{cursor: prev}, %View{cursor: current}) when is_map(current) do
    changes = []

    changes =
      if prev == nil or (is_map(prev) and Map.get(prev, :visible, true) == false) do
        [changes, ANSI.show_cursor()]
      else
        changes
      end

    changes =
      if prev == nil or Map.get(prev, :shape) != Map.get(current, :shape) do
        [changes, ANSI.cursor_shape(Map.fetch!(current, :shape))]
      else
        changes
      end

    if prev == nil or Map.get(prev, :x) != Map.get(current, :x) or
         Map.get(prev, :y) != Map.get(current, :y) do
      [changes, ANSI.move_to(Map.fetch!(current, :x), Map.fetch!(current, :y))]
    else
      changes
    end
  end

  # ---------------------------------------------------------------------------
  # Termination cleanup (best-effort)
  # ---------------------------------------------------------------------------

  defp reset_terminal_state(%__MODULE__{writer: nil}), do: :ok

  defp reset_terminal_state(%__MODULE__{} = state) do
    # Restore to a conservative baseline.
    output = [
      ANSI.reset(),
      ANSI.disable_mouse(),
      ANSI.disable_bracketed_paste(),
      ANSI.disable_unicode_width(),
      ANSI.show_cursor(),
      ANSI.exit_alt_screen()
    ]

    try do
      Writer.write_and_flush(state.writer, output)
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end

    :ok
  end
end
