defmodule Tinct.Examples.Dashboard do
  @moduledoc """
  Multi-widget dashboard demo with click focus, click selection, and responsive layout.

  Run with:

      mix run examples/dashboard.ex

  Keys:

    * `tab` — cycle focus between panels
    * `up/down` — navigate focused List/Table/ScrollView
    * `left/right` — switch focused Tabs
    * `enter` — submit focused TextInput / select List/Table item
    * `+` / `-` — adjust ProgressBar
    * `s` — advance Spinner frame
    * `a` — append a log line
    * `ctrl+l` — toggle loading state for focused List/Table/Log panel
    * `ctrl+e` — toggle error state for focused List/Table/Log panel
    * `ctrl+x` — clear focused List/Table/Log panel (empty state)
    * `ctrl+r` — restore focused List/Table/Log panel to ready data
    * mouse click — focus panel (and select row/item on List/Table, tab label on Tabs)
    * mouse wheel — scroll hovered List/Table/ScrollView panel
    * `q` or `ctrl+c` — quit
  """

  use Tinct.Component

  alias Tinct.{Command, Component, Element, Event, Layout, View}
  alias Tinct.Layout.Rect

  alias Tinct.Widgets.{
    Border,
    ProgressBar,
    ScrollView,
    Spinner,
    Static,
    Table,
    Tabs,
    TextInput
  }

  alias Tinct.Widgets.List, as: ListWidget

  @default_size {80, 24}
  @focus_order [:list, :table, :tabs, :input, :scroll, :log]

  @default_list_items ["alpha", "beta", "gamma", "delta", "epsilon", "zeta"]

  @default_table_rows [
    %{name: "agent-a", state: "ready"},
    %{name: "agent-b", state: "busy"},
    %{name: "agent-c", state: "idle"},
    %{name: "agent-d", state: "ready"}
  ]

  @default_log_items ["boot complete", "connected to worker pool"]

  defmodule Model do
    @moduledoc false

    defstruct size: {80, 24},
              focus: :list,
              list: nil,
              table: nil,
              tabs: nil,
              input: nil,
              scroll: nil,
              progress: nil,
              spinner: nil,
              log: nil,
              list_mode: :ready,
              table_mode: :ready,
              log_mode: :ready,
              log_seq: 1,
              last_action: "Ready"
  end

  @impl true
  def init(_opts) do
    model = %Model{
      size: @default_size,
      focus: :list,
      list:
        ListWidget.init(
          items: @default_list_items,
          selected: 1,
          height: 6,
          on_select: :picked_item
        ),
      table:
        Table.init(
          columns: [
            %{header: "Worker", width: :auto, key: :name},
            %{header: "State", width: :auto, key: :state}
          ],
          rows: @default_table_rows,
          selected: 0,
          height: 4,
          on_select: :picked_row
        ),
      tabs:
        Tabs.init(
          tabs: [
            {"Overview", Element.text("Overview panel")},
            {"Logs", Element.text("Logs panel")},
            {"Stats", Element.text("Stats panel")}
          ],
          active: 0,
          on_change: :tab_changed
        ),
      input: TextInput.init(placeholder: "Type and press Enter", on_submit: :send),
      scroll:
        ScrollView.init(
          children: Enum.map(1..24, fn i -> Element.text("Stream line #{i}") end),
          width: 32,
          height: 8,
          show_scrollbar: true
        ),
      progress: ProgressBar.init(label: "Build", progress: 0.42, width: 28),
      spinner: Spinner.init(style: :dots, label: "Running", color: :cyan),
      log: build_log(@default_log_items),
      list_mode: :ready,
      table_mode: :ready,
      log_mode: :ready,
      log_seq: length(@default_log_items) + 1,
      last_action: "Ready"
    }

    model
    |> reflow_widgets(@default_size)
    |> sync_input_focus()
  end

  @impl true
  def update(%Model{} = model, %Event.Key{key: "c", mod: [:ctrl]}) do
    {model, Command.quit()}
  end

  def update(%Model{} = model, %Event.Key{key: "q", mod: []}) do
    {model, Command.quit()}
  end

  def update(%Model{} = model, %Event.Resize{width: width, height: height}) do
    model
    |> reflow_widgets({width, height})
    |> apply_meta("Resized to #{width}×#{height}", [])
  end

  def update(%Model{} = model, %Event.Key{key: :tab, mod: []}) do
    next = next_focus(model.focus)
    apply_meta(model, "Focus: #{next}", focus: next)
  end

  def update(%Model{} = model, %Event.Key{key: "+", mod: []}) do
    progress = ProgressBar.increment(model.progress, 0.05)
    apply_meta(model, "Progress #{round(progress.progress * 100)}%", progress: progress)
  end

  def update(%Model{} = model, %Event.Key{key: "-", mod: []}) do
    progress = ProgressBar.increment(model.progress, -0.05)
    apply_meta(model, "Progress #{round(progress.progress * 100)}%", progress: progress)
  end

  def update(%Model{} = model, %Event.Key{key: "s", mod: []}) do
    spinner = Spinner.handle_tick(model.spinner)
    apply_meta(model, "Spinner advanced", spinner: spinner)
  end

  def update(%Model{} = model, %Event.Key{key: "a", mod: []}) do
    line = "manual event #{model.log_seq}"
    log = Static.update(model.log, {:add_item, line})

    model
    |> apply_meta("Added log line", log: log, log_seq: model.log_seq + 1)
  end

  def update(%Model{} = model, %Event.Key{key: "l", mod: [:ctrl]}) do
    toggle_loading_for_focus(model)
  end

  def update(%Model{} = model, %Event.Key{key: "e", mod: [:ctrl]}) do
    toggle_error_for_focus(model)
  end

  def update(%Model{} = model, %Event.Key{key: "x", mod: [:ctrl]}) do
    clear_focused_panel(model)
  end

  def update(%Model{} = model, %Event.Key{key: "r", mod: [:ctrl]}) do
    restore_focused_panel(model)
  end

  def update(%Model{} = model, %Event.Mouse{type: :click, button: :left} = mouse) do
    handle_left_click(model, mouse)
  end

  def update(%Model{} = model, %Event.Mouse{type: :wheel} = mouse) do
    handle_wheel(model, mouse)
  end

  def update(%Model{} = model, %Event.Mouse{}), do: model

  def update(%Model{} = model, %Event.Key{} = key) do
    route_key(model, model.focus, key)
  end

  def update(%Model{} = model, %Event.Paste{} = paste) do
    {input, cmd} = Component.normalize_update_result(TextInput.update(model.input, paste))

    model
    |> apply_meta(cmd_to_message(cmd), input: input)
    |> maybe_handle_input_submit(cmd)
  end

  def update(%Model{} = model, _msg), do: model

  @impl true
  def view(%Model{} = model) do
    View.new(dashboard_content(model), mouse_mode: :cell_motion)
  end

  # --- View composition ---

  defp dashboard_content(%Model{} = model) do
    Element.column([], [
      Element.text("Tinct Multi-Widget Dashboard", fg: :cyan, bold: true),
      Element.text(
        "tab focus · click focuses panel (and tab labels) · wheel scrolls hovered list/table/scroll · ctrl+l/e/x/r panel state · q quit",
        fg: :bright_black
      ),
      Element.text(""),
      Element.row([gap: 1], [left_column(model), right_column(model)]),
      Element.text(""),
      panel(:input, "Input", model.focus, TextInput.view(model.input).content),
      Element.text(""),
      panel(:log, "Log", model.focus, log_content(model)),
      Element.text(""),
      Element.text("Hint: #{focus_hint(model.focus)}", fg: :bright_black),
      Element.text("Last action: #{model.last_action}", fg: :bright_black)
    ])
  end

  defp left_column(%Model{} = model) do
    Element.box([flex_grow: 1], [
      panel(:list, "List", model.focus, list_content(model)),
      Element.text(""),
      panel(:scroll, "ScrollView", model.focus, ScrollView.view(model.scroll).content)
    ])
  end

  defp right_column(%Model{} = model) do
    Element.box([flex_grow: 1], [
      panel(:table, "Table", model.focus, table_content(model)),
      Element.text(""),
      panel(:tabs, "Tabs", model.focus, Tabs.view(model.tabs).content),
      Element.text(""),
      panel(nil, "Activity", model.focus, activity_content(model))
    ])
  end

  defp panel(id, label, focused, content) do
    active? = focused == id

    Border.element(
      [
        id: id,
        style: if(active?, do: :bold, else: :single),
        color: if(active?, do: :cyan, else: :bright_black),
        title: panel_title(label, active?)
      ],
      [content]
    )
  end

  defp panel_title(label, true), do: "▶ #{label}"
  defp panel_title(label, false), do: label

  defp activity_content(%Model{} = model) do
    Element.row([gap: 2], [
      Spinner.view(model.spinner).content,
      ProgressBar.view(model.progress).content
    ])
  end

  defp list_content(%Model{list_mode: :loading}) do
    Element.text("Loading list items…", fg: :yellow)
  end

  defp list_content(%Model{list_mode: {:error, message}}) do
    Element.text("List error: #{message}", fg: :red)
  end

  defp list_content(%Model{list_mode: :ready, list: %{items: []}}) do
    Element.text("No items yet. Press ctrl+r to reload default items.", fg: :bright_black)
  end

  defp list_content(%Model{list: list}) do
    ListWidget.view(list).content
  end

  defp table_content(%Model{table_mode: :loading}) do
    Element.text("Loading table rows…", fg: :yellow)
  end

  defp table_content(%Model{table_mode: {:error, message}}) do
    Element.text("Table error: #{message}", fg: :red)
  end

  defp table_content(%Model{table_mode: :ready, table: %{rows: []}}) do
    Element.text("No rows available. Press ctrl+r to restore sample rows.", fg: :bright_black)
  end

  defp table_content(%Model{table: table}) do
    Table.view(table).content
  end

  defp log_content(%Model{log_mode: :loading}) do
    Element.text("Loading logs…", fg: :yellow)
  end

  defp log_content(%Model{log_mode: {:error, message}}) do
    Element.text("Log error: #{message}", fg: :red)
  end

  defp log_content(%Model{log_mode: :ready, log: %{items: []}}) do
    Element.text("No log entries yet. Press 'a' to add one.", fg: :bright_black)
  end

  defp log_content(%Model{log: log}) do
    Static.view(log).content
  end

  # --- Mouse handling ---

  defp handle_left_click(%Model{} = model, %Event.Mouse{x: x, y: y}) do
    rects = panel_rects(model)
    panel = panel_at(rects, x, y)

    if panel do
      model = apply_meta(model, "Focus: #{panel}", focus: panel)

      case panel do
        :list -> click_select_list(model, rects[:list], y)
        :table -> click_select_table(model, rects[:table], y)
        :tabs -> click_select_tabs(model, rects[:tabs], x, y)
        _ -> model
      end
    else
      model
    end
  end

  defp handle_wheel(%Model{} = model, %Event.Mouse{} = mouse) do
    rects = panel_rects(model)
    hovered = panel_at(rects, mouse.x, mouse.y)

    target =
      cond do
        hovered in [:list, :table, :scroll] -> hovered
        model.focus in [:list, :table, :scroll] -> model.focus
        true -> nil
      end

    if target do
      model =
        if model.focus == target,
          do: model,
          else: apply_meta(model, "Focus: #{target}", focus: target)

      route_wheel(model, target, mouse)
    else
      model
    end
  end

  defp route_wheel(%Model{} = model, :list, %Event.Mouse{} = mouse) do
    if model.list_mode == :ready do
      {list, cmd} = Component.normalize_update_result(ListWidget.update(model.list, mouse))
      model |> apply_meta(cmd_to_message(cmd), list: list) |> maybe_handle_selection(cmd)
    else
      model
    end
  end

  defp route_wheel(%Model{} = model, :table, %Event.Mouse{} = mouse) do
    if model.table_mode == :ready do
      {table, cmd} = Component.normalize_update_result(Table.update(model.table, mouse))
      model |> apply_meta(cmd_to_message(cmd), table: table) |> maybe_handle_selection(cmd)
    else
      model
    end
  end

  defp route_wheel(%Model{} = model, :scroll, %Event.Mouse{} = mouse) do
    scroll = ScrollView.update(model.scroll, mouse)
    apply_meta(model, "Scroll y=#{scroll.offset_y}", scroll: scroll)
  end

  defp click_select_list(%Model{list_mode: mode} = model, _rect, _y) when mode != :ready do
    apply_meta(model, "List unavailable: #{mode_name(mode)}", [])
  end

  defp click_select_list(%Model{} = model, nil, _y), do: model

  defp click_select_list(%Model{} = model, %Rect{} = rect, y) do
    row = y - (rect.y + 1)
    row_count = max(rect.height - 2, 0)
    index = model.list.offset + row

    cond do
      row < 0 or row >= row_count ->
        model

      index < 0 or index >= length(model.list.items) ->
        model

      true ->
        list = ListWidget.select(model.list, index)
        apply_meta(model, "Selected list item #{index + 1}", list: list)
    end
  end

  defp click_select_table(%Model{table_mode: mode} = model, _rect, _y) when mode != :ready do
    apply_meta(model, "Table unavailable: #{mode_name(mode)}", [])
  end

  defp click_select_table(%Model{} = model, nil, _y), do: model

  defp click_select_table(%Model{} = model, %Rect{} = rect, y) do
    header_rows = if model.table.show_header, do: 2, else: 0
    row = y - (rect.y + 1 + header_rows)
    row_count = max(rect.height - 2 - header_rows, 0)
    index = model.table.offset + row

    cond do
      row < 0 or row >= row_count ->
        model

      index < 0 or index >= length(model.table.rows) ->
        model

      true ->
        table = Table.select(model.table, index)
        apply_meta(model, "Selected table row #{index + 1}", table: table)
    end
  end

  defp click_select_tabs(%Model{} = model, nil, _x, _y), do: model

  defp click_select_tabs(%Model{} = model, %Rect{} = rect, x, y) do
    tab_bar_x = rect.x + 1
    tab_bar_y = rect.y + 1

    if y != tab_bar_y do
      model
    else
      case Tabs.tab_at_x(model.tabs, x - tab_bar_x) do
        nil ->
          model

        index when index == model.tabs.active ->
          model

        index ->
          tabs = Tabs.set_active(model.tabs, index)
          apply_meta(model, "Selected tab #{index + 1}", tabs: tabs)
      end
    end
  end

  # --- Keyboard routing ---

  defp route_key(%Model{} = model, :list, %Event.Key{} = key) do
    if model.list_mode == :ready do
      {list, cmd} = Component.normalize_update_result(ListWidget.update(model.list, key))
      model |> apply_meta(cmd_to_message(cmd), list: list) |> maybe_handle_selection(cmd)
    else
      apply_meta(model, "List unavailable: #{mode_name(model.list_mode)}", [])
    end
  end

  defp route_key(%Model{} = model, :table, %Event.Key{} = key) do
    if model.table_mode == :ready do
      {table, cmd} = Component.normalize_update_result(Table.update(model.table, key))
      model |> apply_meta(cmd_to_message(cmd), table: table) |> maybe_handle_selection(cmd)
    else
      apply_meta(model, "Table unavailable: #{mode_name(model.table_mode)}", [])
    end
  end

  defp route_key(%Model{} = model, :tabs, %Event.Key{} = key) do
    {tabs, cmd} = Component.normalize_update_result(Tabs.update(model.tabs, key))
    apply_meta(model, cmd_to_message(cmd), tabs: tabs)
  end

  defp route_key(%Model{} = model, :input, %Event.Key{} = key) do
    {input, cmd} = Component.normalize_update_result(TextInput.update(model.input, key))

    model
    |> apply_meta(cmd_to_message(cmd), input: input)
    |> maybe_handle_input_submit(cmd)
  end

  defp route_key(%Model{} = model, :scroll, %Event.Key{} = key) do
    scroll = ScrollView.update(model.scroll, key)
    apply_meta(model, "Scroll y=#{scroll.offset_y}", scroll: scroll)
  end

  defp route_key(%Model{} = model, :log, _key) do
    apply_meta(model, "Log panel focused", [])
  end

  defp route_key(%Model{} = model, _focus, _key), do: model

  # --- Focused panel mode toggles ---

  defp toggle_loading_for_focus(%Model{focus: :list} = model) do
    next_mode = if model.list_mode == :loading, do: :ready, else: :loading
    apply_meta(model, "List mode: #{mode_name(next_mode)}", list_mode: next_mode)
  end

  defp toggle_loading_for_focus(%Model{focus: :table} = model) do
    next_mode = if model.table_mode == :loading, do: :ready, else: :loading
    apply_meta(model, "Table mode: #{mode_name(next_mode)}", table_mode: next_mode)
  end

  defp toggle_loading_for_focus(%Model{focus: :log} = model) do
    next_mode = if model.log_mode == :loading, do: :ready, else: :loading
    apply_meta(model, "Log mode: #{mode_name(next_mode)}", log_mode: next_mode)
  end

  defp toggle_loading_for_focus(%Model{} = model) do
    apply_meta(model, "Focus List/Table/Log to toggle loading", [])
  end

  defp toggle_error_for_focus(%Model{focus: :list} = model) do
    next_mode =
      if match?({:error, _}, model.list_mode), do: :ready, else: {:error, "data source failed"}

    apply_meta(model, "List mode: #{mode_name(next_mode)}", list_mode: next_mode)
  end

  defp toggle_error_for_focus(%Model{focus: :table} = model) do
    next_mode =
      if match?({:error, _}, model.table_mode), do: :ready, else: {:error, "query failed"}

    apply_meta(model, "Table mode: #{mode_name(next_mode)}", table_mode: next_mode)
  end

  defp toggle_error_for_focus(%Model{focus: :log} = model) do
    next_mode =
      if match?({:error, _}, model.log_mode),
        do: :ready,
        else: {:error, "log stream disconnected"}

    apply_meta(model, "Log mode: #{mode_name(next_mode)}", log_mode: next_mode)
  end

  defp toggle_error_for_focus(%Model{} = model) do
    apply_meta(model, "Focus List/Table/Log to toggle error", [])
  end

  defp clear_focused_panel(%Model{focus: :list} = model) do
    list = ListWidget.set_items(model.list, [])
    apply_meta(model, "Cleared list items", list: list, list_mode: :ready)
  end

  defp clear_focused_panel(%Model{focus: :table} = model) do
    table = Table.set_rows(model.table, [])
    apply_meta(model, "Cleared table rows", table: table, table_mode: :ready)
  end

  defp clear_focused_panel(%Model{focus: :log} = model) do
    log = clear_log(model.log)
    apply_meta(model, "Cleared log entries", log: log, log_mode: :ready)
  end

  defp clear_focused_panel(%Model{} = model) do
    apply_meta(model, "Focus List/Table/Log to clear data", [])
  end

  defp restore_focused_panel(%Model{focus: :list} = model) do
    list = ListWidget.set_items(model.list, @default_list_items)
    apply_meta(model, "Restored list items", list: list, list_mode: :ready)
  end

  defp restore_focused_panel(%Model{focus: :table} = model) do
    table = Table.set_rows(model.table, @default_table_rows)
    apply_meta(model, "Restored table rows", table: table, table_mode: :ready)
  end

  defp restore_focused_panel(%Model{focus: :log} = model) do
    log = build_log(@default_log_items)

    apply_meta(model, "Restored log entries",
      log: log,
      log_mode: :ready,
      log_seq: length(@default_log_items) + 1
    )
  end

  defp restore_focused_panel(%Model{} = model) do
    apply_meta(model, "Focus List/Table/Log to restore defaults", [])
  end

  # --- Domain behaviors ---

  defp maybe_handle_input_submit(%Model{} = model, {:send, value}) do
    clean = String.trim(value)

    if clean == "" do
      model
    else
      log = Static.update(model.log, {:add_item, "input: #{clean}"})
      input = TextInput.clear(model.input)
      apply_meta(model, "Submitted input", log: log, input: input)
    end
  end

  defp maybe_handle_input_submit(%Model{} = model, _cmd), do: model

  defp maybe_handle_selection(%Model{} = model, {:picked_item, item}) do
    log = Static.update(model.log, {:add_item, "list select: #{inspect(item)}"})
    apply_meta(model, "List selected", log: log)
  end

  defp maybe_handle_selection(%Model{} = model, {:picked_row, row}) do
    log = Static.update(model.log, {:add_item, "table select: #{inspect(row)}"})
    apply_meta(model, "Table selected", log: log)
  end

  defp maybe_handle_selection(%Model{} = model, _cmd), do: model

  # --- Responsive sizing ---

  defp reflow_widgets(%Model{} = model, {cols, rows}) do
    safe_cols = max(cols, 40)
    safe_rows = max(rows, 18)

    sizes = responsive_sizes({safe_cols, safe_rows})

    list =
      model.list
      |> Map.put(:height, sizes.list_height)
      |> ListWidget.set_items(model.list.items)

    table =
      model.table
      |> Map.put(:height, sizes.table_height)
      |> Table.set_rows(model.table.rows)

    scroll =
      ScrollView.update(
        model.scroll,
        %Event.Resize{width: sizes.scroll_width, height: sizes.scroll_height}
      )

    progress = %{model.progress | width: sizes.progress_width}
    log = trim_log(model.log, sizes.log_limit)

    %{
      model
      | size: {safe_cols, safe_rows},
        list: list,
        table: table,
        scroll: scroll,
        progress: progress,
        log: log
    }
  end

  defp responsive_sizes({cols, rows}) do
    %{
      list_height: clamp(div(rows, 4), 4, 12),
      table_height: clamp(div(rows, 5), 3, 10),
      scroll_height: clamp(div(rows, 3), 4, 14),
      scroll_width: max(div(cols, 2) - 8, 16),
      progress_width: clamp(div(cols, 3), 16, 48),
      log_limit: clamp(div(rows, 2), 4, 40)
    }
  end

  defp trim_log(log, limit) do
    items = Enum.take(log.items, -limit)
    rendered_count = min(log.rendered_count, length(items))
    %{log | items: items, rendered_count: rendered_count}
  end

  # --- Hit-testing ---

  defp panel_rects(%Model{} = model) do
    model
    |> dashboard_content()
    |> Layout.resolve(model.size)
    |> Enum.reduce(%{}, fn {element, rect}, acc ->
      case Map.get(element.attrs, :panel_id) do
        id when is_atom(id) -> Map.put(acc, id, rect)
        _ -> acc
      end
    end)
  end

  defp panel_at(rects, x, y) when is_map(rects) do
    rects
    |> Enum.find_value(fn {panel, rect} -> if Rect.contains?(rect, x, y), do: panel end)
  end

  # --- Helpers ---

  defp build_log(items) do
    Static.init(
      items: items,
      render_fn: fn item, idx -> Element.text("#{idx + 1}. #{item}") end
    )
  end

  defp clear_log(log), do: %{log | items: [], rendered_count: 0}

  defp apply_meta(%Model{} = model, action, updates) when is_list(updates) do
    updated = struct(model, updates) |> sync_input_focus()
    %{updated | last_action: action}
  end

  defp sync_input_focus(%Model{} = model) do
    input =
      if model.focus == :input,
        do: TextInput.focus(model.input),
        else: TextInput.blur(model.input)

    %{model | input: input}
  end

  defp mode_name(:ready), do: "ready"
  defp mode_name(:loading), do: "loading"
  defp mode_name({:error, _}), do: "error"

  defp cmd_to_message(nil), do: "Updated"
  defp cmd_to_message(cmd), do: "Event #{inspect(cmd)}"

  defp next_focus(current) do
    idx = Enum.find_index(@focus_order, &(&1 == current)) || 0
    Enum.at(@focus_order, rem(idx + 1, length(@focus_order)))
  end

  defp focus_hint(:list),
    do: "List: up/down or wheel; click a row to select; Enter emits selection"

  defp focus_hint(:table),
    do: "Table: up/down or wheel; click a row to select; Enter emits selection"

  defp focus_hint(:tabs), do: "Tabs: left/right or Tab; number keys or click tab labels"
  defp focus_hint(:input), do: "Input: type + Enter to append to log"
  defp focus_hint(:scroll), do: "ScrollView: up/down/page keys or wheel"
  defp focus_hint(:log), do: "Log: press 'a' to append, ctrl+x to clear, ctrl+r to restore"
  defp focus_hint(_), do: "Use Tab or mouse click to focus a panel"

  defp clamp(value, min_value, max_value) do
    value
    |> max(min_value)
    |> min(max_value)
  end
end

Tinct.run(Tinct.Examples.Dashboard)
