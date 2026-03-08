defmodule Tinct.Examples.Widgets do
  @moduledoc """
  Interactive widget showcase for manual visual verification.

  This demo lets you cycle through every built-in widget and interact with each
  one in a focused panel so you can see behavior directly in the terminal.

  Run with:

      mix run examples/widgets.ex

  Global keys:

    * `ctrl+n` — next widget
    * `ctrl+p` — previous widget
    * `q` / `ctrl+c` — quit
    * mouse wheel — scroll on List/Table/ScrollView pages
  """

  use Tinct.Component

  alias Tinct.{Command, Component, Element, Event, View}

  alias Tinct.Widgets.{
    Border,
    ProgressBar,
    ScrollView,
    Spinner,
    Static,
    StatusBar,
    Table,
    Tabs,
    Text,
    TextInput
  }

  alias Tinct.Widgets.List, as: ListWidget

  @pages [
    :text,
    :text_input,
    :list,
    :table,
    :tabs,
    :progress_bar,
    :spinner,
    :scroll_view,
    :static,
    :status_bar,
    :border
  ]

  @spinner_styles [:dots, :line, :arc, :bounce, :dots2, :simple]
  @border_styles [:single, :double, :round, :bold]

  defmodule Model do
    @moduledoc false
    defstruct page_index: 0,
              text: nil,
              text_input: nil,
              list: nil,
              table: nil,
              tabs: nil,
              progress_bar: nil,
              spinner: nil,
              scroll_view: nil,
              static: nil,
              status_bar: nil,
              border: nil,
              last_action: "Ready"
  end

  @impl true
  def init(_opts) do
    %Model{
      page_index: 0,
      text: Text.init(content: "Text widget\nPress u to change this content"),
      text_input:
        TextInput.init(
          value: "type here",
          focused: true,
          on_change: :changed,
          on_submit: :submitted,
          placeholder: "Type here"
        ),
      list:
        ListWidget.init(
          items: ["alpha", "beta", "gamma", "delta", "epsilon", "zeta"],
          selected: 1,
          height: 5,
          on_select: :picked
        ),
      table:
        Table.init(
          columns: [
            %{header: "Worker", width: :auto, key: :name},
            %{header: "State", width: :auto, key: :state}
          ],
          rows: [
            %{name: "A", state: "ready"},
            %{name: "B", state: "busy"},
            %{name: "C", state: "idle"},
            %{name: "D", state: "ready"}
          ],
          selected: 0,
          height: 4,
          on_select: :row_selected
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
      progress_bar: ProgressBar.init(progress: 0.35, label: "Build", width: 40),
      spinner: Spinner.init(style: :dots, label: "Working", color: :cyan),
      scroll_view:
        ScrollView.init(
          children: Enum.map(1..20, fn i -> Element.text("Line #{i}") end),
          width: 50,
          height: 8,
          show_scrollbar: true
        ),
      static:
        Static.init(
          items: ["Booted", "Connected", "Ready"],
          render_fn: fn item, index -> Element.text("#{index + 1}. #{item}") end
        ),
      status_bar:
        StatusBar.init(
          sections: [
            {"main", [align: :left]},
            {"widget showcase", [align: :center]},
            {"ok", [align: :right]}
          ],
          position: :bottom
        ),
      border:
        Border.init(
          style: :round,
          title: "Border widget",
          children: [
            Element.text("Inside the border"),
            Element.text("Press 1-4 to change style")
          ]
        ),
      last_action: "Ready"
    }
  end

  @impl true
  def update(%Model{} = model, %Event.Key{key: "c", mod: [:ctrl]}) do
    {model, Command.quit()}
  end

  def update(%Model{} = model, %Event.Key{key: "q", mod: []}) do
    {model, Command.quit()}
  end

  def update(%Model{} = model, %Event.Key{key: "n", mod: [:ctrl]}) do
    next_index = rem(model.page_index + 1, length(@pages))

    %{
      model
      | page_index: next_index,
        last_action: "Switched to #{page_title(page_at(next_index))}"
    }
  end

  def update(%Model{} = model, %Event.Key{key: "p", mod: [:ctrl]}) do
    prev_index = rem(model.page_index - 1 + length(@pages), length(@pages))

    %{
      model
      | page_index: prev_index,
        last_action: "Switched to #{page_title(page_at(prev_index))}"
    }
  end

  def update(%Model{} = model, %Event.Mouse{} = mouse) do
    handle_page_mouse(model, current_page(model), mouse)
  end

  def update(%Model{} = model, %Event.Key{} = key) do
    handle_page_key(model, current_page(model), key)
  end

  def update(%Model{} = model, %Event.Paste{} = paste) do
    handle_page_paste(model, current_page(model), paste)
  end

  def update(%Model{} = model, _msg), do: model

  @impl true
  def view(%Model{} = model) do
    page = current_page(model)

    root =
      Element.column([], [
        Element.text("Tinct Widget Showcase", fg: :cyan, bold: true),
        Element.text(nav_line(model)),
        Element.text(
          "ctrl+n / ctrl+p switch widgets · q quits · #{page_help(page)} · mouse wheel on list/table/scroll",
          fg: :bright_black
        ),
        Element.text(""),
        Border.element([style: :single, title: page_title(page)], [render_page(model, page)]),
        Element.text(""),
        Element.text("Last action: #{model.last_action}", fg: :bright_black)
      ])

    View.new(root, mouse_mode: :cell_motion)
  end

  defp handle_page_key(%Model{} = model, :text, %Event.Key{key: "u", mod: []}) do
    text = Text.update(model.text, {:set_content, "Text widget\nUpdated content"})
    %{model | text: text, last_action: "Updated text content"}
  end

  defp handle_page_key(%Model{} = model, :text, _key), do: model

  defp handle_page_key(%Model{} = model, :text_input, %Event.Key{} = key) do
    {text_input, cmd} = Component.normalize_update_result(TextInput.update(model.text_input, key))
    updated_model = %{model | text_input: text_input}
    maybe_set_action(updated_model, cmd)
  end

  defp handle_page_key(%Model{} = model, :list, %Event.Key{} = key) do
    {list, cmd} = Component.normalize_update_result(ListWidget.update(model.list, key))
    updated_model = %{model | list: list}
    maybe_set_action(updated_model, cmd)
  end

  defp handle_page_key(%Model{} = model, :table, %Event.Key{} = key) do
    {table, cmd} = Component.normalize_update_result(Table.update(model.table, key))
    updated_model = %{model | table: table}
    maybe_set_action(updated_model, cmd)
  end

  defp handle_page_key(%Model{} = model, :tabs, %Event.Key{} = key) do
    {tabs, cmd} = Component.normalize_update_result(Tabs.update(model.tabs, key))
    updated_model = %{model | tabs: tabs}
    maybe_set_action(updated_model, cmd)
  end

  defp handle_page_key(%Model{} = model, :progress_bar, %Event.Key{key: :left, mod: []}) do
    progress_bar = ProgressBar.increment(model.progress_bar, -0.05)

    %{
      model
      | progress_bar: progress_bar,
        last_action: "Progress #{percent_text(progress_bar.progress)}"
    }
  end

  defp handle_page_key(%Model{} = model, :progress_bar, %Event.Key{key: :right, mod: []}) do
    progress_bar = ProgressBar.increment(model.progress_bar, 0.05)

    %{
      model
      | progress_bar: progress_bar,
        last_action: "Progress #{percent_text(progress_bar.progress)}"
    }
  end

  defp handle_page_key(%Model{} = model, :progress_bar, %Event.Key{key: "r", mod: []}) do
    progress_bar = ProgressBar.set_progress(model.progress_bar, 0.0)
    %{model | progress_bar: progress_bar, last_action: "Progress reset"}
  end

  defp handle_page_key(%Model{} = model, :progress_bar, _key), do: model

  defp handle_page_key(%Model{} = model, :spinner, %Event.Key{key: :right, mod: []}) do
    spinner = Spinner.handle_tick(model.spinner)
    %{model | spinner: spinner, last_action: "Advanced spinner frame"}
  end

  defp handle_page_key(%Model{} = model, :spinner, %Event.Key{key: "s", mod: []}) do
    spinner = %{model.spinner | style: next_style(model.spinner.style, @spinner_styles), frame: 0}
    %{model | spinner: spinner, last_action: "Spinner style #{spinner.style}"}
  end

  defp handle_page_key(%Model{} = model, :spinner, _key), do: model

  defp handle_page_key(%Model{} = model, :scroll_view, %Event.Key{} = key) do
    scroll_view = ScrollView.update(model.scroll_view, key)

    %{
      model
      | scroll_view: scroll_view,
        last_action: "Scroll offset y=#{scroll_view.offset_y}"
    }
  end

  defp handle_page_key(%Model{} = model, :static, %Event.Key{key: "a", mod: []}) do
    next_id = length(model.static.items) + 1
    static = Static.update(model.static, {:add_item, "event #{next_id}"})
    %{model | static: static, last_action: "Added one static item"}
  end

  defp handle_page_key(%Model{} = model, :static, %Event.Key{key: "m", mod: []}) do
    next_id = length(model.static.items) + 1

    static =
      Static.update(model.static, {
        :add_items,
        ["event #{next_id}", "event #{next_id + 1}", "event #{next_id + 2}"]
      })

    %{model | static: static, last_action: "Added three static items"}
  end

  defp handle_page_key(%Model{} = model, :static, %Event.Key{key: "r", mod: []}) do
    static = Static.mark_rendered(model.static)
    %{model | static: static, last_action: "Marked static items as rendered"}
  end

  defp handle_page_key(%Model{} = model, :static, _key), do: model

  defp handle_page_key(%Model{} = model, :status_bar, %Event.Key{key: "l", mod: []}) do
    status_bar =
      StatusBar.update(model.status_bar, {:set_section, 0, {"left updated", [align: :left]}})

    %{model | status_bar: status_bar, last_action: "Updated left status section"}
  end

  defp handle_page_key(%Model{} = model, :status_bar, %Event.Key{key: "c", mod: []}) do
    status_bar =
      StatusBar.update(model.status_bar, {:set_section, 1, {"center updated", [align: :center]}})

    %{model | status_bar: status_bar, last_action: "Updated center status section"}
  end

  defp handle_page_key(%Model{} = model, :status_bar, %Event.Key{key: "r", mod: []}) do
    status_bar =
      StatusBar.update(model.status_bar, {:set_section, 2, {"right updated", [align: :right]}})

    %{model | status_bar: status_bar, last_action: "Updated right status section"}
  end

  defp handle_page_key(%Model{} = model, :status_bar, %Event.Key{key: "t", mod: []}) do
    status_bar = %{model.status_bar | position: :top}
    %{model | status_bar: status_bar, last_action: "Status bar moved to top"}
  end

  defp handle_page_key(%Model{} = model, :status_bar, %Event.Key{key: "b", mod: []}) do
    status_bar = %{model.status_bar | position: :bottom}
    %{model | status_bar: status_bar, last_action: "Status bar moved to bottom"}
  end

  defp handle_page_key(%Model{} = model, :status_bar, _key), do: model

  defp handle_page_key(%Model{} = model, :border, %Event.Key{key: key, mod: []})
       when key in ["1", "2", "3", "4"] do
    style = style_from_key(key)
    border = %{model.border | style: style}
    %{model | border: border, last_action: "Border style #{style}"}
  end

  defp handle_page_key(%Model{} = model, :border, %Event.Key{key: "t", mod: []}) do
    next_title = if model.border.title, do: nil, else: "Border widget"
    border = %{model.border | title: next_title}
    %{model | border: border, last_action: "Toggled border title"}
  end

  defp handle_page_key(%Model{} = model, :border, _key), do: model

  defp handle_page_mouse(%Model{} = model, :list, %Event.Mouse{} = mouse) do
    {list, cmd} = Component.normalize_update_result(ListWidget.update(model.list, mouse))
    updated_model = %{model | list: list}
    maybe_set_action(updated_model, cmd)
  end

  defp handle_page_mouse(%Model{} = model, :table, %Event.Mouse{} = mouse) do
    {table, cmd} = Component.normalize_update_result(Table.update(model.table, mouse))
    updated_model = %{model | table: table}
    maybe_set_action(updated_model, cmd)
  end

  defp handle_page_mouse(%Model{} = model, :scroll_view, %Event.Mouse{} = mouse) do
    scroll_view = ScrollView.update(model.scroll_view, mouse)

    %{
      model
      | scroll_view: scroll_view,
        last_action: "Scroll offset y=#{scroll_view.offset_y}"
    }
  end

  defp handle_page_mouse(%Model{} = model, _page, _mouse), do: model

  defp handle_page_paste(%Model{} = model, :text_input, %Event.Paste{} = paste) do
    {text_input, cmd} =
      Component.normalize_update_result(TextInput.update(model.text_input, paste))

    updated_model = %{model | text_input: text_input}
    maybe_set_action(updated_model, cmd)
  end

  defp handle_page_paste(%Model{} = model, _page, _paste), do: model

  defp maybe_set_action(%Model{} = model, nil), do: model

  defp maybe_set_action(%Model{} = model, cmd) do
    %{model | last_action: "Command #{inspect(cmd)}"}
  end

  defp render_page(%Model{} = model, :text) do
    Element.column([], [
      Text.view(model.text).content,
      Element.text("u updates text", fg: :bright_black)
    ])
  end

  defp render_page(%Model{} = model, :text_input) do
    Element.column([], [
      TextInput.view(model.text_input).content,
      Element.text("value: #{inspect(model.text_input.value)}", fg: :bright_black)
    ])
  end

  defp render_page(%Model{} = model, :list) do
    selected = ListWidget.selected_item(model.list)

    Element.column([], [
      ListWidget.view(model.list).content,
      Element.text("selected: #{inspect(selected)}", fg: :bright_black)
    ])
  end

  defp render_page(%Model{} = model, :table) do
    selected = Table.selected_row(model.table)

    Element.column([], [
      Table.view(model.table).content,
      Element.text("selected row: #{inspect(selected)}", fg: :bright_black)
    ])
  end

  defp render_page(%Model{} = model, :tabs) do
    Element.column([], [
      Tabs.view(model.tabs).content,
      Element.text("active index: #{model.tabs.active}", fg: :bright_black)
    ])
  end

  defp render_page(%Model{} = model, :progress_bar) do
    Element.column([], [
      ProgressBar.view(model.progress_bar).content,
      Element.text("left/right changes progress · r resets", fg: :bright_black)
    ])
  end

  defp render_page(%Model{} = model, :spinner) do
    Element.column([], [
      Spinner.view(model.spinner).content,
      Element.text("right advances frame · s cycles style", fg: :bright_black)
    ])
  end

  defp render_page(%Model{} = model, :scroll_view) do
    Element.column([], [
      ScrollView.view(model.scroll_view).content,
      Element.text("up/down/page_up/page_down scroll", fg: :bright_black)
    ])
  end

  defp render_page(%Model{} = model, :static) do
    new_count = length(Static.new_items(model.static))

    Element.column([], [
      Static.view(model.static).content,
      Element.text("new items: #{new_count} · a adds one · m adds many · r marks rendered",
        fg: :bright_black
      )
    ])
  end

  defp render_page(%Model{} = model, :status_bar) do
    Element.column([], [
      Element.box([height: 6], [StatusBar.view(model.status_bar).content]),
      Element.text("l/c/r update sections · t top · b bottom", fg: :bright_black)
    ])
  end

  defp render_page(%Model{} = model, :border) do
    Element.column([], [
      Border.view(model.border).content,
      Element.text("1-4 style · t toggle title", fg: :bright_black)
    ])
  end

  defp nav_line(%Model{} = model) do
    @pages
    |> Enum.with_index()
    |> Enum.map(fn {page, index} ->
      label = page_title(page)
      if index == model.page_index, do: "[#{label}]", else: label
    end)
    |> Enum.join("  ")
  end

  defp page_help(:text), do: "u updates content"
  defp page_help(:text_input), do: "type and press enter"
  defp page_help(:list), do: "up/down + enter"
  defp page_help(:table), do: "up/down + enter"
  defp page_help(:tabs), do: "left/right/tab"
  defp page_help(:progress_bar), do: "left/right/r"
  defp page_help(:spinner), do: "right advances frame, s changes style"
  defp page_help(:scroll_view), do: "up/down/page_up/page_down"
  defp page_help(:static), do: "a/m/r"
  defp page_help(:status_bar), do: "l/c/r, t or b"
  defp page_help(:border), do: "1-4 or t"

  defp current_page(%Model{page_index: index}), do: page_at(index)
  defp page_at(index), do: Enum.at(@pages, index, :text)

  defp page_title(:text), do: "Text"
  defp page_title(:text_input), do: "TextInput"
  defp page_title(:list), do: "List"
  defp page_title(:table), do: "Table"
  defp page_title(:tabs), do: "Tabs"
  defp page_title(:progress_bar), do: "ProgressBar"
  defp page_title(:spinner), do: "Spinner"
  defp page_title(:scroll_view), do: "ScrollView"
  defp page_title(:static), do: "Static"
  defp page_title(:status_bar), do: "StatusBar"
  defp page_title(:border), do: "Border"

  defp percent_text(progress) do
    "#{round(progress * 100)}%"
  end

  defp next_style(current, styles) do
    current_index = Enum.find_index(styles, &(&1 == current)) || 0
    Enum.at(styles, rem(current_index + 1, length(styles)))
  end

  defp style_from_key("1"), do: Enum.at(@border_styles, 0)
  defp style_from_key("2"), do: Enum.at(@border_styles, 1)
  defp style_from_key("3"), do: Enum.at(@border_styles, 2)
  defp style_from_key("4"), do: Enum.at(@border_styles, 3)
end

Tinct.run(Tinct.Examples.Widgets)
