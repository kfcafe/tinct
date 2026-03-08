# Project Rules

## Language
Elixir. Pure Elixir — no NIFs, no Ports for core functionality.

## Verify Gate
Every bean must pass:
```bash
mix compile --warnings-as-errors && mix test --no-start
```
Individual beans add specific test file assertions on top of this.

## Code Style
- `mix format` compliance (auto-enforced)
- `@moduledoc` on every public module
- `@doc` on every public function
- `@spec` on every public function
- `@impl true` on every behaviour callback
- Descriptive names: `parse_escape_sequence` not `parse_seq`
- Pattern matching over conditionals
- Small, focused functions — each does one thing

## Architecture
- Layers depend only on layers below (see ARCHITECTURE.md)
- No circular dependencies between modules
- Components are modules, not processes (only infrastructure uses GenServer)
- State structs, not bare maps, for GenServer state
- Extract business logic into pure functions — GenServer callbacks are thin wrappers

## Testing
- Every module gets a corresponding test file in test/
- Test behaviour, not implementation
- Use ExUnit with `async: true` where possible
- Doctests on key public functions
- Test file structure mirrors lib/ structure

## Forbidden Patterns
- No `String.to_atom/1` on untrusted input
- No bare `_` catch-all in case/with when return types are known
- No complex `else` blocks in `with` statements
- No `Application.get_env` at compile time in module bodies
- No mocks — use behaviour-based injection if needed

## Component Pattern (Elm Architecture)
- `update/2` returns either `model` or `{model, command}` — never call side effects directly
- `view/1` always returns a `%Tinct.View{}` struct, never raw strings or iodata
- Commands are data — `Command.async/2`, `Command.quit/0`, `Command.batch/1` — the runtime executes them
- Use `@impl Tinct.Component` (not `@impl true`) on component callbacks for clarity

## UI Construction
- Users build UIs with `import Tinct.UI` and the block DSL (`column do ... end`)
- Element builders (`Element.text/2`, `Element.row/2`) are the underlying layer — DSL wraps them
- Style sugar: `color:` → `fg:`, `background:` → `bg:` in the DSL

## Testing Components
- Use `Tinct.Test.render/2` → `Tinct.Test.send_key/2` → `Tinct.Test.contains?/2`
- Never start real terminal processes in tests — `Tinct.Test` renders to in-memory buffers
- Use `send_event_raw/2` or `send_key_raw/2` when you need to assert on returned commands

## File Naming
- `lib/tinct/module_name.ex` for `Tinct.ModuleName`
- `test/tinct/module_name_test.exs` for tests
- Nested modules: `lib/tinct/buffer/cell.ex` for `Tinct.Buffer.Cell`
