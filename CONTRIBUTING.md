# Contributing to Tinct

Thanks for helping improve Tinct.

## Development Setup

```bash
git clone https://github.com/kfcafe/tinct.git
cd tinct
mix deps.get
```

Use Elixir `~> 1.16`.

## Local Quality Gates

Run these before opening a pull request:

```bash
mix format
mix compile --warnings-as-errors
mix test --no-start
mix credo --strict
mix dialyzer
```

For faster iteration while developing, run focused tests first:

```bash
mix test test/path/to/file_test.exs
```

## Code and Architecture Expectations

- Keep modules small and focused.
- Add `@moduledoc`, `@doc`, and `@spec` for public API.
- Follow layer boundaries documented in `ARCHITECTURE.md`.
- Prefer pure functions for business logic; keep GenServer callbacks thin.
- Avoid unsafe patterns such as `String.to_atom/1` on untrusted input.

## Pull Request Workflow

1. Create a branch with one focused change.
2. Add or update tests for behavior changes.
3. Update docs when changing public APIs or expected behavior.
4. Confirm all quality gates pass locally.
5. Open a pull request describing:
   - what changed,
   - why it changed,
   - how it was tested.

## Reporting Issues

Use GitHub Issues for bugs and feature requests:

- https://github.com/kfcafe/tinct/issues

For security vulnerabilities, follow `SECURITY.md` instead of opening a public issue.
