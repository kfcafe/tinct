# Tinct Architecture

## Overview

Tinct is a pure Elixir TUI framework built on the Elm Architecture. It renders
terminal UIs using declarative views, CSS-like styling, and flexbox layout.

The framework is organized in layers. Each layer depends only on the layers
below it. Agents build bottom-up — foundation first, widgets last.

```
┌─────────────────────────────────────────────┐
│              Application Layer              │
│   User code: init/update/view callbacks     │
├─────────────────────────────────────────────┤
│              Widget Library                 │
│   Text, Input, List, Table, Tabs, etc.      │
├─────────────────────────────────────────────┤
│              Component System               │
│   Behaviour, focus, commands, subscriptions  │
├─────────────────────────────────────────────┤
│              Styling Engine                 │
│   CSS-like rules, themes, color profiles     │
├─────────────────────────────────────────────┤
│              Layout Engine                  │
│   Flexbox solver, constraint resolution      │
├─────────────────────────────────────────────┤
│              Rendering Engine               │
│   Cell buffer, diffing, ANSI encoding        │
├─────────────────────────────────────────────┤
│              Event System                   │
│   Input parsing, keyboard protocol, mouse    │
├─────────────────────────────────────────────┤
│              Terminal Backend               │
│   Raw mode, ANSI output, capability detect   │
└─────────────────────────────────────────────┘
```

## Layer 1: Terminal Backend

The lowest layer. Handles raw communication with the terminal.

### Responsibilities

- Enter/exit raw mode (disable line buffering, echo)
- Enter/exit alternate screen buffer
- Write bytes to stdout (ANSI escape sequences)
- Detect terminal size, handle resize signals
- Detect terminal capabilities (color profile, Kitty protocol support)
- IEx compatibility (use `:io.get_chars/2` when running in IEx)

### Key modules

- `Tinct.Terminal` — enter/exit raw mode, alternate screen
- `Tinct.Terminal.Capabilities` — detect color profile, keyboard protocol, unicode width
- `Tinct.Terminal.Writer` — buffered ANSI output, synchronized rendering (Mode 2026)

### Design decisions

- Pure Elixir, no NIFs. Uses Erlang's `:io` module and Port for raw mode.
- Capability detection at startup — query terminal once, cache results.
- Auto color downsampling: detect profile (truecolor/256/16/ascii), downgrade
  all colors to match. Colors "just work" everywhere.

### Inspiration

- Bubble Tea v2's color downsampling and capability detection
- TermUI's `:io.get_chars/2` trick for IEx compatibility


## Layer 2: Event System

Parses raw terminal input into structured events.

### Responsibilities

- Parse escape sequences into key events (arrows, modifiers, function keys)
- Parse mouse events (click, release, wheel, motion)
- Parse paste events (bracketed paste mode)
- Support Kitty keyboard protocol (progressive enhancement)
- Detect key release events (for games, hold-to-repeat)
- Graceful fallback: enhanced keys on modern terminals, basic keys everywhere

### Key modules

- `Tinct.Event` — event types (Key, Mouse, Paste, Resize, Focus, etc.)
- `Tinct.Event.Parser` — state machine that turns byte sequences into events
- `Tinct.Event.Reader` — GenServer that reads stdin and emits events

### Design decisions

- Parser is a pure function (bytes in, events out) — easy to test.
- Reader is a separate process — crash isolation from the app.
- Progressive keyboard enhancement: request Kitty protocol, fall back gracefully.
- Paste events are distinct from key events (no `msg.Paste` flag hack).

### Inspiration

- Bubble Tea v2's KeyPressMsg/KeyReleaseMsg split and Kitty protocol support
- Ink's `useInput` / `usePaste` separation


## Layer 3: Rendering Engine

Maintains a cell buffer and produces minimal ANSI output.

### Responsibilities

- Cell buffer: 2D grid of cells (character + foreground + background + attributes)
- Double buffering: maintain current and previous buffer
- Diffing: compare buffers, produce minimal set of ANSI operations
- ANSI encoding: convert diff operations into escape sequences
- Synchronized output: wrap writes in Mode 2026 begin/end
- Unicode width handling: correctly measure wide characters and emoji

### Key modules

- `Tinct.Buffer` — 2D cell grid, read/write operations
- `Tinct.Buffer.Cell` — single cell (char, fg, bg, bold, italic, etc.)
- `Tinct.Buffer.Diff` — compare two buffers, emit change operations
- `Tinct.ANSI` — encode operations as ANSI escape sequences

### Design decisions

- Buffers are immutable (ETS or maps). View function produces a new buffer,
  diff compares against previous.
- Diff algorithm: linear scan, skip unchanged cells, batch adjacent changes.
- Run-length coalescing for sequences of same-styled text.

### Inspiration

- Ratatui's immediate-mode buffer/diff approach
- Bubble Tea v2's Cursed Renderer (ncurses algorithm)
- TermUI's ETS double buffering


## Layer 4: Layout Engine

Resolves a tree of elements into positioned rectangles on the cell grid.

### Responsibilities

