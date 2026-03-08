# Event System Conventions

## Event Types
- Events are plain structs — no processes, no behaviours
- All event types live in `event.ex` as sibling `defmodule` blocks (Key, Mouse, Paste, Resize, Focus)
- New event types follow the pattern: struct with `@type t`, `defstruct`, `@moduledoc` with doctest examples

## Constructors
- The `Tinct.Event` module provides convenience constructors (`key/1`, `key/2`, `ctrl_c/0`)
- Constructors set sensible defaults (e.g., `type: :press`, `mod: []`)
- Printable key events set `text:` automatically; special keys leave `text: nil`

## Parser
- `event/parser.ex` is a pure function — bytes in, events out, no side effects
- The parser is a state machine that handles partial escape sequences
- Test the parser with raw byte sequences, not convenience constructors

## Reader
- `event/reader.ex` is the only GenServer in this layer
- It reads stdin and sends `{:event, event}` messages to a target process
- Supports `:stdio` and `{:test, pid}` input modes
- In test mode, events are sent directly — no stdin reading
