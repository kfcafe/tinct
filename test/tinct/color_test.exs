defmodule Tinct.ColorTest do
  use ExUnit.Case, async: true

  alias Tinct.Color

  doctest Tinct.Color

  describe "named_to_index/1" do
    test "maps standard colors to indices 0-7" do
      assert Color.named_to_index(:black) == 0
      assert Color.named_to_index(:red) == 1
      assert Color.named_to_index(:green) == 2
      assert Color.named_to_index(:yellow) == 3
      assert Color.named_to_index(:blue) == 4
      assert Color.named_to_index(:magenta) == 5
      assert Color.named_to_index(:cyan) == 6
      assert Color.named_to_index(:white) == 7
    end

    test "maps bright colors to indices 8-15" do
      assert Color.named_to_index(:bright_black) == 8
      assert Color.named_to_index(:bright_red) == 9
      assert Color.named_to_index(:bright_green) == 10
      assert Color.named_to_index(:bright_yellow) == 11
      assert Color.named_to_index(:bright_blue) == 12
      assert Color.named_to_index(:bright_magenta) == 13
      assert Color.named_to_index(:bright_cyan) == 14
      assert Color.named_to_index(:bright_white) == 15
    end

    test "dark_gray is an alias for bright_black (index 8)" do
      assert Color.named_to_index(:dark_gray) == Color.named_to_index(:bright_black)
    end

    test "all named colors produce valid indices" do
      named = [
        :black,
        :red,
        :green,
        :yellow,
        :blue,
        :magenta,
        :cyan,
        :white,
        :bright_black,
        :bright_red,
        :bright_green,
        :bright_yellow,
        :bright_blue,
        :bright_magenta,
        :bright_cyan,
        :bright_white,
        :dark_gray
      ]

      for name <- named do
        index = Color.named_to_index(name)
        assert index in 0..15, "#{name} should map to 0-15, got #{index}"
      end
    end
  end

  describe "to_ansi_fg/1" do
    test "standard colors produce codes 30-37" do
      assert Color.to_ansi_fg(:black) == [30]
      assert Color.to_ansi_fg(:red) == [31]
      assert Color.to_ansi_fg(:green) == [32]
      assert Color.to_ansi_fg(:yellow) == [33]
      assert Color.to_ansi_fg(:blue) == [34]
      assert Color.to_ansi_fg(:magenta) == [35]
      assert Color.to_ansi_fg(:cyan) == [36]
      assert Color.to_ansi_fg(:white) == [37]
    end

    test "bright colors produce codes 90-97" do
      assert Color.to_ansi_fg(:bright_black) == [90]
      assert Color.to_ansi_fg(:bright_red) == [91]
      assert Color.to_ansi_fg(:bright_green) == [92]
      assert Color.to_ansi_fg(:bright_yellow) == [93]
      assert Color.to_ansi_fg(:bright_blue) == [94]
      assert Color.to_ansi_fg(:bright_magenta) == [95]
      assert Color.to_ansi_fg(:bright_cyan) == [96]
      assert Color.to_ansi_fg(:bright_white) == [97]
    end

    test "dark_gray produces same code as bright_black" do
      assert Color.to_ansi_fg(:dark_gray) == [90]
    end

    test "indexed colors produce extended sequence 38;5;N" do
      assert Color.to_ansi_fg({:index, 0}) == [38, 5, 0]
      assert Color.to_ansi_fg({:index, 42}) == [38, 5, 42]
      assert Color.to_ansi_fg({:index, 255}) == [38, 5, 255]
    end

    test "RGB colors produce true color sequence 38;2;R;G;B" do
      assert Color.to_ansi_fg({:rgb, 255, 0, 0}) == [38, 2, 255, 0, 0]
      assert Color.to_ansi_fg({:rgb, 0, 128, 255}) == [38, 2, 0, 128, 255]
      assert Color.to_ansi_fg({:rgb, 0, 0, 0}) == [38, 2, 0, 0, 0]
    end

    test "default resets foreground with code 39" do
      assert Color.to_ansi_fg(:default) == [39]
    end
  end

  describe "to_ansi_bg/1" do
    test "standard colors produce codes 40-47" do
      assert Color.to_ansi_bg(:black) == [40]
      assert Color.to_ansi_bg(:red) == [41]
      assert Color.to_ansi_bg(:green) == [42]
      assert Color.to_ansi_bg(:yellow) == [43]
      assert Color.to_ansi_bg(:blue) == [44]
      assert Color.to_ansi_bg(:magenta) == [45]
      assert Color.to_ansi_bg(:cyan) == [46]
      assert Color.to_ansi_bg(:white) == [47]
    end

    test "bright colors produce codes 100-107" do
      assert Color.to_ansi_bg(:bright_black) == [100]
      assert Color.to_ansi_bg(:bright_red) == [101]
      assert Color.to_ansi_bg(:bright_green) == [102]
      assert Color.to_ansi_bg(:bright_yellow) == [103]
      assert Color.to_ansi_bg(:bright_blue) == [104]
      assert Color.to_ansi_bg(:bright_magenta) == [105]
      assert Color.to_ansi_bg(:bright_cyan) == [106]
      assert Color.to_ansi_bg(:bright_white) == [107]
    end

    test "indexed colors produce extended sequence 48;5;N" do
      assert Color.to_ansi_bg({:index, 42}) == [48, 5, 42]
    end

    test "RGB colors produce true color sequence 48;2;R;G;B" do
      assert Color.to_ansi_bg({:rgb, 255, 0, 0}) == [48, 2, 255, 0, 0]
    end

    test "default resets background with code 49" do
      assert Color.to_ansi_bg(:default) == [49]
    end
  end

  describe "downsample/2 — true_color" do
    test "passes through all color types unchanged" do
      assert Color.downsample(:red, :true_color) == :red
      assert Color.downsample(:bright_cyan, :true_color) == :bright_cyan
      assert Color.downsample({:index, 42}, :true_color) == {:index, 42}
      assert Color.downsample({:rgb, 100, 200, 50}, :true_color) == {:rgb, 100, 200, 50}
      assert Color.downsample(:default, :true_color) == :default
    end
  end

  describe "downsample/2 — ascii and no_tty" do
    test "ascii strips all color to :default" do
      assert Color.downsample(:red, :ascii) == :default
      assert Color.downsample({:index, 42}, :ascii) == :default
      assert Color.downsample({:rgb, 100, 200, 50}, :ascii) == :default
      assert Color.downsample(:default, :ascii) == :default
    end

    test "no_tty strips all color to :default" do
      assert Color.downsample(:red, :no_tty) == :default
      assert Color.downsample({:index, 42}, :no_tty) == :default
      assert Color.downsample({:rgb, 100, 200, 50}, :no_tty) == :default
      assert Color.downsample(:default, :no_tty) == :default
    end
  end

  describe "downsample/2 — ansi256" do
    test "passes named colors through unchanged" do
      assert Color.downsample(:red, :ansi256) == :red
      assert Color.downsample(:bright_cyan, :ansi256) == :bright_cyan
      assert Color.downsample(:dark_gray, :ansi256) == :dark_gray
    end

    test "passes indexed colors through unchanged" do
      assert Color.downsample({:index, 0}, :ansi256) == {:index, 0}
      assert Color.downsample({:index, 42}, :ansi256) == {:index, 42}
      assert Color.downsample({:index, 255}, :ansi256) == {:index, 255}
    end

    test "passes default through unchanged" do
      assert Color.downsample(:default, :ansi256) == :default
    end

    test "converts RGB to indexed color" do
      assert {:index, _} = Color.downsample({:rgb, 255, 0, 0}, :ansi256)
      assert {:index, _} = Color.downsample({:rgb, 0, 128, 255}, :ansi256)
    end

    test "pure black maps to cube black (index 16)" do
      assert Color.downsample({:rgb, 0, 0, 0}, :ansi256) == {:index, 16}
    end

    test "pure white maps to cube white (index 231)" do
      assert Color.downsample({:rgb, 255, 255, 255}, :ansi256) == {:index, 231}
    end

    test "mid-gray uses the grayscale ramp (232-255)" do
      {:index, n} = Color.downsample({:rgb, 128, 128, 128}, :ansi256)
      assert n in 232..255
    end

    test "pure red maps to the red area of the color cube" do
      {:index, n} = Color.downsample({:rgb, 255, 0, 0}, :ansi256)
      # 16 + 36*5 + 6*0 + 0 = 196
      assert n == 196
    end

    test "pure green maps to the green area of the color cube" do
      {:index, n} = Color.downsample({:rgb, 0, 255, 0}, :ansi256)
      # 16 + 36*0 + 6*5 + 0 = 46
      assert n == 46
    end

    test "pure blue maps to the blue area of the color cube" do
      {:index, n} = Color.downsample({:rgb, 0, 0, 255}, :ansi256)
      # 16 + 36*0 + 6*0 + 5 = 21
      assert n == 21
    end
  end

  describe "downsample/2 — ansi16" do
    test "passes named colors through unchanged" do
      assert Color.downsample(:red, :ansi16) == :red
      assert Color.downsample(:bright_cyan, :ansi16) == :bright_cyan
      assert Color.downsample(:dark_gray, :ansi16) == :dark_gray
    end

    test "passes default through unchanged" do
      assert Color.downsample(:default, :ansi16) == :default
    end

    test "converts indexed 0-15 to canonical named colors" do
      assert Color.downsample({:index, 0}, :ansi16) == :black
      assert Color.downsample({:index, 1}, :ansi16) == :red
      assert Color.downsample({:index, 7}, :ansi16) == :white
      assert Color.downsample({:index, 8}, :ansi16) == :bright_black
      assert Color.downsample({:index, 9}, :ansi16) == :bright_red
      assert Color.downsample({:index, 15}, :ansi16) == :bright_white
    end

    test "converts higher indexed colors to nearest named color" do
      result = Color.downsample({:index, 196}, :ansi16)
      assert is_atom(result)
      # Index 196 is bright red in the cube → should map to :bright_red
      assert result == :bright_red
    end

    test "converts grayscale indexed colors to named colors" do
      # Index 232 = very dark gray (value 8)
      result = Color.downsample({:index, 232}, :ansi16)
      assert is_atom(result)

      # Index 255 = near-white gray (value 238)
      result = Color.downsample({:index, 255}, :ansi16)
      assert is_atom(result)
    end

    test "pure black RGB maps to :black" do
      assert Color.downsample({:rgb, 0, 0, 0}, :ansi16) == :black
    end

    test "pure white RGB maps to :bright_white" do
      assert Color.downsample({:rgb, 255, 255, 255}, :ansi16) == :bright_white
    end

    test "pure red RGB maps to :bright_red" do
      assert Color.downsample({:rgb, 255, 0, 0}, :ansi16) == :bright_red
    end

    test "pure green RGB maps to :bright_green" do
      assert Color.downsample({:rgb, 0, 255, 0}, :ansi16) == :bright_green
    end

    test "pure blue RGB maps to :bright_blue" do
      assert Color.downsample({:rgb, 0, 0, 255}, :ansi16) == :bright_blue
    end
  end

  describe "round-trip conversions" do
    test "named → index → named preserves identity for all canonical colors" do
      canonical = [
        :black,
        :red,
        :green,
        :yellow,
        :blue,
        :magenta,
        :cyan,
        :white,
        :bright_black,
        :bright_red,
        :bright_green,
        :bright_yellow,
        :bright_blue,
        :bright_magenta,
        :bright_cyan,
        :bright_white
      ]

      for name <- canonical do
        index = Color.named_to_index(name)
        round_tripped = Color.downsample({:index, index}, :ansi16)
        assert round_tripped == name, "#{name} → #{index} → #{round_tripped}"
      end
    end
  end

  describe "edge cases" do
    test "grays downsample to grayscale ramp in 256-color mode" do
      for gray <- [32, 64, 96, 160, 192, 224] do
        {:index, n} = Color.downsample({:rgb, gray, gray, gray}, :ansi256)
        assert n in 232..255, "gray #{gray} should use grayscale ramp, got index #{n}"
      end
    end

    test "near-black downsample stays in cube (index 16)" do
      assert Color.downsample({:rgb, 0, 0, 0}, :ansi256) == {:index, 16}
    end

    test "near-white downsample stays in cube (index 231)" do
      assert Color.downsample({:rgb, 255, 255, 255}, :ansi256) == {:index, 231}
    end
  end
end
