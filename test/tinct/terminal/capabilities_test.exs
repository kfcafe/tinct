defmodule Tinct.Terminal.CapabilitiesTest do
  use ExUnit.Case, async: true

  alias Tinct.Terminal.Capabilities

  # All tests use detect/1 with an explicit env map so they're
  # deterministic regardless of the actual terminal environment.

  describe "detect/1 struct" do
    test "returns a %Capabilities{} struct" do
      caps = Capabilities.detect(%{tty: true})
      assert %Capabilities{} = caps
    end

    test "stores raw TERM and TERM_PROGRAM values" do
      caps =
        Capabilities.detect(%{
          "TERM" => "xterm-256color",
          "TERM_PROGRAM" => "iTerm.app",
          tty: true
        })

      assert caps.term == "xterm-256color"
      assert caps.term_program == "iTerm.app"
    end

    test "nil TERM and TERM_PROGRAM when not provided" do
      caps = Capabilities.detect(%{tty: false})
      assert caps.term == nil
      assert caps.term_program == nil
    end
  end

  describe "color profile — NO_COLOR" do
    test "NO_COLOR set to any value returns :ascii" do
      caps = Capabilities.detect(%{"NO_COLOR" => "1", tty: true})
      assert caps.color_profile == :ascii
    end

    test "NO_COLOR empty string still returns :ascii (per no-color.org spec)" do
      caps = Capabilities.detect(%{"NO_COLOR" => "", tty: true})
      assert caps.color_profile == :ascii
    end

    test "NO_COLOR takes priority over COLORTERM=truecolor" do
      caps = Capabilities.detect(%{"NO_COLOR" => "1", "COLORTERM" => "truecolor", tty: true})
      assert caps.color_profile == :ascii
    end
  end

  describe "color profile — COLORTERM" do
    test "COLORTERM=truecolor returns :true_color" do
      caps = Capabilities.detect(%{"COLORTERM" => "truecolor", tty: true})
      assert caps.color_profile == :true_color
    end

    test "COLORTERM=24bit returns :true_color" do
      caps = Capabilities.detect(%{"COLORTERM" => "24bit", tty: true})
      assert caps.color_profile == :true_color
    end

    test "COLORTERM=unknown does not trigger :true_color" do
      caps = Capabilities.detect(%{"COLORTERM" => "unknown", "TERM" => "xterm", tty: true})
      assert caps.color_profile == :ansi16
    end
  end

  describe "color profile — TERM with 256color" do
    test "TERM=xterm-256color returns :ansi256" do
      caps = Capabilities.detect(%{"TERM" => "xterm-256color", tty: true})
      assert caps.color_profile == :ansi256
    end

    test "TERM=screen-256color returns :ansi256" do
      caps = Capabilities.detect(%{"TERM" => "screen-256color", tty: true})
      assert caps.color_profile == :ansi256
    end

    test "TERM containing 256color anywhere returns :ansi256" do
      caps = Capabilities.detect(%{"TERM" => "tmux-256color", tty: true})
      assert caps.color_profile == :ansi256
    end
  end

  describe "color profile — basic terminal" do
    test "TERM set and TTY returns :ansi16" do
      caps = Capabilities.detect(%{"TERM" => "xterm", tty: true})
      assert caps.color_profile == :ansi16
    end

    test "TERM set but not a TTY returns :no_tty" do
      caps = Capabilities.detect(%{"TERM" => "xterm", tty: false})
      assert caps.color_profile == :no_tty
    end
  end

  describe "color profile — no terminal" do
    test "no TERM and not a TTY returns :no_tty" do
      caps = Capabilities.detect(%{tty: false})
      assert caps.color_profile == :no_tty
    end

    test "no TERM but is a TTY returns :no_tty" do
      caps = Capabilities.detect(%{tty: true})
      assert caps.color_profile == :no_tty
    end
  end

  describe "kitty keyboard protocol" do
    test "TERM=xterm-kitty detects kitty keyboard" do
      caps = Capabilities.detect(%{"TERM" => "xterm-kitty", tty: true})
      assert caps.kitty_keyboard
    end

    test "TERM_PROGRAM=ghostty detects kitty keyboard" do
      caps = Capabilities.detect(%{"TERM_PROGRAM" => "ghostty", "TERM" => "xterm", tty: true})
      assert caps.kitty_keyboard
    end

    test "TERM_PROGRAM=kitty detects kitty keyboard" do
      caps = Capabilities.detect(%{"TERM_PROGRAM" => "kitty", "TERM" => "xterm", tty: true})
      assert caps.kitty_keyboard
    end

    test "TERM_PROGRAM=WezTerm detects kitty keyboard" do
      caps = Capabilities.detect(%{"TERM_PROGRAM" => "WezTerm", "TERM" => "xterm", tty: true})
      assert caps.kitty_keyboard
    end

    test "TERM_PROGRAM=iTerm.app detects kitty keyboard" do
      caps = Capabilities.detect(%{"TERM_PROGRAM" => "iTerm.app", "TERM" => "xterm", tty: true})
      assert caps.kitty_keyboard
    end

    test "TERM_PROGRAM=Alacritty detects kitty keyboard" do
      caps = Capabilities.detect(%{"TERM_PROGRAM" => "Alacritty", "TERM" => "xterm", tty: true})
      assert caps.kitty_keyboard
    end

    test "all known kitty keyboard terminals are detected" do
      terminals = ~w(iTerm.app WezTerm ghostty rio contour foot kitty Alacritty)

      for term_program <- terminals do
        caps =
          Capabilities.detect(%{"TERM_PROGRAM" => term_program, "TERM" => "xterm", tty: true})

        assert caps.kitty_keyboard, "Expected kitty keyboard for TERM_PROGRAM=#{term_program}"
      end
    end

    test "unknown TERM_PROGRAM does not detect kitty keyboard" do
      caps = Capabilities.detect(%{"TERM_PROGRAM" => "unknown", "TERM" => "xterm", tty: true})
      refute caps.kitty_keyboard
    end

    test "no TERM or TERM_PROGRAM does not detect kitty keyboard" do
      caps = Capabilities.detect(%{tty: true})
      refute caps.kitty_keyboard
    end
  end

  describe "mouse support" do
    test "modern terminal supports mouse" do
      caps = Capabilities.detect(%{"TERM" => "xterm-256color", tty: true})
      assert caps.mouse
    end

    test "dumb terminal does not support mouse" do
      caps = Capabilities.detect(%{"TERM" => "dumb", tty: true})
      refute caps.mouse
    end

    test "no TERM does not support mouse" do
      caps = Capabilities.detect(%{tty: true})
      refute caps.mouse
    end
  end

  describe "bracketed paste" do
    test "modern terminal supports bracketed paste" do
      caps = Capabilities.detect(%{"TERM" => "xterm-256color", tty: true})
      assert caps.bracketed_paste
    end

    test "dumb terminal does not support bracketed paste" do
      caps = Capabilities.detect(%{"TERM" => "dumb", tty: true})
      refute caps.bracketed_paste
    end

    test "no TERM does not support bracketed paste" do
      caps = Capabilities.detect(%{tty: true})
      refute caps.bracketed_paste
    end
  end

  describe "synchronized rendering (Mode 2026)" do
    test "xterm-kitty supports sync rendering" do
      caps = Capabilities.detect(%{"TERM" => "xterm-kitty", tty: true})
      assert caps.sync_rendering
    end

    test "known TERM_PROGRAM supports sync rendering" do
      for term_program <- ~w(iTerm.app WezTerm kitty foot contour ghostty) do
        caps =
          Capabilities.detect(%{"TERM_PROGRAM" => term_program, "TERM" => "xterm", tty: true})

        assert caps.sync_rendering, "Expected sync rendering for TERM_PROGRAM=#{term_program}"
      end
    end

    test "unknown terminal does not support sync rendering" do
      caps = Capabilities.detect(%{"TERM" => "xterm", "TERM_PROGRAM" => "unknown", tty: true})
      refute caps.sync_rendering
    end

    test "no TERM_PROGRAM does not support sync rendering" do
      caps = Capabilities.detect(%{"TERM" => "xterm", tty: true})
      refute caps.sync_rendering
    end
  end

  describe "Unicode width (Mode 2027)" do
    test "xterm-kitty supports unicode width" do
      caps = Capabilities.detect(%{"TERM" => "xterm-kitty", tty: true})
      assert caps.unicode_width
    end

    test "known TERM_PROGRAM supports unicode width" do
      for term_program <- ~w(WezTerm kitty foot contour ghostty) do
        caps =
          Capabilities.detect(%{"TERM_PROGRAM" => term_program, "TERM" => "xterm", tty: true})

        assert caps.unicode_width, "Expected unicode width for TERM_PROGRAM=#{term_program}"
      end
    end

    test "unknown terminal does not support unicode width" do
      caps = Capabilities.detect(%{"TERM" => "xterm", "TERM_PROGRAM" => "unknown", tty: true})
      refute caps.unicode_width
    end
  end

  describe "sensible defaults" do
    test "empty env with no TTY returns conservative defaults" do
      caps = Capabilities.detect(%{tty: false})
      assert caps.color_profile == :no_tty
      refute caps.kitty_keyboard
      refute caps.mouse
      refute caps.bracketed_paste
      refute caps.sync_rendering
      refute caps.unicode_width
    end

    test "typical modern terminal env returns full capabilities" do
      caps =
        Capabilities.detect(%{
          "TERM" => "xterm-256color",
          "COLORTERM" => "truecolor",
          "TERM_PROGRAM" => "ghostty",
          tty: true
        })

      assert caps.color_profile == :true_color
      assert caps.kitty_keyboard
      assert caps.mouse
      assert caps.bracketed_paste
      assert caps.sync_rendering
      assert caps.unicode_width
    end
  end

  describe "public convenience functions" do
    # These read from the real environment, so we just verify they
    # return the correct types without asserting specific values.

    test "color_profile/0 returns a valid color profile atom" do
      assert Capabilities.color_profile() in [:true_color, :ansi256, :ansi16, :ascii, :no_tty]
    end

    test "supports_kitty_keyboard?/0 returns a boolean" do
      assert is_boolean(Capabilities.supports_kitty_keyboard?())
    end

    test "supports_mouse?/0 returns a boolean" do
      assert is_boolean(Capabilities.supports_mouse?())
    end

    test "supports_bracketed_paste?/0 returns a boolean" do
      assert is_boolean(Capabilities.supports_bracketed_paste?())
    end

    test "supports_sync_rendering?/0 returns a boolean" do
      assert is_boolean(Capabilities.supports_sync_rendering?())
    end

    test "supports_unicode_width?/0 returns a boolean" do
      assert is_boolean(Capabilities.supports_unicode_width?())
    end
  end
end