- Flexbox layout: direction, justify, align, wrap, grow, shrink, basis
- Constraint resolution: fixed, percentage, min/max width/height
- Padding, margin, gap
- Border rendering (with auto-connecting between adjacent borders)
- Overflow handling: visible, hidden, scroll

### Key modules

- `Tinct.Layout` — resolve element tree into positioned rects
- `Tinct.Layout.Flex` — flexbox constraint solver
- `Tinct.Layout.Rect` — positioned rectangle (x, y, width, height)

### Design decisions

- Don't use Yoga (C dependency). Write a simple flexbox solver in Elixir.
  Terminal layout is simpler than browser layout — no floats, no inline text
  reflow, no percentage-of-viewport edge cases. A character grid with integer
  dimensions is much easier to solve.
- Single-pass layout where possible. Two-pass for shrink-to-fit.
- Borders: auto-connecting (like Brick). Adjacent borders merge into
  proper intersections (┬, ├, ┼, etc.).

### Inspiration

- Ink's Yoga-based flexbox (the model, not the implementation)
- Brick's auto-connecting borders
- Ratatui's constraint-based layout


## Layer 5: Styling Engine

CSS-like styling system for terminal UIs.

### Responsibilities

- Style structs: foreground, background, bold, italic, underline, border, etc.
- Named styles / classes (like CSS class names)
- Theme system: named color palettes, swappable at runtime
- Style inheritance: parent styles cascade to children (like CSS)
- Auto color downsampling: colors adapt to terminal capability

### Key modules

- `Tinct.Style` — style struct and builder functions
- `Tinct.Theme` — named themes, color palettes
- `Tinct.Color` — color types (named, RGB, ANSI256), downsampling

### Design decisions

- Styles are data (structs), not inline function calls.
- No actual CSS parser (too complex for v0.1). Instead, a DSL:
  ```elixir
  style do
    color :green
    background :black
    bold true
    padding 1
    border :round
  end
  ```
- Themes are maps of name → style. Components reference names, not colors.
  Switch themes and everything updates.
- Color downsampling happens at render time, not style definition time.

### Inspiration

- Textual's CSS approach (the concept, simplified for terminal)
- Brick's named attribute themes
- Bubble Tea v2's auto color downsampling


## Layer 6: Component System

The core framework — Elm Architecture on OTP.

### Responsibilities

- Component behaviour: `init/1`, `update/2`, `view/1`
- Declarative view return type (struct, not string)
- Command system: async side effects that send messages back
- Subscription system: timers, file watchers, terminal events
- Focus management: tab between interactive components
- App lifecycle: start, run, quit

### Key modules

- `Tinct.Component` — behaviour definition
- `Tinct.View` — declarative view struct (content, cursor, alt_screen, mouse_mode, etc.)
- `Tinct.Command` — async side effects
- `Tinct.App` — GenServer that runs the event loop
- `Tinct.App.Supervisor` — supervises reader, renderer, app

### Callback model

```elixir
defmodule MyApp do
  use Tinct.Component

  @impl true
  def init(_opts), do: %{count: 0}

  @impl true
  def update(model, msg) do
    case msg do
      :increment -> %{model | count: model.count + 1}
      :decrement -> %{model | count: model.count - 1}
      {:key, "q"} -> Tinct.quit(model)
      _ -> model
    end
  end

  @impl true
  def view(model) do
    import Tinct.UI

    view do
      column gap: 1 do
        text "Count: #{model.count}", bold: true, color: :cyan
        text "↑/↓ to change, q to quit", color: :dark_gray
      end
    end
  end
end

Tinct.run(MyApp)
```

### Declarative view struct

```elixir
%Tinct.View{
  content: element_tree,
  cursor: %Tinct.Cursor{x: 14, y: 0, shape: :block, blink: true},
  alt_screen: true,
  mouse_mode: :cell_motion,
  title: "My App",
  keyboard_enhancements: [:disambiguate, :report_events]
}
```

### Design decisions

- `view/1` returns a `%Tinct.View{}` struct, not a string. Terminal features
  (alt screen, mouse mode, cursor, title) are declared in the view. The
  framework handles state transitions.
- Components are modules, not processes. Only infrastructure (reader, renderer,
  app loop) are processes. Over-processing adds latency.
- Commands are `{module, function, args}` tuples spawned as Tasks. Results
  arrive as messages.
- Focus is managed by the framework, not individual components.

### Inspiration

- Bubble Tea v2's declarative View struct
- TermUI's Elm Architecture on GenServer
- ExRatatui's LiveView-style callbacks


## Layer 7: Widget Library

Pre-built components for common UI patterns.

### Core widgets (v0.1)

| Widget | Description | Priority |
|--------|-------------|----------|
| `Text` | Styled text display | P0 |
| `TextInput` | Single-line text input with cursor | P0 |
| `TextArea` | Multi-line text input | P1 |
| `List` | Selectable, scrollable list | P0 |
| `Table` | Columns, rows, selection, sorting | P1 |
| `Tabs` | Tab bar with switchable panels | P1 |
| `ScrollView` | Scrollable viewport for any content | P0 |
| `ProgressBar` | Determinate and indeterminate progress | P1 |
| `Spinner` | Activity indicator | P1 |
| `Static` | Log-style output above live area | P0 |
| `Border` | Bordered container (auto-connecting) | P0 |
| `StatusBar` | Fixed bar at top or bottom | P0 |

