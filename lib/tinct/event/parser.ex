defmodule Tinct.Event.Parser do
  @moduledoc """
  Parses raw terminal bytes into structured event structs.

  A pure function parser — no state, no side effects. Takes a binary of terminal
  input and returns a list of `Tinct.Event.*` structs plus any leftover bytes
  from incomplete escape sequences.

  Handles:
  - Printable ASCII characters
  - Control keys (enter, tab, escape, backspace)
  - Ctrl+letter combinations
  - CSI sequences (arrows, function keys, page up/down, home/end, delete)
  - SS3 sequences (F1-F4)
  - Arrow keys with modifiers (shift, alt, ctrl)
  - SGR mouse encoding (`\\e[<...M` / `\\e[<...m`)
  - Bracketed paste (`\\e[200~` ... `\\e[201~`)
  - Focus events (`\\e[I` / `\\e[O`)
  - Alt+key (ESC followed by a character)

  Incomplete sequences are returned as remaining bytes so the caller can prepend
  them to the next read.

  ## Examples

      iex> Tinct.Event.Parser.parse("a")
      {[%Tinct.Event.Key{key: "a", mod: [], type: :press, text: "a", is_repeat: false}], ""}

      iex> Tinct.Event.Parser.parse("\\e[A")
      {[%Tinct.Event.Key{key: :up, mod: [], type: :press, text: nil, is_repeat: false}], ""}
  """

  import Bitwise

  alias Tinct.Event.{Focus, Key, Mouse, Paste}

  @doc """
  Parses raw terminal bytes into structured events.

  Returns `{events, remaining}` where `events` is a list of event structs
  and `remaining` is any unparsed trailing bytes from an incomplete escape
  sequence.

  ## Examples

      iex> Tinct.Event.Parser.parse("hello")
      {[
        %Tinct.Event.Key{key: "h", mod: [], type: :press, text: "h", is_repeat: false},
        %Tinct.Event.Key{key: "e", mod: [], type: :press, text: "e", is_repeat: false},
        %Tinct.Event.Key{key: "l", mod: [], type: :press, text: "l", is_repeat: false},
        %Tinct.Event.Key{key: "l", mod: [], type: :press, text: "l", is_repeat: false},
        %Tinct.Event.Key{key: "o", mod: [], type: :press, text: "o", is_repeat: false}
      ], ""}
  """
  @spec parse(binary()) :: {[struct()], binary()}
  def parse(data) when is_binary(data) do
    parse_bytes(data, [])
  end

  # --- Top-level dispatch ---

  defp parse_bytes(<<>>, acc), do: {Enum.reverse(acc), ""}

  # Bracketed paste start: \e[200~
  defp parse_bytes(<<"\e[200~", rest::binary>>, acc) do
    parse_paste(rest, "", acc)
  end

  # ESC [ — CSI sequence
  defp parse_bytes(<<"\e[", rest::binary>>, acc) do
    parse_csi(rest, acc)
  end

  # ESC O — SS3 sequence (F1-F4)
  defp parse_bytes(<<"\eO", rest::binary>>, acc) do
    parse_ss3(rest, acc)
  end

  # ESC followed by a printable character — Alt+key
  defp parse_bytes(<<"\e", char, rest::binary>>, acc) when char >= 32 and char <= 126 do
    event = %Key{key: <<char>>, mod: [:alt], type: :press, text: <<char>>}
    parse_bytes(rest, [event | acc])
  end

  # Lone ESC — might be incomplete or actual escape key
  # If there's nothing after, it could be an incomplete sequence
  defp parse_bytes(<<"\e">>, acc) do
    {Enum.reverse(acc), "\e"}
  end

  # ESC followed by something we don't recognize — emit escape key, re-parse rest
  defp parse_bytes(<<"\e", rest::binary>>, acc) do
    event = %Key{key: :escape, mod: [], type: :press}
    parse_bytes(rest, [event | acc])
  end

  # Enter — CR (raw mode) or LF (cooked mode)
  defp parse_bytes(<<13, rest::binary>>, acc) do
    event = %Key{key: :enter, mod: [], type: :press}
    parse_bytes(rest, [event | acc])
  end

  defp parse_bytes(<<10, rest::binary>>, acc) do
    event = %Key{key: :enter, mod: [], type: :press}
    parse_bytes(rest, [event | acc])
  end

  # Tab
  defp parse_bytes(<<9, rest::binary>>, acc) do
    event = %Key{key: :tab, mod: [], type: :press}
    parse_bytes(rest, [event | acc])
  end

  # Backspace (DEL)
  defp parse_bytes(<<127, rest::binary>>, acc) do
    event = %Key{key: :backspace, mod: [], type: :press}
    parse_bytes(rest, [event | acc])
  end

  # Backspace (BS)
  defp parse_bytes(<<8, rest::binary>>, acc) do
    event = %Key{key: :backspace, mod: [], type: :press}
    parse_bytes(rest, [event | acc])
  end

  # Ctrl+letter (1-26, excluding tab=9, enter=13)
  defp parse_bytes(<<byte, rest::binary>>, acc)
       when byte >= 1 and byte <= 26 and byte != 9 and byte != 13 do
    letter = <<byte + 96>>
    event = %Key{key: letter, mod: [:ctrl], type: :press, text: letter}
    parse_bytes(rest, [event | acc])
  end

  # Printable ASCII (32-126)
  defp parse_bytes(<<char, rest::binary>>, acc) when char >= 32 and char <= 126 do
    event = %Key{key: <<char>>, mod: [], type: :press, text: <<char>>}
    parse_bytes(rest, [event | acc])
  end

  # Unknown byte — skip it gracefully
  defp parse_bytes(<<_byte, rest::binary>>, acc) do
    parse_bytes(rest, acc)
  end

  # --- CSI sequences (\e[ already consumed) ---

  # Focus in: \e[I
  defp parse_csi(<<"I", rest::binary>>, acc) do
    event = %Focus{focused: true}
    parse_bytes(rest, [event | acc])
  end

  # Focus out: \e[O
  defp parse_csi(<<"O", rest::binary>>, acc) do
    event = %Focus{focused: false}
    parse_bytes(rest, [event | acc])
  end

  # SGR mouse: \e[< ...
  defp parse_csi(<<"<", rest::binary>>, acc) do
    parse_sgr_mouse(rest, "", acc)
  end

  # General CSI: collect params then dispatch on final byte
  defp parse_csi(data, acc) do
    parse_csi_params(data, "", acc)
  end

  # Collect CSI parameter bytes (digits, semicolons) until we hit a final byte
  defp parse_csi_params(<<char, rest::binary>>, params, acc)
       when char >= 0x30 and char <= 0x3F do
    parse_csi_params(rest, params <> <<char>>, acc)
  end

  # Skip intermediate bytes (0x20-0x2F)
  defp parse_csi_params(<<char, rest::binary>>, params, acc)
       when char >= 0x20 and char <= 0x2F do
    parse_csi_params(rest, params, acc)
  end

  # Final byte (0x40-0x7E) — dispatch
  defp parse_csi_params(<<final, rest::binary>>, params, acc)
       when final >= 0x40 and final <= 0x7E do
    event = csi_event(params, final)
    parse_bytes(rest, maybe_prepend(event, acc))
  end

  # Incomplete CSI — return remaining
  defp parse_csi_params(<<>>, params, acc) do
    {Enum.reverse(acc), "\e[" <> params}
  end

  # Unknown byte in CSI — skip the whole sequence
  defp parse_csi_params(<<_byte, rest::binary>>, _params, acc) do
    parse_bytes(rest, acc)
  end

  # --- CSI dispatch ---

  # Arrow keys: A=up, B=down, C=right, D=left
  defp csi_event("", ?A), do: %Key{key: :up, mod: [], type: :press}
  defp csi_event("", ?B), do: %Key{key: :down, mod: [], type: :press}
  defp csi_event("", ?C), do: %Key{key: :right, mod: [], type: :press}
  defp csi_event("", ?D), do: %Key{key: :left, mod: [], type: :press}

  # Home / End
  defp csi_event("", ?H), do: %Key{key: :home, mod: [], type: :press}
  defp csi_event("", ?F), do: %Key{key: :end, mod: [], type: :press}

  # Tilde sequences: \e[N~ where N is the key number
  defp csi_event(params, ?~) do
    parse_tilde_sequence(params)
  end

  # Arrow with modifiers: \e[1;{mod}A etc.
  defp csi_event(params, final) when final in [?A, ?B, ?C, ?D, ?H, ?F] do
    key =
      case final do
        ?A -> :up
        ?B -> :down
        ?C -> :right
        ?D -> :left
        ?H -> :home
        ?F -> :end
      end

    mod = extract_modifier(params)
    %Key{key: key, mod: mod, type: :press}
  end

  # Unknown CSI — skip
  defp csi_event(_params, _final), do: nil

  # --- Tilde sequences ---

  defp parse_tilde_sequence(params) do
    case String.split(params, ";") do
      [num_str] ->
        tilde_key(String.to_integer(num_str), [])

      [num_str, mod_str] ->
        mod = decode_modifier(String.to_integer(mod_str))
        tilde_key(String.to_integer(num_str), mod)

      _other ->
        nil
    end
  end

  defp tilde_key(3, mod), do: %Key{key: :delete, mod: mod, type: :press}
  defp tilde_key(5, mod), do: %Key{key: :page_up, mod: mod, type: :press}
  defp tilde_key(6, mod), do: %Key{key: :page_down, mod: mod, type: :press}
  defp tilde_key(1, mod), do: %Key{key: :home, mod: mod, type: :press}
  defp tilde_key(4, mod), do: %Key{key: :end, mod: mod, type: :press}
  defp tilde_key(2, mod), do: %Key{key: :insert, mod: mod, type: :press}

  # Function keys via CSI
  defp tilde_key(11, mod), do: %Key{key: :f1, mod: mod, type: :press}
  defp tilde_key(12, mod), do: %Key{key: :f2, mod: mod, type: :press}
  defp tilde_key(13, mod), do: %Key{key: :f3, mod: mod, type: :press}
  defp tilde_key(14, mod), do: %Key{key: :f4, mod: mod, type: :press}
  defp tilde_key(15, mod), do: %Key{key: :f5, mod: mod, type: :press}
  defp tilde_key(17, mod), do: %Key{key: :f6, mod: mod, type: :press}
  defp tilde_key(18, mod), do: %Key{key: :f7, mod: mod, type: :press}
  defp tilde_key(19, mod), do: %Key{key: :f8, mod: mod, type: :press}
  defp tilde_key(20, mod), do: %Key{key: :f9, mod: mod, type: :press}
  defp tilde_key(21, mod), do: %Key{key: :f10, mod: mod, type: :press}
  defp tilde_key(23, mod), do: %Key{key: :f11, mod: mod, type: :press}
  defp tilde_key(24, mod), do: %Key{key: :f12, mod: mod, type: :press}

  # Bracketed paste markers (handled separately, but just in case)
  defp tilde_key(200, _mod), do: nil
  defp tilde_key(201, _mod), do: nil

  defp tilde_key(_num, _mod), do: nil

  # --- SS3 sequences (\eO already consumed) ---

  defp parse_ss3(<<"P", rest::binary>>, acc) do
    event = %Key{key: :f1, mod: [], type: :press}
    parse_bytes(rest, [event | acc])
  end

  defp parse_ss3(<<"Q", rest::binary>>, acc) do
    event = %Key{key: :f2, mod: [], type: :press}
    parse_bytes(rest, [event | acc])
  end

  defp parse_ss3(<<"R", rest::binary>>, acc) do
    event = %Key{key: :f3, mod: [], type: :press}
    parse_bytes(rest, [event | acc])
  end

  defp parse_ss3(<<"S", rest::binary>>, acc) do
    event = %Key{key: :f4, mod: [], type: :press}
    parse_bytes(rest, [event | acc])
  end

  # Incomplete SS3
  defp parse_ss3(<<>>, acc) do
    {Enum.reverse(acc), "\eO"}
  end

  # Unknown SS3 — skip
  defp parse_ss3(<<_byte, rest::binary>>, acc) do
    parse_bytes(rest, acc)
  end

  # --- SGR mouse (\e[< already consumed) ---

  # Collect until M (press) or m (release)
  defp parse_sgr_mouse(<<"M", rest::binary>>, params, acc) do
    event = decode_sgr_mouse(params, :press)
    parse_bytes(rest, maybe_prepend(event, acc))
  end

  defp parse_sgr_mouse(<<"m", rest::binary>>, params, acc) do
    event = decode_sgr_mouse(params, :release)
    parse_bytes(rest, maybe_prepend(event, acc))
  end

  defp parse_sgr_mouse(<<char, rest::binary>>, params, acc)
       when (char >= ?0 and char <= ?9) or char == ?; do
    parse_sgr_mouse(rest, params <> <<char>>, acc)
  end

  # Incomplete SGR mouse
  defp parse_sgr_mouse(<<>>, params, acc) do
    {Enum.reverse(acc), "\e[<" <> params}
  end

  # Invalid SGR mouse — skip
  defp parse_sgr_mouse(<<_byte, rest::binary>>, _params, acc) do
    parse_bytes(rest, acc)
  end

  defp decode_sgr_mouse(params, press_or_release) do
    case String.split(params, ";") do
      [button_str, x_str, y_str] ->
        button_code = String.to_integer(button_str)
        x = String.to_integer(x_str) - 1
        y = String.to_integer(y_str) - 1

        {type, button, mod} = decode_mouse_button(button_code, press_or_release)
        %Mouse{type: type, button: button, x: x, y: y, mod: mod}

      _other ->
        nil
    end
  end

  defp decode_mouse_button(code, press_or_release) do
    # Modifier bits: 4=shift, 8=alt, 16=ctrl
    mod = decode_mouse_modifiers(code &&& 0x1C)

    # Motion flag: bit 32
    motion? = (code &&& 32) != 0

    # Base button (bits 0-1 + bit 6-7 for wheel)
    base = code &&& 0x43

    case {base, motion?} do
      {64, _motion?} ->
        {:wheel, :wheel_up, mod}

      {65, _motion?} ->
        {:wheel, :wheel_down, mod}

      {_base, true} ->
        {:motion, motion_mouse_button(base), mod}

      {_base, false} ->
        {mouse_click_type(press_or_release), click_mouse_button(base), mod}
    end
  end

  defp motion_mouse_button(base) do
    case base do
      0 -> :left
      1 -> :middle
      2 -> :right
      _ -> :none
    end
  end

  defp click_mouse_button(base) do
    case base do
      0 -> :left
      1 -> :middle
      2 -> :right
      3 -> :none
      _ -> :none
    end
  end

  defp mouse_click_type(:release), do: :release
  defp mouse_click_type(_press_or_release), do: :click

  defp decode_mouse_modifiers(bits) do
    []
    |> then(fn m -> if (bits &&& 4) != 0, do: [:shift | m], else: m end)
    |> then(fn m -> if (bits &&& 8) != 0, do: [:alt | m], else: m end)
    |> then(fn m -> if (bits &&& 16) != 0, do: [:ctrl | m], else: m end)
  end

  # --- Bracketed paste (\e[200~ already consumed) ---

  defp parse_paste(<<"\e[201~", rest::binary>>, content, acc) do
    event = %Paste{content: content}
    parse_bytes(rest, [event | acc])
  end

  defp parse_paste(<<char, rest::binary>>, content, acc) do
    parse_paste(rest, content <> <<char>>, acc)
  end

  # Incomplete paste — return everything as remaining
  defp parse_paste(<<>>, content, acc) do
    {Enum.reverse(acc), "\e[200~" <> content}
  end

  # --- Modifier decoding ---

  defp extract_modifier(params) do
    case String.split(params, ";") do
      [_n, mod_str] ->
        decode_modifier(String.to_integer(mod_str))

      _other ->
        []
    end
  end

  # xterm modifier encoding: value = 1 + bitmask
  # 1=shift, 2=alt, 4=ctrl, 8=meta
  defp decode_modifier(value) do
    bits = value - 1

    []
    |> then(fn m -> if (bits &&& 1) != 0, do: [:shift | m], else: m end)
    |> then(fn m -> if (bits &&& 2) != 0, do: [:alt | m], else: m end)
    |> then(fn m -> if (bits &&& 4) != 0, do: [:ctrl | m], else: m end)
    |> then(fn m -> if (bits &&& 8) != 0, do: [:meta | m], else: m end)
    |> Enum.reverse()
  end

  # --- Helpers ---

  defp maybe_prepend(nil, acc), do: acc
  defp maybe_prepend(event, acc), do: [event | acc]
end
