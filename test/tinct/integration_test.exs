defmodule Tinct.IntegrationTest.StyledComponent do
  @moduledoc false
  use Tinct.Component

  @impl Tinct.Component
  def init(_opts), do: %{}

  @impl Tinct.Component
  def update(model, _msg), do: model

  @impl Tinct.Component
  def view(_model) do
    Tinct.View.new(
      Tinct.Element.column([], [
        Tinct.Element.text("green bold", fg: :green, bold: true),
        Tinct.Element.text("plain text")
      ])
    )
  end
end

defmodule Tinct.IntegrationTest do
  @moduledoc """
  Integration tests for the full render pipeline:
  element tree → layout → buffer → cells with correct styles,
  and buffer → ANSI escape sequences.
  """

  use ExUnit.Case, async: true

  alias Tinct.{Buffer, Element, Layout, Style}
  alias Tinct.Buffer.Diff

  # -------------------------------------------------------------------
  # Style flows through the render pipeline (element → layout → buffer)
  # -------------------------------------------------------------------

  describe "text style flows through render pipeline" do
    test "fg color on text element appears on buffer cells" do
      el = Element.text("hi", fg: :red)
      buf = Layout.render(el, {10, 1})

      assert Buffer.get(buf, 0, 0).char == "h"
      assert Buffer.get(buf, 0, 0).fg == :red
      assert Buffer.get(buf, 1, 0).char == "i"
      assert Buffer.get(buf, 1, 0).fg == :red
    end

    test "bg color on text element appears on buffer cells" do
      el = Element.text("ab", bg: :blue)
      buf = Layout.render(el, {10, 1})

      assert Buffer.get(buf, 0, 0).bg == :blue
      assert Buffer.get(buf, 1, 0).bg == :blue
    end

    test "bold on text element appears on buffer cells" do
      el = Element.text("ok", bold: true)
      buf = Layout.render(el, {10, 1})

      cell = Buffer.get(buf, 0, 0)
      assert cell.bold == true
      assert cell.char == "o"
    end

    test "multiple styles on text element flow through together" do
      el = Element.text("x", fg: :green, bg: :yellow, bold: true, italic: true)
      buf = Layout.render(el, {5, 1})

      cell = Buffer.get(buf, 0, 0)
      assert cell.char == "x"
      assert cell.fg == :green
      assert cell.bg == :yellow
      assert cell.bold == true
      assert cell.italic == true
    end

    test "unstyled text resolves to defaults in buffer" do
      el = Element.text("hi")
      buf = Layout.render(el, {10, 1})

      cell = Buffer.get(buf, 0, 0)
      assert cell.fg == :default
      assert cell.bg == :default
      assert cell.bold == false
      assert cell.italic == false
    end
  end

  # -------------------------------------------------------------------
  # Style inheritance via Style.merge (the pattern widgets use)
  # -------------------------------------------------------------------

  describe "style inheritance via Style.merge in layout" do
    test "child inherits parent fg and bold through merge" do
      parent_style = Style.new(fg: :red, bold: true)
      child_style = Style.merge(parent_style, Style.new())

      tree =
        Element.column([], [
          %Element{type: :text, style: child_style, children: [], attrs: %{content: "hello"}}
        ])

      buf = Layout.render(tree, {20, 5})

      cell = Buffer.get(buf, 0, 0)
      assert cell.fg == :red
      assert cell.bold == true
    end

    test "child overrides parent fg while inheriting other attributes" do
      parent_style = Style.new(fg: :red, bold: true)
      child_style = Style.merge(parent_style, Style.new(fg: :blue))

      tree =
        Element.column([], [
          %Element{type: :text, style: child_style, children: [], attrs: %{content: "hello"}}
        ])

      buf = Layout.render(tree, {20, 5})

      cell = Buffer.get(buf, 0, 0)
      assert cell.fg == :blue
      assert cell.bold == true
    end

    test "nested inheritance: grandparent → parent → child" do
      grandparent = Style.new(fg: :red, bold: true, bg: :white)
      parent = Style.merge(grandparent, Style.new(fg: :green))
      child = Style.merge(parent, Style.new(italic: true))

      tree =
        Element.column([], [
          Element.column([], [
            %Element{type: :text, style: child, children: [], attrs: %{content: "deep"}}
          ])
        ])

      buf = Layout.render(tree, {20, 5})

      cell = Buffer.get(buf, 0, 0)
      assert cell.fg == :green
      assert cell.bold == true
      assert cell.bg == :white
      assert cell.italic == true
    end

    test "mixed: some children inherit, some override" do
      parent_style = Style.new(fg: :red, bg: :black)
      inheriting = Style.merge(parent_style, Style.new())
      overriding = Style.merge(parent_style, Style.new(fg: :blue))

      tree =
        Element.column([], [
          %Element{type: :text, style: inheriting, children: [], attrs: %{content: "inherit"}},
          %Element{type: :text, style: overriding, children: [], attrs: %{content: "override"}}
        ])

      buf = Layout.render(tree, {20, 5})

      # First child inherits red fg and black bg
      assert Buffer.get(buf, 0, 0).fg == :red
      assert Buffer.get(buf, 0, 0).bg == :black

      # Second child overrides fg to blue but keeps black bg
      assert Buffer.get(buf, 0, 1).fg == :blue
      assert Buffer.get(buf, 0, 1).bg == :black
    end
  end

  # -------------------------------------------------------------------
  # ANSI output end-to-end (buffer → Diff.full_render → escape sequences)
  # -------------------------------------------------------------------

  describe "color encoding in ANSI output" do
    test "RGB color produces truecolor escape sequence" do
      el = Element.text("hi", fg: {:rgb, 255, 0, 0})
      buf = Layout.render(el, {10, 1})

      output = buf |> Diff.full_render() |> IO.iodata_to_binary()

      assert output =~ "38;2;255;0;0"
    end

    test "named color produces standard ANSI escape sequence" do
      el = Element.text("hi", fg: :red)
      buf = Layout.render(el, {10, 1})

      output = buf |> Diff.full_render() |> IO.iodata_to_binary()

      # Named red fg uses SGR code 31
      assert output =~ "\e[" <> "31m"
    end

    test "default color produces no color escape — only reset" do
      el = Element.text("hi")
      buf = Layout.render(el, {10, 1})

      output = buf |> Diff.full_render() |> IO.iodata_to_binary()

      # No truecolor or indexed color sequences
      refute output =~ "38;2;"
      refute output =~ "38;5;"
      # Reset is present (default style emits reset)
      assert output =~ "\e[0m"
    end
  end

  # -------------------------------------------------------------------
  # Styled layout round-trip (column/row with styles → buffer → ANSI)
  # -------------------------------------------------------------------

  describe "styled layout round-trip" do
    test "styled text in column has correct position and style" do
      tree =
        Element.column([], [
          Element.text("hello", fg: :green, bold: true),
          Element.text("world", fg: :cyan)
        ])

      buf = Layout.render(tree, {20, 5})

      # Row 0: "hello" in green, bold
      cell = Buffer.get(buf, 0, 0)
      assert cell.char == "h"
      assert cell.fg == :green
      assert cell.bold == true

      # Row 1: "world" in cyan, not bold
      cell = Buffer.get(buf, 0, 1)
      assert cell.char == "w"
      assert cell.fg == :cyan
      assert cell.bold == false
    end

    test "ANSI output from styled column contains both color sequences" do
      tree =
        Element.column([], [
          Element.text("a", fg: :red),
          Element.text("b", fg: :blue)
        ])

      buf = Layout.render(tree, {10, 5})

      output = buf |> Diff.full_render() |> IO.iodata_to_binary()

      # Red fg (SGR 31), Blue fg (SGR 34)
      assert output =~ "31"
      assert output =~ "34"
    end
  end

  # -------------------------------------------------------------------
  # Tinct.Test.render round-trip with a real component
  # -------------------------------------------------------------------

  describe "Tinct.Test.render pipeline with styled component" do
    test "cell_at returns cells with correct style attributes" do
      state = Tinct.Test.render(Tinct.IntegrationTest.StyledComponent, [])

      # First row: "green bold" with fg: :green, bold: true
      cell = Tinct.Test.cell_at(state, 0, 0)
      assert cell.char == "g"
      assert cell.fg == :green
      assert cell.bold == true

      # Second row: "plain text" with defaults
      cell = Tinct.Test.cell_at(state, 0, 1)
      assert cell.char == "p"
      assert cell.fg == :default
      assert cell.bold == false
    end

    test "contains? finds styled text in rendered output" do
      state = Tinct.Test.render(Tinct.IntegrationTest.StyledComponent, [])

      assert Tinct.Test.contains?(state, "green bold")
      assert Tinct.Test.contains?(state, "plain text")
    end
  end
end
