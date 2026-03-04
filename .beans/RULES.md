# Project Rules

## Language
Elixir. Pure Elixir — no NIFs, no Ports for core functionality.

## Verify Gate
Every bean must pass:
```bash
cd /Users/asher/tinct && mix compile --warnings-as-errors && mix test --no-start
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

## File Naming
- `lib/tinct/module_name.ex` for `Tinct.ModuleName`
- `test/tinct/module_name_test.exs` for tests
- Nested modules: `lib/tinct/buffer/cell.ex` for `Tinct.Buffer.Cell`
