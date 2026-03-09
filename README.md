# Tinct

[![CI](https://github.com/kfcafe/tinct/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/kfcafe/tinct/actions/workflows/ci.yml)

Tinct is a terminal UI framework written in pure Elixir.

It gives you an Elm-style component model (`init/update/view`) plus headless
rendering tests, so you can spend more time building your tool and less time
fighting ANSI escape sequences.

If you’ve built TUIs before: Tinct is trying to feel like LiveView development,
but in the terminal.

## Status

**Alpha (`0.1.0-dev`)**.

It works well enough for experiments and internal tools, but it’s not stable
yet. Expect breaking API changes while the architecture settles.

If you do use it right now, pin to a commit.

## API stability

During `0.x`, API compatibility is not guaranteed across every commit.

For beta tags (`0.2.0-beta.x` and later), the goal is stable core public APIs
with a documented deprecation process.

Full policy: [docs/API_STABILITY.md](docs/API_STABILITY.md)

## Quick Start

Prereqs:

- Elixir `~> 1.16`

Run the demos:

```bash
git clone https://github.com/kfcafe/tinct.git
cd tinct
mix deps.get

# Chat-style demo
mix run examples/chat.ex

# Multi-panel dashboard demo
mix run examples/dashboard.ex

# Widget-by-widget interactive showcase
mix run examples/widgets.ex
```

Press `q` or `ctrl+c` to quit.

## Installation (alpha / repo-first)

Right now, this repo is the source of truth.

If you want to try Tinct in another project, pin a commit in `mix.exs`:

```elixir
defp deps do
  [
    {:tinct, github: "kfcafe/tinct", ref: "<commit>"}
  ]
end
```

## What works now

- Elm Architecture flow (`init/1`, `update/2`, `view/1`)
- Declarative UI building (`Tinct.UI` DSL + `Tinct.Element`)
- Terminal input events: keyboard, paste, mouse, resize
- Layout + rendering pipeline (buffer + diff + ANSI output)
- Built-in widgets with tests:
  - `Text`, `TextInput`, `List`, `Table`, `Tabs`
  - `ProgressBar`, `Spinner`, `ScrollView`, `Static`
  - `Border`, `StatusBar`, `SplitPane`, `Tree`
- Headless UI testing via `Tinct.Test`

## Docs

- Architecture overview: [ARCHITECTURE.md](ARCHITECTURE.md)
- Terminal notes / manual verification matrix: [docs/TERMINAL_COMPATIBILITY.md](docs/TERMINAL_COMPATIBILITY.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
