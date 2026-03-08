defmodule Tinct.EventTest do
  use ExUnit.Case, async: true

  alias Tinct.Event
  alias Tinct.Event.{Focus, Key, Mouse, Paste, Resize}

  doctest Tinct.Event
  doctest Tinct.Event.Key
  doctest Tinct.Event.Mouse
  doctest Tinct.Event.Paste
  doctest Tinct.Event.Resize
  doctest Tinct.Event.Focus

  describe "Key struct defaults" do
    test "has expected defaults" do
      key = %Key{}
      assert key.key == nil
      assert key.mod == []
      assert key.type == :press
      assert key.text == nil
      assert key.is_repeat == false
    end

    test "accepts all fields" do
      key = %Key{key: "a", mod: [:ctrl, :shift], type: :release, text: "a", is_repeat: true}
      assert key.key == "a"
      assert key.mod == [:ctrl, :shift]
      assert key.type == :release
      assert key.text == "a"
      assert key.is_repeat == true
    end
  end

  describe "Mouse struct defaults" do
    test "has expected defaults" do
      mouse = %Mouse{}
      assert mouse.type == :click
      assert mouse.button == :left
      assert mouse.x == 0
      assert mouse.y == 0
      assert mouse.mod == []
    end

    test "accepts all fields" do
      mouse = %Mouse{type: :wheel, button: :wheel_up, x: 42, y: 10, mod: [:ctrl]}
      assert mouse.type == :wheel
      assert mouse.button == :wheel_up
      assert mouse.x == 42
      assert mouse.y == 10
      assert mouse.mod == [:ctrl]
    end
  end

  describe "Paste struct defaults" do
    test "has expected defaults" do
      paste = %Paste{}
      assert paste.content == ""
    end

    test "accepts content" do
      paste = %Paste{content: "hello world"}
      assert paste.content == "hello world"
    end
  end

  describe "Resize struct defaults" do
    test "has expected defaults" do
      resize = %Resize{}
      assert resize.width == 0
      assert resize.height == 0
    end

    test "accepts dimensions" do
      resize = %Resize{width: 120, height: 40}
      assert resize.width == 120
      assert resize.height == 40
    end
  end

  describe "Focus struct defaults" do
    test "has expected defaults" do
      focus = %Focus{}
      assert focus.focused == true
    end

    test "accepts focused value" do
      focus = %Focus{focused: false}
      assert focus.focused == false
    end
  end

  describe "Event.key/1" do
    test "creates key press for string key" do
      event = Event.key("q")
      assert %Key{} = event
      assert event.key == "q"
      assert event.mod == []
      assert event.type == :press
      assert event.text == "q"
      assert event.is_repeat == false
    end

    test "sets text for printable characters" do
      assert Event.key("A").text == "A"
      assert Event.key(" ").text == " "
      assert Event.key("1").text == "1"
      assert Event.key("!").text == "!"
    end

    test "creates key press for atom key" do
      event = Event.key(:enter)
      assert %Key{} = event
      assert event.key == :enter
      assert event.mod == []
      assert event.type == :press
      assert event.text == nil
      assert event.is_repeat == false
    end

    test "works with all special keys" do
      special_keys = [
        :enter,
        :escape,
        :tab,
        :backspace,
        :delete,
        :up,
        :down,
        :left,
        :right,
        :home,
        :end,
        :page_up,
        :page_down,
        :f1,
        :f12
      ]

      for key <- special_keys do
        event = Event.key(key)
        assert event.key == key
        assert event.text == nil
      end
    end
  end

  describe "Event.key/2" do
    test "creates key press with modifiers for string key" do
      event = Event.key("c", [:ctrl])
      assert event.key == "c"
      assert event.mod == [:ctrl]
      assert event.type == :press
      assert event.text == "c"
    end

    test "creates key press with modifiers for atom key" do
      event = Event.key(:left, [:shift, :alt])
      assert event.key == :left
      assert event.mod == [:shift, :alt]
      assert event.type == :press
      assert event.text == nil
    end

    test "supports multiple modifiers" do
      event = Event.key("a", [:ctrl, :alt, :shift])
      assert event.mod == [:ctrl, :alt, :shift]
    end

    test "empty modifier list is equivalent to key/1" do
      assert Event.key("q", []) == Event.key("q")
      assert Event.key(:enter, []) == Event.key(:enter)
    end
  end

  describe "Event.ctrl_c/0" do
    test "produces correct struct" do
      event = Event.ctrl_c()
      assert %Key{} = event
      assert event.key == "c"
      assert event.mod == [:ctrl]
      assert event.type == :press
      assert event.text == "c"
      assert event.is_repeat == false
    end

    test "equals key(\"c\", [:ctrl])" do
      assert Event.ctrl_c() == Event.key("c", [:ctrl])
    end
  end

  describe "Event.key_press?/1" do
    test "returns true for key press events" do
      assert Event.key_press?(Event.key("a"))
      assert Event.key_press?(Event.key(:enter))
      assert Event.key_press?(Event.key("c", [:ctrl]))
    end

    test "returns false for key release events" do
      refute Event.key_press?(%Key{key: "a", type: :release})
    end

    test "returns false for key repeat events" do
      refute Event.key_press?(%Key{key: "a", type: :repeat})
    end

    test "returns false for non-key events" do
      refute Event.key_press?(%Mouse{})
      refute Event.key_press?(%Paste{content: "hi"})
      refute Event.key_press?(%Resize{width: 80, height: 24})
      refute Event.key_press?(%Focus{focused: true})
    end

    test "returns false for non-event values" do
      refute Event.key_press?(nil)
      refute Event.key_press?("a")
      refute Event.key_press?(42)
      refute Event.key_press?(%{})
    end
  end

  describe "Event.key_release?/1" do
    test "returns true for key release events" do
      assert Event.key_release?(%Key{key: "a", type: :release})
      assert Event.key_release?(%Key{key: :escape, type: :release})
    end

    test "returns false for key press events" do
      refute Event.key_release?(Event.key("a"))
    end

    test "returns false for key repeat events" do
      refute Event.key_release?(%Key{key: "a", type: :repeat})
    end

    test "returns false for non-key events" do
      refute Event.key_release?(%Mouse{})
      refute Event.key_release?(%Paste{})
      refute Event.key_release?(%Resize{})
      refute Event.key_release?(%Focus{})
    end

    test "returns false for non-event values" do
      refute Event.key_release?(nil)
      refute Event.key_release?("a")
    end
  end

  describe "Event.printable?/1" do
    test "returns true for letter keys" do
      assert Event.printable?(Event.key("a"))
      assert Event.printable?(Event.key("Z"))
    end

    test "returns true for number keys" do
      assert Event.printable?(Event.key("0"))
      assert Event.printable?(Event.key("9"))
    end

    test "returns true for symbol keys" do
      assert Event.printable?(Event.key("!"))
      assert Event.printable?(Event.key("@"))
      assert Event.printable?(Event.key("-"))
    end

    test "returns true for space" do
      assert Event.printable?(Event.key(" "))
    end

    test "returns false for special atom keys" do
      refute Event.printable?(Event.key(:enter))
      refute Event.printable?(Event.key(:escape))
      refute Event.printable?(Event.key(:tab))
      refute Event.printable?(Event.key(:backspace))
      refute Event.printable?(Event.key(:delete))
      refute Event.printable?(Event.key(:up))
      refute Event.printable?(Event.key(:down))
      refute Event.printable?(Event.key(:left))
      refute Event.printable?(Event.key(:right))
      refute Event.printable?(Event.key(:home))
      refute Event.printable?(Event.key(:end))
      refute Event.printable?(Event.key(:page_up))
      refute Event.printable?(Event.key(:page_down))
      refute Event.printable?(Event.key(:f1))
      refute Event.printable?(Event.key(:f12))
    end

    test "returns false for non-key events" do
      refute Event.printable?(%Mouse{})
      refute Event.printable?(%Paste{})
      refute Event.printable?(%Resize{})
      refute Event.printable?(%Focus{})
    end

    test "returns false for non-event values" do
      refute Event.printable?(nil)
      refute Event.printable?("a")
    end
  end

  describe "pattern matching on event types" do
    test "can match key events" do
      event = Event.key("q")
      assert %Key{key: "q"} = event
    end

    test "can match mouse events" do
      event = %Mouse{type: :click, button: :left, x: 5, y: 10}
      assert %Mouse{type: :click, x: 5, y: 10} = event
    end

    test "can match paste events" do
      event = %Paste{content: "pasted text"}
      assert %Paste{content: "pasted text"} = event
    end

    test "can match resize events" do
      event = %Resize{width: 80, height: 24}
      assert %Resize{width: 80, height: 24} = event
    end

    test "can match focus events" do
      event = %Focus{focused: false}
      assert %Focus{focused: false} = event
    end

    test "can use case to dispatch on event type" do
      events = [
        Event.key("a"),
        %Mouse{type: :click},
        %Paste{content: "hi"},
        %Resize{width: 80, height: 24},
        %Focus{focused: true}
      ]

      labels =
        Enum.map(events, fn
          %Key{} -> :key
          %Mouse{} -> :mouse
          %Paste{} -> :paste
          %Resize{} -> :resize
          %Focus{} -> :focus
        end)

      assert labels == [:key, :mouse, :paste, :resize, :focus]
    end
  end
end
