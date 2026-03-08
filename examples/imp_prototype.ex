defmodule Tinct.Examples.ImpPrototype do
  @moduledoc """
  Imp engineering cockpit prototype — task-centric engineering UI.

  Two-pane layout: task tree on the left, task detail (with contextual
  activity + conversation) on the right. Chat input at the bottom sends
  messages scoped to the selected task.

  Run with:

      mix run examples/imp_prototype.ex

  Keys:

    * `tab` / `shift+tab` — cycle focus between panes
    * `up/down` or `j/k` — navigate within focused pane
    * `enter` — expand/collapse tree nodes, select task, or send message
    * `?` — toggle help overlay
    * `escape` — close overlay
    * `q` or `ctrl+c` — quit
  """

  use Tinct.Component

  alias Tinct.{Command, Element, Event, View}
  alias Tinct.FocusGroup
  alias Tinct.HitTest
  alias Tinct.Overlay
  alias Tinct.Widgets.{Border, SplitPane, TextInput, Tree}

  # -- Color palette -----------------------------------------------------------

  @accent {:rgb, 110, 140, 255}
  @accent_dim {:rgb, 60, 80, 140}
  @green {:rgb, 80, 220, 120}
  @yellow {:rgb, 240, 200, 80}
  @red {:rgb, 240, 80, 80}
  @cyan {:rgb, 80, 200, 240}
  @muted {:rgb, 100, 105, 115}
  @text_primary {:rgb, 220, 222, 228}
  @text_secondary {:rgb, 160, 165, 175}
  @orange {:rgb, 240, 160, 60}
  @purple {:rgb, 180, 120, 240}
  @section_line {:rgb, 55, 58, 68}

  # -- Fake data ---------------------------------------------------------------

  @tasks %{
    1 => %{id: 1, name: "fix-auth-redirect", status: :done, agent: "imp-1",
      detail: "Fixed OAuth redirect loop by validating callback URL against allowlist.",
      activity: [
        {~T[14:01:12], :claim, "claimed task"},
        {~T[14:01:15], :read,  "read lib/auth/oauth.ex (142 lines)"},
        {~T[14:01:22], :read,  "read lib/auth/callback.ex (87 lines)"},
        {~T[14:01:35], :edit,  "edit lib/auth/callback.ex — add URL validation"},
        {~T[14:01:42], :test,  "run mix test test/auth/ — 12 passed"},
        {~T[14:01:48], :done,  "✓ verified"}
      ],
      conversation: [
        {:user, "what was the root cause?"},
        {:imp, "The OAuth callback handler accepted any redirect_uri parameter without validation. An attacker could set redirect_uri to their own domain and capture the auth code. I added an allowlist check against the configured redirect URIs."}
      ]},

    2 => %{id: 2, name: "deploy-api", status: :running, agent: "imp-2",
      detail: "Adding /api/v2/users endpoint with pagination support.",
      activity: [
        {~T[14:02:01], :claim, "claimed task"},
        {~T[14:02:05], :read,  "read lib/router.ex (234 lines)"},
        {~T[14:02:14], :read,  "read lib/controllers/user_controller.ex"},
        {~T[14:02:30], :edit,  "edit lib/router.ex — add /api/v2 scope"},
        {~T[14:02:45], :edit,  "edit user_controller_v2.ex (new file)"},
        {~T[14:03:01], :test,  "run mix test — 44 passed, 2 failed"},
        {~T[14:03:10], :edit,  "edit user_controller_v2.ex — fix pagination"},
        {~T[14:03:18], :test,  "run mix test — 46 passed"}
      ],
      conversation: [
        {:user, "what's left?"},
        {:imp, "Pagination is working. Still need to add rate limiting middleware before this endpoint goes live. I'll create a follow-up task for that."}
      ]},

    3 => %{id: 3, name: "write-tests", status: :ready, agent: nil,
      detail: "Need integration tests for new user endpoints. Blocked until deploy-api finishes.",
      activity: [],
      conversation: []},

    4 => %{id: 4, name: "update-docs", status: :ready, agent: nil,
      detail: "Update API docs with new v2 endpoints and deprecation notices.",
      activity: [],
      conversation: []},

    5 => %{id: 5, name: "perf-audit", status: :blocked, agent: nil,
      detail: "Profile database queries on /dashboard. Waiting on deploy-api completion.",
      activity: [],
      conversation: [
        {:user, "what queries are slow?"},
        {:imp, "I haven't started yet — this task is blocked on deploy-api. Once the new endpoints land I can profile the dashboard queries against the updated schema."}
      ]},

    6 => %{id: 6, name: "refactor-config", status: :done, agent: "imp-1",
      detail: "Moved hardcoded config values to runtime.exs with env var fallbacks.",
      activity: [
        {~T[14:03:25], :claim, "claimed task"},
        {~T[14:03:30], :read,  "read config/runtime.exs"},
        {~T[14:03:35], :read,  "read config/config.exs"},
        {~T[14:03:38], :edit,  "edit config/runtime.exs — extract 8 env vars"},
        {~T[14:03:42], :edit,  "edit lib/app/config.ex — add accessor functions"},
        {~T[14:03:45], :test,  "run mix test — all passed"},
        {~T[14:03:48], :done,  "✓ verified"}
      ],
      conversation: []},

    7 => %{id: 7, name: "add-rate-limiting", status: :ready, agent: nil,
      detail: "Implement token bucket rate limiting on public API endpoints.",
      activity: [],
      conversation: []},

    8 => %{id: 8, name: "fix-ci-flake", status: :done, agent: "imp-3",
      detail: "Fixed race condition in async test setup by adding explicit synchronization.",
      activity: [
        {~T[14:04:00], :claim, "claimed task"},
        {~T[14:04:05], :read,  "read test/support/data_case.ex"},
        {~T[14:04:12], :read,  "read test/controllers/user_test.exs"},
        {~T[14:04:20], :edit,  "edit test/support/data_case.ex — add checkout barrier"},
        {~T[14:04:28], :test,  "run mix test --repeat 20 — all passed"},
        {~T[14:04:35], :done,  "✓ verified"}
      ],
      conversation: [
        {:user, "will this fix it permanently?"},
        {:imp, "Yes. The flake was caused by Ecto.Adapters.SQL.Sandbox checkouts racing with async test setup. The barrier ensures the checkout completes before any test runs. I verified with 20 repeated runs — zero failures."}
      ]}
  }

  @task_tree %{
    label: "my-app",
    children: [
      %{label: "Sprint 3", children: [
        %{label: "● fix-auth-redirect", children: []},
        %{label: "◐ deploy-api", children: []},
        %{label: "○ write-tests", children: []},
        %{label: "○ update-docs", children: []}
      ]},
      %{label: "Backlog", children: [
        %{label: "◌ perf-audit", children: []},
        %{label: "● refactor-config", children: []},
        %{label: "○ add-rate-limiting", children: []},
        %{label: "● fix-ci-flake", children: []}
      ]}
    ]
  }

  @task_name_to_id %{
    "fix-auth-redirect" => 1,
    "deploy-api" => 2,
    "write-tests" => 3,
    "update-docs" => 4,
    "perf-audit" => 5,
    "refactor-config" => 6,
    "add-rate-limiting" => 7,
    "fix-ci-flake" => 8
  }

  # -- Model -------------------------------------------------------------------

  defmodule Model do
    @moduledoc false

    defstruct size: {120, 40},
              focus: nil,
              tree: nil,
              input: nil,
              hit_map: nil,
              show_help: false,
              selected_task_id: 1,
              tasks: %{},
              detail_scroll: 0
  end

  # -- Component callbacks -----------------------------------------------------

  @impl true
  def init(_opts) do
    tree = Tree.init(
      root: @task_tree,
      height: 30,
      expanded: MapSet.new([[0], [0, 0]]),
      on_select: :tree_select
    )

    input = TextInput.init(placeholder: "ask imp about this task...", focused: true)

    %Model{
      focus: FocusGroup.new([:tree, :detail, :input]),
      tree: tree,
      input: input,
      hit_map: HitTest.new(),
      selected_task_id: 1,
      tasks: @tasks,
      detail_scroll: 0
    }
  end

  @impl true
  def update(%Model{} = model, %Event.Key{key: "c", mod: [:ctrl]}) do
    {model, Command.quit()}
  end

  def update(%Model{} = model, %Event.Key{key: "q", mod: []}) do
    cond do
      model.show_help -> %{model | show_help: false}
      FocusGroup.active(model.focus) == :input -> route_key_to_pane(model, %Event.Key{key: "q", mod: [], type: :press})
      true -> {model, Command.quit()}
    end
  end

  def update(%Model{} = model, %Event.Key{key: "?", mod: []}) do
    if FocusGroup.active(model.focus) == :input do
      route_key_to_pane(model, %Event.Key{key: "?", mod: [], type: :press})
    else
      %{model | show_help: !model.show_help}
    end
  end

  def update(%Model{} = model, %Event.Key{key: :escape, mod: []}) do
    %{model | show_help: false}
  end

  # Enter in input pane sends the message
  def update(%Model{} = model, %Event.Key{key: :enter, mod: []} = key) do
    if FocusGroup.active(model.focus) == :input do
      send_chat_message(model)
    else
      route_key_to_pane(model, key)
    end
  end

  def update(%Model{} = model, %Event.Key{} = key) do
    case FocusGroup.handle_key(model.focus, key) do
      {:consumed, new_focus} ->
        %{model | focus: new_focus}

      :passthrough ->
        route_key_to_pane(model, key)
    end
  end

  def update(%Model{} = model, {:tree_select, node}) do
    task_id = find_task_id_by_tree_label(node.label)
    if task_id, do: %{model | selected_task_id: task_id, detail_scroll: 0}, else: model
  end

  def update(%Model{} = model, %Event.Mouse{type: :click} = mouse) do
    case HitTest.handle_click(model.hit_map, mouse, model.focus) do
      {:hit, _tag, new_focus} -> %{model | focus: new_focus}
      {:miss, _focus} -> model
    end
  end

  def update(%Model{} = model, %Event.Resize{width: w, height: h}) do
    %{model | size: {w, h}}
  end

  def update(%Model{} = model, _msg), do: model

  # -- Chat message handling ---------------------------------------------------

  defp send_chat_message(%Model{input: input, selected_task_id: tid, tasks: tasks} = model) do
    value = String.trim(input.value)

    if value == "" do
      model
    else
      task = Map.get(tasks, tid)
      new_conversation = task.conversation ++ [{:user, value}]

      # Fake imp response
      response = fake_response(task, value)
      new_conversation = new_conversation ++ [{:imp, response}]

      updated_task = %{task | conversation: new_conversation}
      new_input = TextInput.clear(input)

      %{model |
        tasks: Map.put(tasks, tid, updated_task),
        input: new_input
      }
    end
  end

  defp fake_response(task, _msg) do
    case task.status do
      :done -> "This task is complete. The changes are in #{Enum.count(task.activity)} steps — see the activity log above for details."
      :running -> "I'm still working on this. Currently on step #{Enum.count(task.activity)} — check the activity log for real-time progress."
      :blocked -> "This task is blocked. I can't start until the upstream dependency is resolved."
      :ready -> "This task is ready to start. Want me to pick it up now?"
      _ -> "I'm not sure about that. Can you clarify?"
    end
  end

  # -- Key routing -------------------------------------------------------------

  defp route_key_to_pane(%Model{} = model, key) do
    case FocusGroup.active(model.focus) do
      :tree ->
        new_tree = Tree.update(model.tree, key)
        case new_tree do
          {tree_model, {:tree_select, node}} ->
            task_id = find_task_id_by_tree_label(node.label)
            model = %{model | tree: tree_model}
            if task_id, do: %{model | selected_task_id: task_id, detail_scroll: 0}, else: model
          tree_model ->
            %{model | tree: tree_model}
        end

      :detail ->
        case key do
          %Event.Key{key: :up} -> %{model | detail_scroll: max(0, model.detail_scroll - 1)}
          %Event.Key{key: :down} -> %{model | detail_scroll: model.detail_scroll + 1}
          %Event.Key{key: "k"} -> %{model | detail_scroll: max(0, model.detail_scroll - 1)}
          %Event.Key{key: "j"} -> %{model | detail_scroll: model.detail_scroll + 1}
          _ -> model
        end

      :input ->
        new_input = TextInput.update(model.input, key)
        new_input = normalize_input(new_input)
        %{model | input: new_input}

      _ ->
        model
    end
  end

  # -- View --------------------------------------------------------------------

  @impl true
  def view(%Model{} = model) do
    {cols, rows} = model.size

    tree_w = div(cols, 4)
    detail_w = cols - tree_w

    hit_map =
      HitTest.new()
      |> HitTest.register(:tree, {0, 1, tree_w, rows - 4})
      |> HitTest.register(:detail, {tree_w, 1, detail_w, rows - 4})
      |> HitTest.register(:input, {0, rows - 3, cols, 3})

    send(self(), {:update_hit_map, hit_map})

    content = render_layout(model, rows)

    if model.show_help do
      help_el = help_overlay_element()
      overlay = Overlay.new(help_el,
        width: min(64, cols - 4),
        height: min(20, rows - 4),
        backdrop: :dim
      )
      View.new(content, overlays: [overlay])
    else
      View.new(content)
    end
  end

  defp render_layout(model, rows) do
    status = render_status_bar(model)
    main = render_main_panes(model, max(rows - 4, 5))
    input_bar = render_input_bar(model)

    Element.column([], [status, main, input_bar])
  end

  # -- Status bar --------------------------------------------------------------

  defp render_status_bar(model) do
    tasks = Map.values(model.tasks)
    done = Enum.count(tasks, &(&1.status == :done))
    running = Enum.count(tasks, &(&1.status == :running))
    ready = Enum.count(tasks, &(&1.status == :ready))
    blocked = Enum.count(tasks, &(&1.status == :blocked))
    total = length(tasks)

    selected = Map.get(model.tasks, model.selected_task_id)
    task_name = if selected, do: selected.name, else: ""

    Element.rich([
      {" ◆ imp ", [fg: :black, bg: @accent, bold: true]},
      {"  my-app ", [fg: @text_primary, bold: true]},
      {"│", [fg: @section_line]},
      {" #{done}✓ ", [fg: @green]},
      {"#{running}◐ ", [fg: @cyan]},
      {"#{ready}○ ", [fg: @yellow]},
      {"#{blocked}◌ ", [fg: @red]},
      {" #{total} total ", [fg: @muted]},
      {"│", [fg: @section_line]},
      {" → #{task_name} ", [fg: @text_secondary]}
    ])
  end

  # -- Main panes (2-column: tree + detail) -----------------------------------

  defp render_main_panes(model, _height) do
    tree_pane = render_tree_pane(model)
    detail_pane = render_detail_pane(model)

    SplitPane.element(
      direction: :horizontal,
      panes: [
        {tree_pane, ratio: 0.25, min: 20},
        {detail_pane, ratio: 0.75, min: 40}
      ]
    )
  end

  # -- Tree pane ---------------------------------------------------------------

  defp render_tree_pane(model) do
    focused = FocusGroup.focused?(model.focus, :tree)
    {border_color, border_style, title} = pane_chrome(focused, "Tasks")

    tree_content = Tree.view(model.tree).content

    Border.element(
      [style: border_style, title: title, color: border_color],
      [tree_content]
    )
  end

  # -- Detail pane (task header + activity + conversation) --------------------

  defp render_detail_pane(model) do
    focused = FocusGroup.focused?(model.focus, :detail)
    task = Map.get(model.tasks, model.selected_task_id)

    {border_color, border_style, _title} = pane_chrome(focused, "")

    detail_title = if task do
      " #{task.name} "
    else
      " Detail "
    end

    inner = case task do
      nil ->
        Element.text("  Select a task from the tree", fg: @muted)
      task ->
        render_task_full(task, focused)
    end

    Border.element(
      [style: border_style, title: detail_title, color: border_color],
      [inner]
    )
  end

  defp render_task_full(task, _focused) do
    header = render_task_header(task)
    activity_section = render_task_activity(task)
    conversation_section = render_task_conversation(task)

    sections = [header]
    sections = if task.activity != [], do: sections ++ [activity_section], else: sections
    sections = sections ++ [conversation_section]

    Element.column([], sections)
  end

  # -- Task header -------------------------------------------------------------

  defp render_task_header(task) do
    status_color = status_color(task.status)
    status_icon = status_icon(task.status)

    agent_text = task.agent || "unassigned"
    agent_color = if task.agent, do: @orange, else: @muted

    status_line = Element.rich([
      {"  ", []},
      {status_icon, [fg: status_color, bold: true]},
      {" #{task.status}", [fg: status_color]},
      {"    ", []},
      {"agent: ", [fg: @muted]},
      {agent_text, [fg: agent_color, bold: task.agent != nil]}
    ])

    detail_line = Element.text("  #{task.detail}", fg: @text_secondary)

    Element.column([], [
      Element.text(""),
      status_line,
      Element.text(""),
      detail_line,
      Element.text("")
    ])
  end

  # -- Task activity section ---------------------------------------------------

  defp render_task_activity(task) do
    section_header = Element.rich([
      {"  ┄┄ ", [fg: @section_line]},
      {"Activity", [fg: @muted, bold: true]},
      {" ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄", [fg: @section_line]}
    ])

    activity_lines = Enum.map(task.activity, fn {time, kind, msg} ->
      time_str = Calendar.strftime(time, "%H:%M")
      color = activity_color(kind)
      icon = activity_icon(kind)

      Element.rich([
        {"  ", []},
        {time_str, [fg: @muted]},
        {" #{icon} ", [fg: color]},
        {msg, [fg: color]}
      ])
    end)

    Element.column([], [section_header | activity_lines] ++ [Element.text("")])
  end

  # -- Task conversation section -----------------------------------------------

  defp render_task_conversation(task) do
    section_header = Element.rich([
      {"  ┄┄ ", [fg: @section_line]},
      {"Conversation", [fg: @muted, bold: true]},
      {" ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄", [fg: @section_line]}
    ])

    messages = if task.conversation == [] do
      [Element.text("  No messages yet. Type below to ask imp about this task.", fg: @muted)]
    else
      Enum.flat_map(task.conversation, fn
        {:user, text} ->
          [
            Element.text(""),
            Element.rich([
              {"  you ", [fg: @accent, bold: true]},
              {text, [fg: @text_primary]}
            ])
          ]

        {:imp, text} ->
          [
            Element.text(""),
            Element.rich([
              {"  imp ", [fg: @green, bold: true]},
              {text, [fg: @text_secondary]}
            ])
          ]
      end)
    end

    Element.column([], [section_header | messages] ++ [Element.text("")])
  end

  # -- Input bar ---------------------------------------------------------------

  defp render_input_bar(model) do
    focused = FocusGroup.focused?(model.focus, :input)
    {border_color, border_style, _title} = pane_chrome(focused, "")

    prompt_color = if focused, do: @accent, else: @muted

    prompt = Element.rich([
      {"❯ ", [fg: prompt_color, bold: focused]}
    ])

    input_view = TextInput.view(model.input).content

    Border.element(
      [style: border_style, color: border_color],
      [Element.row([], [prompt, input_view])]
    )
  end

  # -- Help overlay ------------------------------------------------------------

  defp help_overlay_element do
    header = Element.rich([
      {" Keyboard Shortcuts ", [fg: :black, bg: @accent, bold: true]}
    ])

    bindings = [
      {"Tab / Shift+Tab", "cycle panes"},
      {"Up / Down / j / k", "navigate / scroll detail"},
      {"Enter", "select task / send message"},
      {"Space", "toggle expand tree node"},
      {"Left / Right", "collapse / expand node"},
      {"?", "toggle help"},
      {"Escape", "close overlay"},
      {"q / Ctrl+C", "quit"}
    ]

    binding_lines = Enum.map(bindings, fn {key, desc} ->
      Element.rich([
        {"  #{String.pad_trailing(key, 20)}", [fg: @purple, bold: true]},
        {desc, [fg: @text_secondary]}
      ])
    end)

    footer = Element.rich([
      {"  Panes: ", [fg: @muted]},
      {"Tasks", [fg: @accent]},
      {" │ ", [fg: @muted]},
      {"Detail", [fg: @accent]},
      {" │ ", [fg: @muted]},
      {"Input", [fg: @accent]}
    ])

    Element.column([padding: 1],
      [header, Element.text("")] ++ binding_lines ++ [Element.text(""), footer]
    )
  end

  # -- Pane chrome -------------------------------------------------------------

  defp pane_chrome(true = _focused, label) do
    title = if label != "", do: " #{label} ", else: nil
    {@accent, :round, title}
  end

  defp pane_chrome(false = _focused, label) do
    title = if label != "", do: " #{label} ", else: nil
    {@accent_dim, :single, title}
  end

  # -- Activity styling --------------------------------------------------------

  defp activity_icon(:claim), do: "→"
  defp activity_icon(:read), do: "◇"
  defp activity_icon(:edit), do: "◆"
  defp activity_icon(:test), do: "▷"
  defp activity_icon(:done), do: "●"
  defp activity_icon(_), do: "·"

  defp activity_color(:claim), do: @purple
  defp activity_color(:read), do: @text_secondary
  defp activity_color(:edit), do: @yellow
  defp activity_color(:test), do: @cyan
  defp activity_color(:done), do: @green
  defp activity_color(_), do: @muted

  # -- Status styling ----------------------------------------------------------

  defp status_icon(:done), do: "●"
  defp status_icon(:running), do: "◐"
  defp status_icon(:ready), do: "○"
  defp status_icon(:blocked), do: "◌"
  defp status_icon(_), do: "·"

  defp status_color(:done), do: @green
  defp status_color(:running), do: @cyan
  defp status_color(:ready), do: @yellow
  defp status_color(:blocked), do: @red
  defp status_color(_), do: @muted

  # -- Helpers -----------------------------------------------------------------

  defp find_task_id_by_tree_label(label) do
    clean = label
      |> String.replace(~r/^[●◐○◌▼▶]\s*/, "")
      |> String.trim()

    Map.get(@task_name_to_id, clean)
  end

  defp normalize_input({%TextInput.Model{} = m, _cmd}), do: m
  defp normalize_input(%TextInput.Model{} = m), do: m
end

Tinct.run(Tinct.Examples.ImpPrototype)
