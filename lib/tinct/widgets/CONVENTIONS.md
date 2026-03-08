# Widget Conventions

## Structure
- Every widget implements `Tinct.Component` via `use Tinct.Component`
- Every widget has `init/1`, `update/2`, `view/1` callbacks with `@impl Tinct.Component`
- Widget state is a map or named struct (e.g., `TextInput.Model`) — never a bare term
- `init/1` accepts options with sensible defaults via `Keyword.get/3`

## Messages & Updates
- `update/2` matches specific messages with explicit clauses
- Always include a fall-through: `def update(model, _msg), do: model`
- Return `{model, command}` tuple for side effects, plain `model` otherwise
- Use `{:set_content, value}` style tagged tuples for widget-specific messages

## Views
- `view/1` returns `Tinct.View.new(element_tree)` — always a `View` struct
- Build element trees with `Tinct.Element` builders, not raw struct construction
- Apply widget styles via `Style.merge/2` when combining user styles with defaults

## Public API
- Expose helper functions for programmatic control (e.g., `set_value/2`, `focus/1`, `blur/1`)
- Provide a pure rendering function when useful (e.g., `Text.render_text/3`) for reuse by other widgets
- Document all init options in `@moduledoc` with a bulleted list

## DSL Integration
- Widgets that make sense as containers (like `Border`) provide an `element/2` function
- The `Tinct.UI` module wraps these as macros — widgets don't define their own macros

## Testing
- Each widget has a corresponding test at `test/tinct/widgets/<name>_test.exs`
- Tests use `Tinct.Test.render/2` and `Tinct.Test.contains?/2` — not direct element tree assertions
- Test `init/1` defaults, `update/2` message handling, and `view/1` rendering separately
- Use `Tinct.Test.send_key/2` to simulate user interaction
- Use `Tinct.Test.send_key_raw/2` when asserting on returned commands (e.g., `:quit`)
