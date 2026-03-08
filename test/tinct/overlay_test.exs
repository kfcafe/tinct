defmodule Tinct.OverlayTest do
  use ExUnit.Case, async: true

  alias Tinct.Buffer
  alias Tinct.Element
  alias Tinct.Layout.Rect
  alias Tinct.Overlay
  alias Tinct.Test, as: T
  alias Tinct.View

  doctest Tinct.Overlay

  # ---------------------------------------------------------------------------
  # Overlay struct
  # ---------------------------------------------------------------------------

  describe "Overlay.new/2" do
    test "creates an overlay with defaults" do
      el = Element.text("hi")
      overlay = Overlay.new(el, width: 40, height: 10)

      assert overlay.content == el
      assert overlay.width == 40
      assert overlay.height == 10
      assert overlay.anchor == :center
      assert overlay.backdrop == :none
    end

    test "accepts anchor option" do
      overlay = Overlay.new(Element.text("hi"), width: 10, height: 5, anchor: {:absolute, 3, 7})

      assert overlay.anchor == {:absolute, 3, 7}
    end

    test "accepts backdrop option" do
      overlay = Overlay.new(Element.text("hi"), width: 10, height: 5, backdrop: :dim)

      assert overlay.backdrop == :dim
    end
  end

  # ---------------------------------------------------------------------------
  # Rect calculation
  # ---------------------------------------------------------------------------

  describe "calculate_rect/3" do
    test "centers overlay on screen" do
      overlay = Overlay.new(Element.text("x"), width: 20, height: 10)
      rect = Overlay.calculate_rect(overlay, 80, 24)

      assert rect == Rect.new(30, 7, 20, 10)
    end

    test "centers overlay with odd remainder" do
      overlay = Overlay.new(Element.text("x"), width: 21, height: 11)
      rect = Overlay.calculate_rect(overlay, 80, 24)

      # (80-21)/2 = 29, (24-11)/2 = 6
      assert rect == Rect.new(29, 6, 21, 11)
    end

    test "clamps overlay to screen width" do
      overlay = Overlay.new(Element.text("x"), width: 100, height: 10)
      rect = Overlay.calculate_rect(overlay, 80, 24)

      assert rect.width == 80
      assert rect.x == 0
    end

    test "clamps overlay to screen height" do
      overlay = Overlay.new(Element.text("x"), width: 20, height: 50)
      rect = Overlay.calculate_rect(overlay, 80, 24)

      assert rect.height == 24
      assert rect.y == 0
    end

    test "positions at absolute coordinates" do
      overlay = Overlay.new(Element.text("x"), width: 10, height: 5, anchor: {:absolute, 5, 3})
      rect = Overlay.calculate_rect(overlay, 80, 24)

      assert rect == Rect.new(5, 3, 10, 5)
    end

    test "clamps absolute position to keep overlay on screen" do
      overlay = Overlay.new(Element.text("x"), width: 10, height: 5, anchor: {:absolute, 75, 22})
      rect = Overlay.calculate_rect(overlay, 80, 24)

      assert rect.x == 70
      assert rect.y == 19
    end
  end

  # ---------------------------------------------------------------------------
  # Overlay rendering to buffer
  # ---------------------------------------------------------------------------

  describe "render_overlays/3" do
    test "renders overlay content onto buffer" do
      buf = Buffer.new(20, 5)
      el = Element.text("Hello")
      overlay = Overlay.new(el, width: 10, height: 1, anchor: {:absolute, 0, 0})

      result = Overlay.render_overlays(buf, [overlay])

      assert Buffer.get(result, 0, 0).char == "H"
      assert Buffer.get(result, 1, 0).char == "e"
      assert Buffer.get(result, 4, 0).char == "o"
    end

    test "renders overlay on top of existing content" do
      buf =
        Buffer.new(20, 3)
        |> Buffer.put_string(0, 0, "background text here")

      el = Element.text("TOP")
      overlay = Overlay.new(el, width: 10, height: 1, anchor: {:absolute, 0, 0})

      result = Overlay.render_overlays(buf, [overlay])

      # Overlay overwrites first 3 chars
      assert Buffer.get(result, 0, 0).char == "T"
      assert Buffer.get(result, 1, 0).char == "O"
      assert Buffer.get(result, 2, 0).char == "P"
      # Rest of background is preserved (column 11 = 't' in "background text here")
      assert Buffer.get(result, 11, 0).char == "t"
    end

    test "returns buffer unchanged for empty overlay list" do
      buf = Buffer.new(10, 5) |> Buffer.put_string(0, 0, "intact")
      result = Overlay.render_overlays(buf, [])

      assert Buffer.get(result, 0, 0).char == "i"
    end

    test "applies backdrop dimming" do
      buf =
        Buffer.new(20, 3)
        |> Buffer.put_string(0, 0, "background")

      el = Element.text("X")
      overlay = Overlay.new(el, width: 5, height: 1, anchor: {:absolute, 0, 0}, backdrop: :dim)

      result = Overlay.render_overlays(buf, [overlay])

      # Cells outside the overlay rect should be dimmed
      assert Buffer.get(result, 10, 1).dim == true
      assert Buffer.get(result, 5, 0).dim == true

      # Overlay content itself should NOT be dimmed (overlay paints fresh cells)
      assert Buffer.get(result, 0, 0).char == "X"
      assert Buffer.get(result, 0, 0).dim == false
    end

    test "no dimming when backdrop is :none" do
      buf =
        Buffer.new(20, 3)
        |> Buffer.put_string(0, 0, "background")

      el = Element.text("X")
      overlay = Overlay.new(el, width: 5, height: 1, anchor: {:absolute, 0, 0}, backdrop: :none)

      result = Overlay.render_overlays(buf, [overlay])

      # Background cells should NOT be dimmed
      assert Buffer.get(result, 10, 0).dim == false
    end

    test "multiple overlays stack — last one on top" do
      buf = Buffer.new(20, 5)

      first = Overlay.new(Element.text("AAA"), width: 10, height: 1, anchor: {:absolute, 0, 0})
      second = Overlay.new(Element.text("BB"), width: 10, height: 1, anchor: {:absolute, 0, 0})

      result = Overlay.render_overlays(buf, [first, second])

      # Second overlay overwrites first at (0,0) and (1,0)
      assert Buffer.get(result, 0, 0).char == "B"
      assert Buffer.get(result, 1, 0).char == "B"
      # First overlay's third char is NOT overwritten (second overlay wrote space there)
      # Actually, the second overlay renders "BB" + spaces, so let's check column 2
      # The second overlay has width 10, so "BB" followed by spaces
      assert Buffer.get(result, 2, 0).char == " "
    end

    test "multiple overlays with mixed backdrops" do
      buf =
        Buffer.new(20, 5)
        |> Buffer.put_string(0, 0, "background")

      # First overlay has no backdrop
      first =
        Overlay.new(Element.text("A"), width: 5, height: 1, anchor: {:absolute, 0, 2})

      # Second overlay dims everything (including first overlay's area if not covered)
      second =
        Overlay.new(Element.text("B"),
          width: 5,
          height: 1,
          anchor: {:absolute, 0, 3},
          backdrop: :dim
        )

      result = Overlay.render_overlays(buf, [first, second])

      # First overlay content gets dimmed by second overlay's backdrop
      assert Buffer.get(result, 0, 2).dim == true
      # Background gets dimmed
      assert Buffer.get(result, 0, 0).dim == true
      # Second overlay itself is NOT dimmed
      assert Buffer.get(result, 0, 3).char == "B"
      assert Buffer.get(result, 0, 3).dim == false
    end
  end

  # ---------------------------------------------------------------------------
  # View integration
  # ---------------------------------------------------------------------------

  describe "View with overlays" do
    test "View.new/1 defaults to empty overlays" do
      view = View.new(Element.text("hi"))

      assert view.overlays == []
    end

    test "View.new/2 accepts overlays option" do
      overlay = Overlay.new(Element.text("modal"), width: 20, height: 5)
      view = View.new(Element.text("main"), overlays: [overlay])

      assert length(view.overlays) == 1
      assert hd(view.overlays) == overlay
    end

    test "View.with_modal/3 creates a centered dimmed overlay" do
      main = Element.text("background")
      modal = Element.text("dialog")
      view = View.with_modal(main, modal, width: 40, height: 10)

      assert view.content == main
      assert length(view.overlays) == 1

      overlay = hd(view.overlays)
      assert overlay.content == modal
      assert overlay.width == 40
      assert overlay.height == 10
      assert overlay.anchor == :center
      assert overlay.backdrop == :dim
    end
  end

  # ---------------------------------------------------------------------------
  # Headless rendering via Tinct.Test
  # ---------------------------------------------------------------------------

  describe "headless rendering" do
    test "overlay renders on top of main content via render_view" do
      main = Element.text("background content")
      modal = Element.text("MODAL")
      overlay = Overlay.new(modal, width: 10, height: 1, anchor: {:absolute, 0, 0})
      view = View.new(main, overlays: [overlay])

      text = T.render_view(view, {80, 3})

      assert text =~ "MODAL"
    end

    test "center-anchored overlay is positioned correctly" do
      main = Element.text("")
      modal = Element.text("X")
      overlay = Overlay.new(modal, width: 1, height: 1)
      view = View.new(main, overlays: [overlay])

      # In 80x24, center of width=1 is col 39, center of height=1 is row 11
      buf =
        view
        |> render_to_buffer({80, 24})

      assert Buffer.get(buf, 39, 11).char == "X"
    end

    test "backdrop dimming visible in buffer" do
      main = Element.text("BG")
      modal = Element.text("FG")

      overlay =
        Overlay.new(modal, width: 10, height: 1, anchor: {:absolute, 5, 0}, backdrop: :dim)

      view = View.new(main, overlays: [overlay])

      buf = render_to_buffer(view, {20, 3})

      # Background cells are dimmed
      assert Buffer.get(buf, 0, 0).char == "B"
      assert Buffer.get(buf, 0, 0).dim == true
      assert Buffer.get(buf, 1, 0).char == "G"
      assert Buffer.get(buf, 1, 0).dim == true

      # Overlay content is NOT dimmed
      assert Buffer.get(buf, 5, 0).char == "F"
      assert Buffer.get(buf, 5, 0).dim == false
      assert Buffer.get(buf, 6, 0).char == "G"
      assert Buffer.get(buf, 6, 0).dim == false
    end

    test "view without overlays works exactly as before" do
      view = View.new(Element.text("plain"))
      text = T.render_view(view, {80, 3})

      assert text =~ "plain"
    end
  end

  # ---------------------------------------------------------------------------
  # Component integration
  # ---------------------------------------------------------------------------

  defmodule ModalComponent do
    @moduledoc false
    @behaviour Tinct.Component

    @impl Tinct.Component
    def init(_opts), do: %{show_modal: false}

    @impl Tinct.Component
    def update(model, {:toggle_modal}) do
      %{model | show_modal: !model.show_modal}
    end

    def update(model, _msg), do: model

    @impl Tinct.Component
    def view(%{show_modal: false}) do
      View.new(Element.text("Press M for modal"))
    end

    def view(%{show_modal: true}) do
      main = Element.text("Press M for modal")
      modal = Element.text("Modal Open!")

      overlay =
        Overlay.new(modal,
          width: 20,
          height: 3,
          anchor: :center,
          backdrop: :dim
        )

      View.new(main, overlays: [overlay])
    end
  end

  describe "component with overlay" do
    test "renders without overlay initially" do
      state = T.render(ModalComponent, [])

      assert T.contains?(state, "Press M for modal")
      refute T.contains?(state, "Modal Open!")
    end

    test "renders overlay after toggle" do
      state =
        T.render(ModalComponent, [])
        |> T.send_event({:toggle_modal})

      assert T.contains?(state, "Modal Open!")
    end

    test "overlay backdrop dims background" do
      state =
        T.render(ModalComponent, [])
        |> T.send_event({:toggle_modal})

      buf = T.to_buffer(state)

      # Background cell at (0,0) should be dimmed
      assert Buffer.get(buf, 0, 0).dim == true
    end

    test "overlay content is not dimmed" do
      state =
        T.render(ModalComponent, [], size: {80, 24})
        |> T.send_event({:toggle_modal})

      buf = T.to_buffer(state)

      # Overlay is centered: x=(80-20)/2=30, y=(24-3)/2=10
      # "Modal Open!" starts at col 30, row 10
      assert Buffer.get(buf, 30, 10).char == "M"
      assert Buffer.get(buf, 30, 10).dim == false
    end
  end

  # ---------------------------------------------------------------------------
  # Helper
  # ---------------------------------------------------------------------------

  defp render_to_buffer(%View{} = view, {cols, rows}) do
    alias Tinct.{Layout, Theme}

    buffer =
      case view.content do
        nil -> Buffer.new(cols, rows)
        content -> Layout.render(content, {cols, rows}, Theme.default())
      end

    Overlay.render_overlays(buffer, view.overlays, Theme.default())
  end
end
