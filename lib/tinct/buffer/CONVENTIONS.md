# Buffer & Rendering Conventions

## Buffer
- `Buffer` is a 2D grid of `Cell` structs, indexed by `{col, row}` tuples in a map
- All coordinates are zero-indexed — `{0, 0}` is top-left
- Buffers are immutable — `put/4` and `set_style/5` return new buffers
- `Buffer.new/2` pre-fills all cells — no sparse/lazy allocation

## Cell
- `Cell` holds a single character + style attributes (fg, bg, bold, italic, etc.)
- Character is always a single grapheme string, default `" "` (space)
- Style attributes use `nil` for "inherit" and concrete values for explicit styling

## Diff
- `Diff.diff/2` compares two buffers and produces minimal change operations
- `Diff.full_render/1` renders an entire buffer (used for the first frame)
- Diff output is iodata — lists of strings and escape sequences, not a single binary

## ANSI
- `Tinct.ANSI` encodes operations as escape sequences — pure functions, no I/O
- ANSI functions return iodata, not binaries — callers accumulate and flush once
- Terminal state changes (alt screen, mouse, cursor) are separate from content rendering
