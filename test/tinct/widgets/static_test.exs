defmodule Tinct.Widgets.StaticTest do
  use ExUnit.Case, async: true

  alias Tinct.{Element, View}
  alias Tinct.Test, as: T
  alias Tinct.Widgets.Static

  doctest Tinct.Widgets.Static

  # --- Component: init ---

  describe "init/1" do
    test "initializes with empty items by default" do
      model = Static.init([])
      assert model.items == []
      assert model.rendered_count == 0
      assert is_function(model.render_fn, 2)
    end

    test "accepts a custom render_fn" do
      render_fn = fn item, _idx -> Element.text("custom: #{item}") end
      model = Static.init(render_fn: render_fn)
      assert model.render_fn == render_fn
    end

    test "accepts initial items" do
      model = Static.init(items: ["a", "b"])
      assert model.items == ["a", "b"]
    end

    test "rendered_count starts at zero even with initial items" do
      model = Static.init(items: ["a", "b", "c"])
      assert model.rendered_count == 0
    end
  end

  # --- Component: view ---

  describe "view/1" do
    test "empty items renders nothing" do
      state = T.render(Static, render_fn: fn item, _idx -> Element.text(item) end)
      assert T.line(state, 0) == ""
    end

    test "items appear in rendered output" do
      state =
        T.render(Static,
          items: ["hello", "world"],
          render_fn: fn item, _idx -> Element.text(item) end
        )

      assert T.contains?(state, "hello")
      assert T.contains?(state, "world")
    end

    test "items maintain order" do
      state =
        T.render(Static,
          items: ["first", "second", "third"],
          render_fn: fn item, _idx -> Element.text(item) end
        )

      assert T.line(state, 0) == "first"
      assert T.line(state, 1) == "second"
      assert T.line(state, 2) == "third"
    end

    test "render_fn is called with correct item and index" do
      render_fn = fn item, idx ->
        Element.text("#{idx}:#{item}")
      end

      state = T.render(Static, items: ["a", "b", "c"], render_fn: render_fn)

      assert T.line(state, 0) == "0:a"
      assert T.line(state, 1) == "1:b"
      assert T.line(state, 2) == "2:c"
    end

    test "view returns a View struct" do
      model = Static.init(render_fn: fn item, _idx -> Element.text(item) end)
      assert %View{} = Static.view(model)
    end

    test "single item renders without wrapping column" do
      model =
        Static.init(
          items: ["only"],
          render_fn: fn item, _idx -> Element.text(item) end
        )

      view = Static.view(model)
      assert view.content.type == :text
      assert view.content.attrs.content == "only"
    end
  end

  # --- Component: update ---

  describe "update/2" do
    test "handles {:add_item, item}" do
      model = Static.init(render_fn: fn item, _idx -> Element.text(item) end)
      model = Static.update(model, {:add_item, "hello"})
      assert model.items == ["hello"]
    end

    test "handles {:add_items, items}" do
      model = Static.init(render_fn: fn item, _idx -> Element.text(item) end)
      model = Static.update(model, {:add_items, ["a", "b"]})
      assert model.items == ["a", "b"]
    end

    test "ignores unknown messages" do
      model = Static.init(render_fn: fn item, _idx -> Element.text(item) end)
      assert Static.update(model, :unknown) == model
    end
  end

  # --- Public API: add_item ---

  describe "add_item/2" do
    test "appends a single item" do
      model = Static.init([])
      model = Static.add_item(model, "hello")
      assert model.items == ["hello"]
    end

    test "appends to existing items" do
      model = Static.init(items: ["a"])
      model = Static.add_item(model, "b")
      assert model.items == ["a", "b"]
    end

    test "preserves insertion order" do
      model =
        Static.init([])
        |> Static.add_item("first")
        |> Static.add_item("second")
        |> Static.add_item("third")

      assert model.items == ["first", "second", "third"]
    end
  end

  # --- Public API: add_items ---

  describe "add_items/2" do
    test "appends multiple items at once" do
      model = Static.init([])
      model = Static.add_items(model, ["a", "b", "c"])
      assert model.items == ["a", "b", "c"]
    end

    test "appends to existing items" do
      model = Static.init(items: ["x"])
      model = Static.add_items(model, ["y", "z"])
      assert model.items == ["x", "y", "z"]
    end

    test "empty list is a no-op" do
      model = Static.init(items: ["a"])
      model = Static.add_items(model, [])
      assert model.items == ["a"]
    end
  end

  # --- Public API: new_items ---

  describe "new_items/1" do
    test "all items are new initially" do
      model = Static.init(items: ["a", "b"])
      assert Static.new_items(model) == ["a", "b"]
    end

    test "returns empty list when no items" do
      model = Static.init([])
      assert Static.new_items(model) == []
    end

    test "returns only unrendered items after mark_rendered" do
      model =
        Static.init([])
        |> Static.add_items(["a", "b"])
        |> Static.mark_rendered()
        |> Static.add_items(["c", "d"])

      assert Static.new_items(model) == ["c", "d"]
    end
  end

  # --- Public API: mark_rendered ---

  describe "mark_rendered/1" do
    test "advances rendered_count to current item count" do
      model = Static.init(items: ["a", "b", "c"])
      assert model.rendered_count == 0

      model = Static.mark_rendered(model)
      assert model.rendered_count == 3
    end

    test "after mark_rendered, new_items returns empty" do
      model = Static.init(items: ["a", "b"])
      model = Static.mark_rendered(model)
      assert Static.new_items(model) == []
    end

    test "incremental: mark, add, check new, mark again" do
      model = Static.init([])

      # Add first batch
      model = Static.add_items(model, ["a", "b"])
      assert Static.new_items(model) == ["a", "b"]

      # Mark rendered
      model = Static.mark_rendered(model)
      assert Static.new_items(model) == []

      # Add second batch
      model = Static.add_items(model, ["c", "d"])
      assert Static.new_items(model) == ["c", "d"]
      assert model.rendered_count == 2

      # Mark rendered again
      model = Static.mark_rendered(model)
      assert Static.new_items(model) == []
      assert model.rendered_count == 4
    end
  end

  # --- Integration via send_event ---

  describe "integration with Tinct.Test" do
    test "adding items via events shows them in output" do
      state = T.render(Static, render_fn: fn item, _idx -> Element.text(item) end)
      refute T.contains?(state, "hello")

      state = T.send_event(state, {:add_item, "hello"})
      assert T.contains?(state, "hello")
    end

    test "adding multiple items via event" do
      state = T.render(Static, render_fn: fn item, _idx -> Element.text(item) end)
      state = T.send_event(state, {:add_items, ["one", "two", "three"]})

      assert T.contains?(state, "one")
      assert T.contains?(state, "two")
      assert T.contains?(state, "three")
    end

    test "default render_fn handles strings" do
      state = T.render(Static, items: ["hello"])
      assert T.contains?(state, "hello")
    end

    test "default render_fn handles non-strings" do
      state = T.render(Static, items: [42])
      assert T.contains?(state, "42")
    end
  end
end
