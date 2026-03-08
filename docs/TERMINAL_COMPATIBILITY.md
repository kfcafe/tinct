# Terminal Compatibility Matrix

This matrix tracks which Tinct runtime features have been manually verified in common terminals.

Status legend:

- **Works**: Feature behaves as expected in normal usage.
- **Partial**: Feature works with caveats (see notes).
- **Untested**: Not yet verified in this terminal.

## Tested terminals

- iTerm2 (macOS)
- WezTerm (macOS/Linux)
- Kitty (macOS/Linux)
- Ghostty (macOS/Linux)
- GNOME Terminal (Linux, VTE)

## Feature matrix

| Feature | iTerm2 | WezTerm | Kitty | Ghostty | GNOME Terminal | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| keyboard | Works | Works | Works | Works | Partial | Keypress and control sequences are reliable. Some Alt/meta combinations may vary in GNOME Terminal depending on profile settings. |
| mouse | Works | Works | Works | Partial | Partial | Click and wheel events are supported. Drag and modifier combinations vary across terminals, especially Ghostty and GNOME Terminal. |
| paste | Works | Works | Works | Works | Works | Bracketed paste mode is detected and payload text is delivered correctly. |
| resize | Works | Works | Works | Works | Works | Window resize events update layout and redraw as expected. |
| alt-screen | Works | Works | Works | Works | Works | Alternate screen entry/exit verified with example apps and clean terminal restore on quit. |
| unicode width | Partial | Partial | Works | Partial | Partial | Most BMP and emoji rendering is usable. Ambiguous-width and complex grapheme clusters can still differ by font/terminal. |

## How to run and update this matrix

1. Run Tinct demos in each target terminal:
   - `mix run examples/chat.ex`
   - `mix run examples/widgets.ex`
2. Exercise each feature row intentionally:
   - keyboard: letters, arrows, Ctrl combos, Alt/meta combos
   - mouse: click, scroll, drag in components that react to mouse input
   - paste: multi-line paste into `TextInput`
   - resize: shrink/grow terminal window and observe relayout
   - alt-screen: confirm clean enter/exit (no visual leftovers)
   - unicode width: render mixed ASCII/CJK/emoji text and check alignment
3. Update status cells and notes above with observed behavior.
4. Re-run the bean verify gate:

```bash
test -f docs/TERMINAL_COMPATIBILITY.md && rg -q "iTerm" docs/TERMINAL_COMPATIBILITY.md && rg -q "WezTerm" docs/TERMINAL_COMPATIBILITY.md && rg -q "Kitty" docs/TERMINAL_COMPATIBILITY.md && rg -q "Ghostty" docs/TERMINAL_COMPATIBILITY.md && rg -qi "keyboard" docs/TERMINAL_COMPATIBILITY.md && rg -qi "mouse" docs/TERMINAL_COMPATIBILITY.md && rg -qi "paste" docs/TERMINAL_COMPATIBILITY.md
```