### Agent-specific widgets (v0.2)

| Widget | Description |
|--------|-------------|
| `Markdown` | Render markdown with syntax highlighting |
| `CodeBlock` | Syntax-highlighted code display |
| `StreamText` | Streaming text (LLM token-by-token output) |
| `ToolCall` | Collapsible tool call display |
| `CommandPalette` | Fuzzy-search command discovery |

### Design decisions

- Each widget is a module implementing `Tinct.Component`.
- Widgets are independently testable via headless rendering.
- `Static` component (from Ink) is critical: renders completed output above
  the live area. Perfect for agent conversations — past messages scroll up
  as static content, current streaming response is the live area.

### Inspiration

- Ink's `<Static>` component
- Textual's command palette
- Bubble Tea's Bubbles library


## Testing

### Headless rendering

```elixir
test "counter increments" do
  {view, _model} = Tinct.Test.render(Counter, %{count: 0})
  assert Tinct.Test.contains?(view, "Count: 0")

  {view, _model} = Tinct.Test.send_key(view, :up)
  assert Tinct.Test.contains?(view, "Count: 1")
end
```

### Design decisions

- `Tinct.Test` renders to an in-memory buffer — no terminal needed.
- Send simulated events, assert on rendered output.
- Snapshot testing: capture expected buffer output, compare.

### Inspiration

- ExRatatui's headless test backend
- Textual's testing framework


## Process Architecture

```
┌─────────────────────────────────────────────┐
│              Tinct.App.Supervisor            │
├──────────┬───────────┬──────────────────────┤
│  Event   │   App     │    Renderer          │
│  Reader  │  (state   │    (diff +           │
│  (stdin) │   + loop) │     write)           │
└──────────┴───────────┴──────────────────────┘
              ↕
        ┌─────────────┐
        │ Task.Supervisor │  (for async commands)
        └─────────────┘
```

- **Event Reader**: reads stdin, parses events, sends to App
- **App**: holds model, runs update/view cycle, sends view to Renderer
- **Renderer**: diffs view against previous, writes ANSI to stdout
- **Task.Supervisor**: runs async commands, sends results back to App

Each is a separate BEAM process. Crash isolation is automatic.


## File Structure

```
lib/
├── tinct.ex                    # Public API: run/1, quit/1
├── tinct/
│   ├── terminal.ex             # Raw mode, alternate screen
│   ├── terminal/
│   │   ├── capabilities.ex     # Color profile, keyboard protocol detection
│   │   └── writer.ex           # Buffered ANSI output
│   ├── event.ex                # Event type definitions
│   ├── event/
│   │   ├── parser.ex           # Escape sequence → event
│   │   └── reader.ex           # GenServer reading stdin
│   ├── buffer.ex               # 2D cell grid
│   ├── buffer/
│   │   ├── cell.ex             # Single cell struct
│   │   └── diff.ex             # Buffer comparison
│   ├── ansi.ex                 # ANSI escape sequence encoding
│   ├── layout.ex               # Element tree → positioned rects
│   ├── layout/
│   │   ├── flex.ex             # Flexbox solver
│   │   └── rect.ex             # Rectangle struct
│   ├── style.ex                # Style struct and DSL
│   ├── theme.ex                # Named themes
│   ├── color.ex                # Color types and downsampling
│   ├── component.ex            # Component behaviour
│   ├── view.ex                 # Declarative view struct
│   ├── command.ex              # Async side effects
│   ├── cursor.ex               # Cursor position/shape/color
│   ├── app.ex                  # Main event loop GenServer
│   ├── app/
│   │   └── supervisor.ex       # OTP supervisor
│   ├── ui.ex                   # DSL macros (column, row, text, etc.)
│   ├── test.ex                 # Headless test helpers
│   └── widgets/
│       ├── text.ex
│       ├── text_input.ex
│       ├── list.ex
│       ├── table.ex
│       ├── scroll_view.ex
│       ├── static.ex
│       ├── border.ex
│       ├── status_bar.ex
│       ├── tabs.ex
│       ├── progress_bar.ex
│       └── spinner.ex
```


## Build Order

Layers are built bottom-up. Each layer is independently testable before
the next layer begins.

1. Terminal Backend — raw mode, ANSI output, capability detection
2. Event System — input parsing, key/mouse events
3. Rendering Engine — cell buffer, diffing, ANSI encoding
4. Layout Engine — flexbox solver, constraint resolution
5. Styling Engine — styles, themes, color downsampling
6. Component System — Elm Architecture, app lifecycle, commands
7. Widget Library — built in parallel, one widget per agent
8. Testing Framework — headless rendering, snapshot tests
9. Integration — example apps, documentation
