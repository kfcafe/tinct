defmodule Tinct.FocusGroupTest do
  use ExUnit.Case, async: true

  alias Tinct.Event
  alias Tinct.Event.Key
  alias Tinct.FocusGroup

  doctest Tinct.FocusGroup

  describe "new/1" do
    test "first pane gets initial focus" do
      fg = FocusGroup.new([:tasks, :detail, :logs])
      assert fg.active == :tasks
      assert fg.panes == [:tasks, :detail, :logs]
    end

    test "empty list creates group with no active pane" do
      fg = FocusGroup.new([])
      assert fg.active == nil
      assert fg.panes == []
    end

    test "single pane gets focus" do
      fg = FocusGroup.new([:only])
      assert fg.active == :only
    end
  end

  describe "next/1" do
    test "cycles forward through panes" do
      fg = FocusGroup.new([:a, :b, :c])
      assert fg.active == :a

      fg = FocusGroup.next(fg)
      assert fg.active == :b

      fg = FocusGroup.next(fg)
      assert fg.active == :c
    end

    test "wraps around at the end" do
      fg = FocusGroup.new([:a, :b, :c])
      fg = fg |> FocusGroup.next() |> FocusGroup.next() |> FocusGroup.next()
      assert fg.active == :a
    end

    test "no-op with single pane" do
      fg = FocusGroup.new([:only])
      assert FocusGroup.next(fg).active == :only
    end

    test "no-op with empty group" do
      fg = FocusGroup.new([])
      assert FocusGroup.next(fg).active == nil
    end
  end

  describe "prev/1" do
    test "cycles backward through panes" do
      fg = FocusGroup.new([:a, :b, :c])
      fg = FocusGroup.prev(fg)
      assert fg.active == :c

      fg = FocusGroup.prev(fg)
      assert fg.active == :b
    end

    test "wraps around at the beginning" do
      fg = FocusGroup.new([:a, :b, :c])
      fg = fg |> FocusGroup.prev() |> FocusGroup.prev() |> FocusGroup.prev()
      assert fg.active == :a
    end

    test "no-op with single pane" do
      fg = FocusGroup.new([:only])
      assert FocusGroup.prev(fg).active == :only
    end

    test "no-op with empty group" do
      fg = FocusGroup.new([])
      assert FocusGroup.prev(fg).active == nil
    end
  end

  describe "focus/2" do
    test "jumps to a specific pane" do
      fg = FocusGroup.new([:a, :b, :c])
      fg = FocusGroup.focus(fg, :c)
      assert fg.active == :c
    end

    test "ignores unknown pane" do
      fg = FocusGroup.new([:a, :b])
      fg = FocusGroup.focus(fg, :unknown)
      assert fg.active == :a
    end
  end

  describe "focused?/2" do
    test "returns true for the active pane" do
      fg = FocusGroup.new([:a, :b, :c])
      assert FocusGroup.focused?(fg, :a)
      refute FocusGroup.focused?(fg, :b)
      refute FocusGroup.focused?(fg, :c)
    end

    test "tracks focus changes" do
      fg = FocusGroup.new([:a, :b]) |> FocusGroup.next()
      refute FocusGroup.focused?(fg, :a)
      assert FocusGroup.focused?(fg, :b)
    end

    test "returns false for unknown pane" do
      fg = FocusGroup.new([:a, :b])
      refute FocusGroup.focused?(fg, :unknown)
    end
  end

  describe "active/1" do
    test "returns the active pane" do
      fg = FocusGroup.new([:a, :b])
      assert FocusGroup.active(fg) == :a
    end

    test "returns nil for empty group" do
      fg = FocusGroup.new([])
      assert FocusGroup.active(fg) == nil
    end
  end

  describe "handle_key/2" do
    test "Tab moves focus forward" do
      fg = FocusGroup.new([:a, :b, :c])
      tab = Event.key(:tab)

      assert {:consumed, fg} = FocusGroup.handle_key(fg, tab)
      assert fg.active == :b
    end

    test "Shift+Tab moves focus backward" do
      fg = FocusGroup.new([:a, :b, :c])
      shift_tab = Event.key(:tab, [:shift])

      assert {:consumed, fg} = FocusGroup.handle_key(fg, shift_tab)
      assert fg.active == :c
    end

    test "other keys pass through" do
      fg = FocusGroup.new([:a, :b])

      assert :passthrough == FocusGroup.handle_key(fg, Event.key("q"))
      assert :passthrough == FocusGroup.handle_key(fg, Event.key(:enter))
      assert :passthrough == FocusGroup.handle_key(fg, Event.key("c", [:ctrl]))
    end

    test "Tab with extra modifiers passes through" do
      fg = FocusGroup.new([:a, :b])
      ctrl_tab = Event.key(:tab, [:ctrl])

      assert :passthrough == FocusGroup.handle_key(fg, ctrl_tab)
    end

    test "only consumes key press, not release" do
      fg = FocusGroup.new([:a, :b])
      tab_release = %Key{key: :tab, mod: [], type: :release}

      assert :passthrough == FocusGroup.handle_key(fg, tab_release)
    end
  end

  describe "add_pane/2" do
    test "appends pane to the end" do
      fg = FocusGroup.new([:a, :b]) |> FocusGroup.add_pane(:c)
      assert fg.panes == [:a, :b, :c]
      assert fg.active == :a
    end

    test "first pane added to empty group gets focus" do
      fg = FocusGroup.new([]) |> FocusGroup.add_pane(:first)
      assert fg.panes == [:first]
      assert fg.active == :first
    end
  end

  describe "remove_pane/2" do
    test "removes a non-active pane" do
      fg = FocusGroup.new([:a, :b, :c]) |> FocusGroup.remove_pane(:b)
      assert fg.panes == [:a, :c]
      assert fg.active == :a
    end

    test "removing active pane moves focus to next" do
      fg = FocusGroup.new([:a, :b, :c])
      fg = FocusGroup.focus(fg, :b)
      fg = FocusGroup.remove_pane(fg, :b)
      assert fg.panes == [:a, :c]
      assert fg.active == :c
    end

    test "removing last active pane wraps focus to first" do
      fg = FocusGroup.new([:a, :b, :c])
      fg = FocusGroup.focus(fg, :c)
      fg = FocusGroup.remove_pane(fg, :c)
      assert fg.panes == [:a, :b]
      assert fg.active == :b
    end

    test "removing the only pane leaves no active" do
      fg = FocusGroup.new([:only]) |> FocusGroup.remove_pane(:only)
      assert fg.panes == []
      assert fg.active == nil
    end

    test "removing unknown pane is no-op" do
      fg = FocusGroup.new([:a, :b])
      fg2 = FocusGroup.remove_pane(fg, :unknown)
      assert fg2.panes == fg.panes
      assert fg2.active == fg.active
    end
  end

  describe "panes/1" do
    test "returns registered pane list" do
      fg = FocusGroup.new([:a, :b, :c])
      assert FocusGroup.panes(fg) == [:a, :b, :c]
    end
  end

  describe "works with many panes" do
    test "5 pane cycle" do
      panes = [:p1, :p2, :p3, :p4, :p5]
      fg = FocusGroup.new(panes)

      # Cycle through all 5 forward
      fg = Enum.reduce(1..5, fg, fn _, acc -> FocusGroup.next(acc) end)
      assert fg.active == :p1

      # Cycle through all 5 backward
      fg = Enum.reduce(1..5, fg, fn _, acc -> FocusGroup.prev(acc) end)
      assert fg.active == :p1
    end

    test "Tab cycles all 5 panes" do
      panes = [:p1, :p2, :p3, :p4, :p5]
      fg = FocusGroup.new(panes)
      tab = Event.key(:tab)

      actives =
        Enum.scan(1..5, fg, fn _, acc ->
          {:consumed, new_fg} = FocusGroup.handle_key(acc, tab)
          new_fg
        end)
        |> Enum.map(& &1.active)

      assert actives == [:p2, :p3, :p4, :p5, :p1]
    end
  end
end
