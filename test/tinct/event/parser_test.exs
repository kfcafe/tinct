defmodule Tinct.Event.ParserTest do
  use ExUnit.Case, async: true

  alias Tinct.Event.{Focus, Key, Mouse, Paste}
  alias Tinct.Event.Parser

  doctest Tinct.Event.Parser

  describe "parse/1 — printable characters" do
    test "lowercase letter" do
      {[event], ""} = Parser.parse("a")
      assert %Key{key: "a", text: "a", mod: [], type: :press} = event
    end

    test "uppercase letter" do
      {[event], ""} = Parser.parse("Z")
      assert %Key{key: "Z", text: "Z"} = event
    end

    test "space" do
      {[event], ""} = Parser.parse(" ")
      assert %Key{key: " ", text: " "} = event
    end

    test "digit" do
      {[event], ""} = Parser.parse("1")
      assert %Key{key: "1", text: "1"} = event
    end

    test "symbol" do
      {[event], ""} = Parser.parse("!")
      assert %Key{key: "!", text: "!"} = event
    end
  end

  describe "parse/1 — control keys" do
    test "enter (CR)" do
      {[event], ""} = Parser.parse(<<13>>)
      assert %Key{key: :enter, mod: [], type: :press} = event
    end

    test "tab" do
      {[event], ""} = Parser.parse(<<9>>)
      assert %Key{key: :tab, mod: [], type: :press} = event
    end

    test "backspace (DEL 127)" do
      {[event], ""} = Parser.parse(<<127>>)
      assert %Key{key: :backspace, mod: [], type: :press} = event
    end

    test "backspace (BS 8)" do
      {[event], ""} = Parser.parse(<<8>>)
      assert %Key{key: :backspace, mod: [], type: :press} = event
    end
  end

  describe "parse/1 — escape key" do
    test "lone ESC returns as remaining bytes (incomplete)" do
      {[], "\e"} = Parser.parse("\e")
    end
  end

  describe "parse/1 — ctrl+letter" do
    test "ctrl+c (byte 3)" do
      {[event], ""} = Parser.parse(<<3>>)
      assert %Key{key: "c", mod: [:ctrl], type: :press, text: "c"} = event
    end

    test "ctrl+a (byte 1)" do
      {[event], ""} = Parser.parse(<<1>>)
      assert %Key{key: "a", mod: [:ctrl], type: :press, text: "a"} = event
    end

    test "ctrl+z (byte 26)" do
      {[event], ""} = Parser.parse(<<26>>)
      assert %Key{key: "z", mod: [:ctrl], type: :press, text: "z"} = event
    end

    test "tab (byte 9) is tab, not ctrl+i" do
      {[event], ""} = Parser.parse(<<9>>)
      assert %Key{key: :tab} = event
    end

    test "enter (byte 13) is enter, not ctrl+m" do
      {[event], ""} = Parser.parse(<<13>>)
      assert %Key{key: :enter} = event
    end
  end

  describe "parse/1 — arrow keys" do
    test "up arrow" do
      {[event], ""} = Parser.parse("\e[A")
      assert %Key{key: :up, mod: [], type: :press} = event
    end

    test "down arrow" do
      {[event], ""} = Parser.parse("\e[B")
      assert %Key{key: :down, mod: [], type: :press} = event
    end

    test "right arrow" do
      {[event], ""} = Parser.parse("\e[C")
      assert %Key{key: :right, mod: [], type: :press} = event
    end

    test "left arrow" do
      {[event], ""} = Parser.parse("\e[D")
      assert %Key{key: :left, mod: [], type: :press} = event
    end
  end

  describe "parse/1 — arrow keys with modifiers" do
    test "shift+up (\\e[1;2A)" do
      {[event], ""} = Parser.parse("\e[1;2A")
      assert %Key{key: :up, mod: [:shift], type: :press} = event
    end

    test "alt+down (\\e[1;3B)" do
      {[event], ""} = Parser.parse("\e[1;3B")
      assert %Key{key: :down, mod: [:alt], type: :press} = event
    end

    test "ctrl+right (\\e[1;5C)" do
      {[event], ""} = Parser.parse("\e[1;5C")
      assert %Key{key: :right, mod: [:ctrl], type: :press} = event
    end

    test "ctrl+shift+left (\\e[1;6D)" do
      {[event], ""} = Parser.parse("\e[1;6D")
      assert %Key{key: :left, mod: [:shift, :ctrl], type: :press} = event
    end
  end

  describe "parse/1 — navigation keys" do
    test "home" do
      {[event], ""} = Parser.parse("\e[H")
      assert %Key{key: :home, mod: [], type: :press} = event
    end

    test "end" do
      {[event], ""} = Parser.parse("\e[F")
      assert %Key{key: :end, mod: [], type: :press} = event
    end

    test "page up" do
      {[event], ""} = Parser.parse("\e[5~")
      assert %Key{key: :page_up, mod: [], type: :press} = event
    end

    test "page down" do
      {[event], ""} = Parser.parse("\e[6~")
      assert %Key{key: :page_down, mod: [], type: :press} = event
    end

    test "delete" do
      {[event], ""} = Parser.parse("\e[3~")
      assert %Key{key: :delete, mod: [], type: :press} = event
    end
  end

  describe "parse/1 — function keys (SS3)" do
    test "F1 (\\eOP)" do
      {[event], ""} = Parser.parse("\eOP")
      assert %Key{key: :f1, mod: [], type: :press} = event
    end

    test "F2 (\\eOQ)" do
      {[event], ""} = Parser.parse("\eOQ")
      assert %Key{key: :f2, mod: [], type: :press} = event
    end

    test "F3 (\\eOR)" do
      {[event], ""} = Parser.parse("\eOR")
      assert %Key{key: :f3, mod: [], type: :press} = event
    end

    test "F4 (\\eOS)" do
      {[event], ""} = Parser.parse("\eOS")
      assert %Key{key: :f4, mod: [], type: :press} = event
    end
  end

  describe "parse/1 — function keys (CSI)" do
    test "F5 (\\e[15~)" do
      {[event], ""} = Parser.parse("\e[15~")
      assert %Key{key: :f5, mod: [], type: :press} = event
    end

    test "F6 (\\e[17~)" do
      {[event], ""} = Parser.parse("\e[17~")
      assert %Key{key: :f6, mod: [], type: :press} = event
    end

    test "F7 (\\e[18~)" do
      {[event], ""} = Parser.parse("\e[18~")
      assert %Key{key: :f7, mod: [], type: :press} = event
    end

    test "F8 (\\e[19~)" do
      {[event], ""} = Parser.parse("\e[19~")
      assert %Key{key: :f8, mod: [], type: :press} = event
    end

    test "F9 (\\e[20~)" do
      {[event], ""} = Parser.parse("\e[20~")
      assert %Key{key: :f9, mod: [], type: :press} = event
    end

    test "F10 (\\e[21~)" do
      {[event], ""} = Parser.parse("\e[21~")
      assert %Key{key: :f10, mod: [], type: :press} = event
    end

    test "F11 (\\e[23~)" do
      {[event], ""} = Parser.parse("\e[23~")
      assert %Key{key: :f11, mod: [], type: :press} = event
    end

    test "F12 (\\e[24~)" do
      {[event], ""} = Parser.parse("\e[24~")
      assert %Key{key: :f12, mod: [], type: :press} = event
    end
  end

  describe "parse/1 — mouse (SGR encoding)" do
    test "left click at (10, 5)" do
      # Button 0 = left, coordinates are 1-indexed in SGR
      {[event], ""} = Parser.parse("\e[<0;11;6M")
      assert %Mouse{type: :click, button: :left, x: 10, y: 5, mod: []} = event
    end

    test "right click" do
      {[event], ""} = Parser.parse("\e[<2;1;1M")
      assert %Mouse{type: :click, button: :right, x: 0, y: 0, mod: []} = event
    end

    test "middle click" do
      {[event], ""} = Parser.parse("\e[<1;5;3M")
      assert %Mouse{type: :click, button: :middle, x: 4, y: 2, mod: []} = event
    end

    test "left release" do
      {[event], ""} = Parser.parse("\e[<0;11;6m")
      assert %Mouse{type: :release, button: :left, x: 10, y: 5, mod: []} = event
    end

    test "wheel up" do
      {[event], ""} = Parser.parse("\e[<64;5;10M")
      assert %Mouse{type: :wheel, button: :wheel_up, x: 4, y: 9, mod: []} = event
    end

    test "wheel down" do
      {[event], ""} = Parser.parse("\e[<65;5;10M")
      assert %Mouse{type: :wheel, button: :wheel_down, x: 4, y: 9, mod: []} = event
    end

    test "motion with left button held" do
      # 32 (motion bit) + 0 (left) = 32
      {[event], ""} = Parser.parse("\e[<32;5;10M")
      assert %Mouse{type: :motion, button: :left, x: 4, y: 9, mod: []} = event
    end
  end

  describe "parse/1 — bracketed paste" do
    test "paste with content" do
      input = "\e[200~hello world\e[201~"
      {[event], ""} = Parser.parse(input)
      assert %Paste{content: "hello world"} = event
    end

    test "paste with special characters" do
      input = "\e[200~line1\nline2\ttab\e[201~"
      {[event], ""} = Parser.parse(input)
      assert %Paste{content: "line1\nline2\ttab"} = event
    end

    test "incomplete paste returns remaining" do
      input = "\e[200~partial content"
      {[], remaining} = Parser.parse(input)
      assert remaining == "\e[200~partial content"
    end
  end

  describe "parse/1 — focus" do
    test "focus gained" do
      {[event], ""} = Parser.parse("\e[I")
      assert %Focus{focused: true} = event
    end

    test "focus lost" do
      {[event], ""} = Parser.parse("\e[O")
      assert %Focus{focused: false} = event
    end
  end

  describe "parse/1 — alt+key" do
    test "alt+a" do
      {[event], ""} = Parser.parse("\ea")
      assert %Key{key: "a", mod: [:alt], type: :press, text: "a"} = event
    end

    test "alt+z" do
      {[event], ""} = Parser.parse("\ez")
      assert %Key{key: "z", mod: [:alt], type: :press, text: "z"} = event
    end

    test "alt+A (uppercase)" do
      {[event], ""} = Parser.parse("\eA")
      assert %Key{key: "A", mod: [:alt], type: :press, text: "A"} = event
    end
  end

  describe "parse/1 — incomplete sequences" do
    test "lone ESC" do
      {[], "\e"} = Parser.parse("\e")
    end

    test "ESC [ without final byte" do
      {[], "\e["} = Parser.parse("\e[")
    end

    test "ESC [ with params but no final byte" do
      {[], "\e[1;2"} = Parser.parse("\e[1;2")
    end

    test "incomplete SS3" do
      {[], "\eO"} = Parser.parse("\eO")
    end

    test "incomplete SGR mouse" do
      {[], "\e[<0;5"} = Parser.parse("\e[<0;5")
    end
  end

  describe "parse/1 — multiple events" do
    test "multiple printable characters" do
      {events, ""} = Parser.parse("abc")
      assert length(events) == 3
      assert [%Key{key: "a"}, %Key{key: "b"}, %Key{key: "c"}] = events
    end

    test "mixed events" do
      # "a" then up arrow then "b"
      input = "a\e[Ab"
      {events, ""} = Parser.parse(input)
      assert [%Key{key: "a"}, %Key{key: :up}, %Key{key: "b"}] = events
    end

    test "events followed by incomplete sequence" do
      input = "a\e["
      {[event], remaining} = Parser.parse(input)
      assert %Key{key: "a"} = event
      assert remaining == "\e["
    end
  end

  describe "parse/1 — unknown sequences" do
    test "unknown CSI sequence does not crash" do
      # \e[999Z is not a recognized sequence
      {events, ""} = Parser.parse("\e[999Z")
      # Should skip gracefully — no crash, events is empty or contains nil-filtered results
      assert is_list(events)
    end

    test "unknown byte is skipped" do
      # NUL byte (0) is not handled — should skip it
      {events, ""} = Parser.parse(<<0, ?a>>)
      assert [%Key{key: "a"}] = events
    end
  end
end
