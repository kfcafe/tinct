defmodule Tinct.ANSITest do
  use ExUnit.Case, async: true

  alias Tinct.ANSI

  doctest Tinct.ANSI

  defp to_binary(iodata), do: IO.iodata_to_binary(iodata)

  describe "move_to/2" do
    test "zero-indexed origin" do
      assert to_binary(ANSI.move_to(0, 0)) == "\e[1;1H"
    end

    test "converts zero-indexed to one-indexed" do
      assert to_binary(ANSI.move_to(9, 4)) == "\e[5;10H"
    end

    test "large coordinates" do
      assert to_binary(ANSI.move_to(199, 49)) == "\e[50;200H"
    end
  end

  describe "relative cursor movement" do
    test "move_up/1" do
      assert to_binary(ANSI.move_up(1)) == "\e[1A"
      assert to_binary(ANSI.move_up(3)) == "\e[3A"
    end

    test "move_down/1" do
      assert to_binary(ANSI.move_down(1)) == "\e[1B"
      assert to_binary(ANSI.move_down(5)) == "\e[5B"
    end

    test "move_right/1" do
      assert to_binary(ANSI.move_right(1)) == "\e[1C"
      assert to_binary(ANSI.move_right(2)) == "\e[2C"
    end

    test "move_left/1" do
      assert to_binary(ANSI.move_left(1)) == "\e[1D"
      assert to_binary(ANSI.move_left(4)) == "\e[4D"
    end
  end

  describe "cursor visibility" do
    test "hide_cursor/0" do
      assert to_binary(ANSI.hide_cursor()) == "\e[?25l"
    end

    test "show_cursor/0" do
      assert to_binary(ANSI.show_cursor()) == "\e[?25h"
    end
  end

  describe "cursor_shape/1" do
    test "block cursor" do
      assert to_binary(ANSI.cursor_shape(:block)) == "\e[2 q"
    end

    test "underline cursor" do
      assert to_binary(ANSI.cursor_shape(:underline)) == "\e[4 q"
    end

    test "bar cursor" do
      assert to_binary(ANSI.cursor_shape(:bar)) == "\e[6 q"
    end
  end

  describe "save_cursor/0 and restore_cursor/0" do
    test "save uses DECSC" do
      assert to_binary(ANSI.save_cursor()) == "\e7"
    end

    test "restore uses DECRC" do
      assert to_binary(ANSI.restore_cursor()) == "\e8"
    end
  end

  describe "screen control" do
    test "clear_screen/0" do
      assert to_binary(ANSI.clear_screen()) == "\e[2J"
    end

    test "clear_line/0" do
      assert to_binary(ANSI.clear_line()) == "\e[2K"
    end

    test "clear_to_end_of_line/0" do
      assert to_binary(ANSI.clear_to_end_of_line()) == "\e[K"
    end
  end

  describe "alternate screen" do
    test "enter_alt_screen/0" do
      assert to_binary(ANSI.enter_alt_screen()) == "\e[?1049h"
    end

    test "exit_alt_screen/0" do
      assert to_binary(ANSI.exit_alt_screen()) == "\e[?1049l"
    end
  end

  describe "scrolling" do
    test "scroll_up/1" do
      assert to_binary(ANSI.scroll_up(1)) == "\e[1S"
      assert to_binary(ANSI.scroll_up(3)) == "\e[3S"
    end

    test "scroll_down/1" do
      assert to_binary(ANSI.scroll_down(1)) == "\e[1T"
      assert to_binary(ANSI.scroll_down(2)) == "\e[2T"
    end
  end

  describe "sgr/1" do
    test "single attribute" do
      assert to_binary(ANSI.sgr(bold: true)) == "\e[1m"
      assert to_binary(ANSI.sgr(dim: true)) == "\e[2m"
      assert to_binary(ANSI.sgr(italic: true)) == "\e[3m"
      assert to_binary(ANSI.sgr(underline: true)) == "\e[4m"
      assert to_binary(ANSI.sgr(blink: true)) == "\e[5m"
      assert to_binary(ANSI.sgr(inverse: true)) == "\e[7m"
      assert to_binary(ANSI.sgr(strikethrough: true)) == "\e[9m"
    end

    test "combined text attributes" do
      assert to_binary(ANSI.sgr(bold: true, italic: true)) == "\e[1;3m"
    end

    test "bold with foreground color" do
      assert to_binary(ANSI.sgr(bold: true, fg: :red)) == "\e[1;31m"
    end

    test "foreground and background together" do
      assert to_binary(ANSI.sgr(fg: :red, bg: :blue)) == "\e[31;44m"
    end

    test "complex combination" do
      result = to_binary(ANSI.sgr(bold: true, underline: true, fg: :green, bg: :black))
      assert result == "\e[1;4;32;40m"
    end

    test "false attributes produce no codes" do
      assert ANSI.sgr(bold: false) == []
    end

    test "empty list produces no output" do
      assert ANSI.sgr([]) == []
    end

    test "mixed true and false attributes" do
      assert to_binary(ANSI.sgr(bold: false, italic: true)) == "\e[3m"
    end

    test "with RGB color" do
      result = to_binary(ANSI.sgr(bold: true, fg: {:rgb, 255, 128, 0}))
      assert result == "\e[1;38;2;255;128;0m"
    end

    test "with indexed color" do
      result = to_binary(ANSI.sgr(fg: {:indexed, 196}))
      assert result == "\e[38;5;196m"
    end
  end

  describe "reset/0" do
    test "produces SGR 0" do
      assert to_binary(ANSI.reset()) == "\e[0m"
    end
  end

  describe "fg_color/1" do
    test "named colors (0-7)" do
      assert to_binary(ANSI.fg_color(:black)) == "\e[30m"
      assert to_binary(ANSI.fg_color(:red)) == "\e[31m"
      assert to_binary(ANSI.fg_color(:green)) == "\e[32m"
      assert to_binary(ANSI.fg_color(:yellow)) == "\e[33m"
      assert to_binary(ANSI.fg_color(:blue)) == "\e[34m"
      assert to_binary(ANSI.fg_color(:magenta)) == "\e[35m"
      assert to_binary(ANSI.fg_color(:cyan)) == "\e[36m"
      assert to_binary(ANSI.fg_color(:white)) == "\e[37m"
    end

    test "bright colors (8-15)" do
      assert to_binary(ANSI.fg_color(:bright_black)) == "\e[90m"
      assert to_binary(ANSI.fg_color(:bright_red)) == "\e[91m"
      assert to_binary(ANSI.fg_color(:bright_green)) == "\e[92m"
      assert to_binary(ANSI.fg_color(:bright_yellow)) == "\e[93m"
      assert to_binary(ANSI.fg_color(:bright_blue)) == "\e[94m"
      assert to_binary(ANSI.fg_color(:bright_magenta)) == "\e[95m"
      assert to_binary(ANSI.fg_color(:bright_cyan)) == "\e[96m"
      assert to_binary(ANSI.fg_color(:bright_white)) == "\e[97m"
    end

    test "256-color indexed" do
      assert to_binary(ANSI.fg_color({:indexed, 0})) == "\e[38;5;0m"
      assert to_binary(ANSI.fg_color({:indexed, 196})) == "\e[38;5;196m"
      assert to_binary(ANSI.fg_color({:indexed, 255})) == "\e[38;5;255m"
    end

    test "RGB" do
      assert to_binary(ANSI.fg_color({:rgb, 255, 128, 0})) == "\e[38;2;255;128;0m"
      assert to_binary(ANSI.fg_color({:rgb, 0, 0, 0})) == "\e[38;2;0;0;0m"
    end

    test "default" do
      assert to_binary(ANSI.fg_color(:default)) == "\e[39m"
    end
  end

  describe "bg_color/1" do
    test "named colors (0-7)" do
      assert to_binary(ANSI.bg_color(:black)) == "\e[40m"
      assert to_binary(ANSI.bg_color(:red)) == "\e[41m"
      assert to_binary(ANSI.bg_color(:green)) == "\e[42m"
      assert to_binary(ANSI.bg_color(:blue)) == "\e[44m"
      assert to_binary(ANSI.bg_color(:white)) == "\e[47m"
    end

    test "bright colors (8-15)" do
      assert to_binary(ANSI.bg_color(:bright_black)) == "\e[100m"
      assert to_binary(ANSI.bg_color(:bright_red)) == "\e[101m"
      assert to_binary(ANSI.bg_color(:bright_white)) == "\e[107m"
    end

    test "256-color indexed" do
      assert to_binary(ANSI.bg_color({:indexed, 42})) == "\e[48;5;42m"
      assert to_binary(ANSI.bg_color({:indexed, 0})) == "\e[48;5;0m"
    end

    test "RGB" do
      assert to_binary(ANSI.bg_color({:rgb, 0, 128, 255})) == "\e[48;2;0;128;255m"
    end

    test "default" do
      assert to_binary(ANSI.bg_color(:default)) == "\e[49m"
    end
  end

  describe "synchronized rendering" do
    test "begin_sync/0" do
      assert to_binary(ANSI.begin_sync()) == "\e[?2026h"
    end

    test "end_sync/0" do
      assert to_binary(ANSI.end_sync()) == "\e[?2026l"
    end
  end

  describe "mouse" do
    test "enable_mouse_cell/0 enables cell motion and SGR encoding" do
      assert to_binary(ANSI.enable_mouse_cell()) == "\e[?1002h\e[?1006h"
    end

    test "disable_mouse/0 disables cell motion and SGR encoding" do
      assert to_binary(ANSI.disable_mouse()) == "\e[?1002l\e[?1006l"
    end

    test "enable_mouse_all/0 enables all motion and SGR encoding" do
      assert to_binary(ANSI.enable_mouse_all()) == "\e[?1003h\e[?1006h"
    end
  end

  describe "bracketed paste" do
    test "enable_bracketed_paste/0" do
      assert to_binary(ANSI.enable_bracketed_paste()) == "\e[?2004h"
    end

    test "disable_bracketed_paste/0" do
      assert to_binary(ANSI.disable_bracketed_paste()) == "\e[?2004l"
    end
  end

  describe "unicode width" do
    test "enable_unicode_width/0" do
      assert to_binary(ANSI.enable_unicode_width()) == "\e[?2027h"
    end

    test "disable_unicode_width/0" do
      assert to_binary(ANSI.disable_unicode_width()) == "\e[?2027l"
    end
  end

  describe "iodata compliance" do
    test "all functions return valid iodata" do
      results = [
        ANSI.move_to(0, 0),
        ANSI.move_up(1),
        ANSI.move_down(1),
        ANSI.move_left(1),
        ANSI.move_right(1),
        ANSI.hide_cursor(),
        ANSI.show_cursor(),
        ANSI.cursor_shape(:block),
        ANSI.cursor_shape(:underline),
        ANSI.cursor_shape(:bar),
        ANSI.save_cursor(),
        ANSI.restore_cursor(),
        ANSI.clear_screen(),
        ANSI.clear_line(),
        ANSI.clear_to_end_of_line(),
        ANSI.enter_alt_screen(),
        ANSI.exit_alt_screen(),
        ANSI.scroll_up(1),
        ANSI.scroll_down(1),
        ANSI.sgr(bold: true, fg: :red),
        ANSI.sgr([]),
        ANSI.reset(),
        ANSI.fg_color(:red),
        ANSI.fg_color(:bright_red),
        ANSI.fg_color({:indexed, 42}),
        ANSI.fg_color({:rgb, 255, 0, 0}),
        ANSI.fg_color(:default),
        ANSI.bg_color(:blue),
        ANSI.bg_color(:bright_blue),
        ANSI.bg_color({:indexed, 42}),
        ANSI.bg_color({:rgb, 0, 128, 255}),
        ANSI.bg_color(:default),
        ANSI.begin_sync(),
        ANSI.end_sync(),
        ANSI.enable_mouse_cell(),
        ANSI.disable_mouse(),
        ANSI.enable_mouse_all(),
        ANSI.enable_bracketed_paste(),
        ANSI.disable_bracketed_paste(),
        ANSI.enable_unicode_width(),
        ANSI.disable_unicode_width()
      ]

      for result <- results do
        assert is_binary(IO.iodata_to_binary(result))
      end
    end
  end
end
