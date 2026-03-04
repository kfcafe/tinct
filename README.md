# Tinct

A terminal UI framework for Elixir.

Tinct brings modern TUI development to the BEAM — combining the Elm Architecture
with Elixir's process model, pattern matching, and OTP supervision to build
terminal applications that are fast, composable, and fault-tolerant.

## Status

Early development. Not yet usable.

## Design Principles

- **Declarative views** — describe what the UI should look like, not how to draw it
- **CSS-like styling** — separate presentation from logic
- **Flexbox layout** — the layout model developers already know
- **Progressive enhancement** — gracefully adapt to terminal capabilities
- **BEAM-native** — processes, supervision, hot reload, not bolted on as afterthoughts
- **Testable** — headless rendering to buffer, assert on output, no terminal needed

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design.

## License

MIT
