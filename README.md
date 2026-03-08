# Tinct

Tinct is a pure Elixir terminal UI framework.

It brings an Elm-style component model (`init/update/view`) to the BEAM, with
headless testing and a small set of composable widgets.

## Status

**Alpha (`0.1.0-dev`)**.

Tinct is usable for experiments and internal tools, but it is not stable yet.
Expect API changes while the core architecture settles.

## API stability

We are preparing for beta and now publish explicit API stability expectations.

- During `0.x`, API compatibility is not guaranteed across every commit.
- For beta tags (`0.2.0-beta.x` and later), we aim to keep core public APIs stable and use a documented deprecation process before removals.
- Breaking API changes are called out in release notes and in a dedicated policy doc.

Read the full policy in [docs/API_STABILITY.md](docs/API_STABILITY.md), including what is stable, what can still change, deprecation windows, and versioning expectations.

## Quick Start

Prerequisites:

- Elixir `~> 1.16`

Run the examples:

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

In the demos, press `q` or `ctrl+c` to quit.

## Installation (alpha/dev expectations)

Right now, this repository is the source of truth.

- The project version is `0.1.0-dev`
- Public APIs may change between commits
- Packaging/release flow is still being finalized for a stable developer experience

If you are evaluating Tinct, prefer pinning to a commit and planning for updates.

## What works now

- Elm Architecture component flow (`init/1`, `update/2`, `view/1`)
- Declarative view building (`Tinct.UI` DSL + `Tinct.Element`)
- Core terminal event handling (keyboard, paste, mouse, resize)
- Layout and rendering pipeline (buffer + diff + ANSI output)
- Built-in widgets with tests:
  - `Text`, `TextInput`, `List`, `Table`, `Tabs`
  - `ProgressBar`, `Spinner`, `ScrollView`, `Static`
  - `Border`, `StatusBar`
- Headless UI testing helpers via `Tinct.Test`

## What is next

- Stabilize API shape and reduce breaking changes
- Improve onboarding docs and cookbook-style examples
- Expand real-world examples beyond demos
- Tighten packaging/release workflow for easier adoption

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for layer-by-layer design details.

## License

MIT
