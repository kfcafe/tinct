# Layout Conventions

## Entry Point
- `Layout.render/3` is the main entry point: element tree + dimensions + theme → buffer
- The pipeline is: preprocess → flex resolve → render to buffer
- No processes, no state — layout is a pure computation

## Flex Solver
- `Flex.resolve/2` is a pure function: element tree + available rect → list of `{element, rect}` tuples
- Supports direction, justify, align, wrap, grow, shrink, gap
- Integer character-cell dimensions only — no fractional layout

## Rect
- `Rect` is a simple struct: `x`, `y`, `width`, `height`
- All fields are non-negative integers
- Rects represent positioned areas in the character grid

## Borders
- `Layout.Border` handles box-drawing character rendering
- Border styles: `:single`, `:double`, `:round`, `:bold`
- Borders auto-connect when adjacent — intersections produce proper characters (┬, ├, ┼, etc.)
- Bordered elements add 1-cell padding on each side automatically (handled in preprocessing)

## Adding New Layout Features
- Keep the flex solver pure — no side effects, no terminal I/O
- Test with small element trees and assert on resulting rects and buffer content
- Use `Tinct.Test.render_view/2` for integration-level layout tests
