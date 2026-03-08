defmodule Tinct.ThemeTest do
  use ExUnit.Case, async: true

  alias Tinct.Style
  alias Tinct.Theme

  describe "new/2" do
    test "creates a theme with the given name and styles" do
      styles = %{error: Style.new(fg: :red)}
      theme = Theme.new(:my_app, styles)

      assert theme.name == :my_app
      assert theme.styles == styles
    end

    test "creates a theme with an empty style map" do
      theme = Theme.new(:empty, %{})

      assert theme.name == :empty
      assert theme.styles == %{}
    end
  end

  describe "get/2" do
    test "returns the correct style for a known name" do
      error_style = Style.new(fg: :red, bold: true)
      theme = Theme.new(:app, %{error: error_style})

      assert Theme.get(theme, :error) == error_style
    end

    test "returns nil for a missing name" do
      theme = Theme.new(:app, %{error: Style.new(fg: :red)})

      assert Theme.get(theme, :missing) == nil
    end
  end

  describe "get/3" do
    test "returns the style when the name exists" do
      error_style = Style.new(fg: :red)
      fallback = Style.new(fg: :yellow)
      theme = Theme.new(:app, %{error: error_style})

      assert Theme.get(theme, :error, fallback) == error_style
    end

    test "returns the default for a missing name" do
      fallback = Style.new(fg: :yellow)
      theme = Theme.new(:app, %{})

      assert Theme.get(theme, :missing, fallback) == fallback
    end
  end

  describe "put/3" do
    test "adds a new style to the theme" do
      theme = Theme.new(:app, %{})
      info_style = Style.new(fg: :cyan)

      updated = Theme.put(theme, :info, info_style)

      assert Theme.get(updated, :info) == info_style
    end

    test "updates an existing style" do
      original = Style.new(fg: :red)
      replacement = Style.new(fg: :magenta, bold: true)
      theme = Theme.new(:app, %{error: original})

      updated = Theme.put(theme, :error, replacement)

      assert Theme.get(updated, :error) == replacement
    end

    test "does not modify the original theme" do
      theme = Theme.new(:app, %{})

      Theme.put(theme, :info, Style.new(fg: :cyan))

      assert Theme.get(theme, :info) == nil
    end
  end

  describe "merge/2" do
    test "combines styles from both themes" do
      base = Theme.new(:base, %{error: Style.new(fg: :red)})
      extra = Theme.new(:extra, %{info: Style.new(fg: :cyan)})

      merged = Theme.merge(base, extra)

      assert Theme.get(merged, :error).fg == :red
      assert Theme.get(merged, :info).fg == :cyan
    end

    test "second theme overrides first" do
      base = Theme.new(:base, %{error: Style.new(fg: :red)})
      override = Theme.new(:dark, %{error: Style.new(fg: :magenta)})

      merged = Theme.merge(base, override)

      assert Theme.get(merged, :error).fg == :magenta
    end

    test "takes the name from the override theme" do
      base = Theme.new(:base, %{})
      override = Theme.new(:dark, %{})

      merged = Theme.merge(base, override)

      assert merged.name == :dark
    end
  end

  describe "resolve/2" do
    test "resolves a style name to a fully resolved Style" do
      theme = Theme.new(:app, %{error: Style.new(fg: :red)})

      resolved = Theme.resolve(theme, :error)

      assert resolved.fg == :red
      assert resolved.bg == :default
      assert resolved.bold == false
      assert resolved.italic == false
    end

    test "returns nil for a missing name" do
      theme = Theme.new(:app, %{})

      assert Theme.resolve(theme, :missing) == nil
    end

    test "preserves explicitly set values after resolving" do
      theme = Theme.new(:app, %{alert: Style.new(fg: :yellow, bold: true, italic: true)})

      resolved = Theme.resolve(theme, :alert)

      assert resolved.fg == :yellow
      assert resolved.bold == true
      assert resolved.italic == true
      assert resolved.bg == :default
    end
  end

  describe "default/0" do
    @expected_names [
      :text,
      :bold,
      :dim,
      :error,
      :warning,
      :success,
      :info,
      :muted,
      :border,
      :title,
      :selected,
      :focused,
      :status_bar,
      :input,
      :placeholder
    ]

    test "returns a theme named :default" do
      assert Theme.default().name == :default
    end

    test "contains all expected named styles" do
      theme = Theme.default()

      for name <- @expected_names do
        assert Theme.get(theme, name) != nil, "expected style #{inspect(name)} to be defined"
      end
    end

    test "every named style resolves to a valid Style" do
      theme = Theme.default()

      for name <- @expected_names do
        resolved = Theme.resolve(theme, name)
        assert %Style{} = resolved, "expected #{inspect(name)} to resolve to a Style"
        assert resolved.fg != nil, "expected #{inspect(name)} to have fg after resolve"
        assert resolved.bg != nil, "expected #{inspect(name)} to have bg after resolve"
      end
    end

    test "error style has red foreground and bold" do
      theme = Theme.default()
      error = Theme.get(theme, :error)

      assert error.fg == :red
      assert error.bold == true
    end

    test "warning style has yellow foreground" do
      assert Theme.get(Theme.default(), :warning).fg == :yellow
    end

    test "success style has green foreground" do
      assert Theme.get(Theme.default(), :success).fg == :green
    end

    test "info style has cyan foreground" do
      assert Theme.get(Theme.default(), :info).fg == :cyan
    end

    test "selected style has blue background and white foreground" do
      selected = Theme.get(Theme.default(), :selected)

      assert selected.bg == :blue
      assert selected.fg == :white
    end
  end

  doctest Tinct.Theme
end
