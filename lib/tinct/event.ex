defmodule Tinct.Event.Key do
  @moduledoc """
  A keyboard input event.

  Represents a key press, release, or repeat. The `key` field is either a string
  for printable characters (`"a"`, `"A"`, `" "`) or an atom for special keys
  (`:enter`, `:escape`, `:tab`, `:f1`, etc.).

  ## Modifiers

  The `mod` field is a list of active modifier keys:

    * `:ctrl` — Control key
    * `:alt` — Alt/Option key
    * `:shift` — Shift key
    * `:super` — Super/Windows/Command key
    * `:meta` — Meta key

  ## Examples

      iex> %Tinct.Event.Key{key: "q", type: :press}
      %Tinct.Event.Key{key: "q", mod: [], type: :press, text: nil, is_repeat: false}

      iex> %Tinct.Event.Key{key: :escape}
      %Tinct.Event.Key{key: :escape, mod: [], type: :press, text: nil, is_repeat: false}
  """

  @type t :: %__MODULE__{
          key: atom() | String.t() | nil,
          mod: [atom()],
          type: :press | :release | :repeat,
          text: String.t() | nil,
          is_repeat: boolean()
        }

  defstruct key: nil,
            mod: [],
            type: :press,
            text: nil,
            is_repeat: false
end

defmodule Tinct.Event.Mouse do
  @moduledoc """
  A mouse input event.

  Represents mouse clicks, releases, scroll wheel, and motion. Coordinates
  are zero-indexed with `{0, 0}` at the top-left corner of the terminal.

  ## Examples

      iex> %Tinct.Event.Mouse{type: :click, button: :left, x: 10, y: 5}
      %Tinct.Event.Mouse{type: :click, button: :left, x: 10, y: 5, mod: []}
  """

  @type t :: %__MODULE__{
          type: :click | :release | :wheel | :motion,
          button: :left | :right | :middle | :wheel_up | :wheel_down | :none,
          x: non_neg_integer(),
          y: non_neg_integer(),
          mod: [atom()]
        }

  defstruct type: :click,
            button: :left,
            x: 0,
            y: 0,
            mod: []
end

defmodule Tinct.Event.Paste do
  @moduledoc """
  A bracketed paste event.

  Contains the text pasted into the terminal. Paste events are distinct from
  key events — they arrive as a single message rather than character-by-character.

  ## Examples

      iex> %Tinct.Event.Paste{content: "hello world"}
      %Tinct.Event.Paste{content: "hello world"}
  """

  @type t :: %__MODULE__{
          content: String.t()
        }

  defstruct content: ""
end

defmodule Tinct.Event.Resize do
  @moduledoc """
  A terminal resize event.

  Emitted when the terminal window changes size. The `width` and `height`
  reflect the new dimensions in columns and rows.

  ## Examples

      iex> %Tinct.Event.Resize{width: 120, height: 40}
      %Tinct.Event.Resize{width: 120, height: 40}
  """

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer()
        }

  defstruct width: 0,
            height: 0
end

defmodule Tinct.Event.Focus do
  @moduledoc """
  A terminal focus change event.

  Emitted when the terminal window gains or loses operating system focus.
  Requires focus reporting to be enabled (CSI ? 1004 h).

  ## Examples

      iex> %Tinct.Event.Focus{focused: true}
      %Tinct.Event.Focus{focused: true}

      iex> %Tinct.Event.Focus{focused: false}
      %Tinct.Event.Focus{focused: false}
  """

  @type t :: %__MODULE__{
          focused: boolean()
        }

  defstruct focused: true
end

defmodule Tinct.Event do
  @moduledoc """
  Event types for terminal input.

  All terminal input — keystrokes, mouse clicks, paste, resize, focus changes —
  is represented as a struct from one of the nested event modules. These structs
  are the messages that flow through the framework's update loop.

  ## Event Types

    * `Tinct.Event.Key` — keyboard input (press, release, repeat)
    * `Tinct.Event.Mouse` — mouse input (click, release, wheel, motion)
    * `Tinct.Event.Paste` — bracketed paste content
    * `Tinct.Event.Resize` — terminal size change
    * `Tinct.Event.Focus` — terminal focus gained or lost

  ## Convenience Functions

  Use `key/1` and `key/2` to quickly build key events for tests and message
  matching:

      iex> Tinct.Event.key("q")
      %Tinct.Event.Key{key: "q", mod: [], type: :press, text: "q", is_repeat: false}

      iex> Tinct.Event.key("c", [:ctrl])
      %Tinct.Event.Key{key: "c", mod: [:ctrl], type: :press, text: "c", is_repeat: false}

      iex> Tinct.Event.ctrl_c()
      %Tinct.Event.Key{key: "c", mod: [:ctrl], type: :press, text: "c", is_repeat: false}
  """

  alias Tinct.Event.Key

  @doc """
  Creates a key press event for the given key.

  When the key is a printable string, the `text` field is set automatically.
  When the key is a special atom (`:enter`, `:escape`, etc.), `text` is `nil`.

  ## Examples

      iex> Tinct.Event.key("a")
      %Tinct.Event.Key{key: "a", mod: [], type: :press, text: "a", is_repeat: false}

      iex> Tinct.Event.key(:enter)
      %Tinct.Event.Key{key: :enter, mod: [], type: :press, text: nil, is_repeat: false}
  """
  @spec key(atom() | String.t()) :: Key.t()
  def key(key) when is_binary(key) do
    %Key{key: key, mod: [], type: :press, text: key, is_repeat: false}
  end

  def key(key) when is_atom(key) do
    %Key{key: key, mod: [], type: :press, text: nil, is_repeat: false}
  end

  @doc """
  Creates a key press event with modifiers.

  Modifiers are a list of atoms: `:ctrl`, `:alt`, `:shift`, `:super`, `:meta`.

  ## Examples

      iex> Tinct.Event.key("c", [:ctrl])
      %Tinct.Event.Key{key: "c", mod: [:ctrl], type: :press, text: "c", is_repeat: false}

      iex> Tinct.Event.key(:left, [:shift, :alt])
      %Tinct.Event.Key{key: :left, mod: [:shift, :alt], type: :press, text: nil, is_repeat: false}
  """
  @spec key(atom() | String.t(), [atom()]) :: Key.t()
  def key(key, mod) when is_binary(key) and is_list(mod) do
    %Key{key: key, mod: mod, type: :press, text: key, is_repeat: false}
  end

  def key(key, mod) when is_atom(key) and is_list(mod) do
    %Key{key: key, mod: mod, type: :press, text: nil, is_repeat: false}
  end

  @doc """
  Creates a ctrl+c key press event.

  This is the most common quit signal in terminal applications.

  ## Examples

      iex> Tinct.Event.ctrl_c()
      %Tinct.Event.Key{key: "c", mod: [:ctrl], type: :press, text: "c", is_repeat: false}
  """
  @spec ctrl_c() :: Key.t()
  def ctrl_c do
    key("c", [:ctrl])
  end

  @doc """
  Returns `true` if the event is a key press.

  ## Examples

      iex> Tinct.Event.key_press?(Tinct.Event.key("a"))
      true

      iex> Tinct.Event.key_press?(%Tinct.Event.Key{key: "a", type: :release})
      false

      iex> Tinct.Event.key_press?(%Tinct.Event.Mouse{})
      false
  """
  @spec key_press?(term()) :: boolean()
  def key_press?(%Key{type: :press}), do: true
  def key_press?(_), do: false

  @doc """
  Returns `true` if the event is a key release.

  ## Examples

      iex> Tinct.Event.key_release?(%Tinct.Event.Key{key: "a", type: :release})
      true

      iex> Tinct.Event.key_release?(Tinct.Event.key("a"))
      false

      iex> Tinct.Event.key_release?(%Tinct.Event.Mouse{})
      false
  """
  @spec key_release?(term()) :: boolean()
  def key_release?(%Key{type: :release}), do: true
  def key_release?(_), do: false

  @doc """
  Returns `true` if the event is a printable character key press.

  Printable keys are string keys representing letters, numbers, symbols, and
  space. Non-printable keys are atoms like `:enter`, `:escape`, `:tab`, etc.

  ## Examples

      iex> Tinct.Event.printable?(Tinct.Event.key("a"))
      true

      iex> Tinct.Event.printable?(Tinct.Event.key(" "))
      true

      iex> Tinct.Event.printable?(Tinct.Event.key(:enter))
      false

      iex> Tinct.Event.printable?(%Tinct.Event.Mouse{})
      false
  """
  @spec printable?(term()) :: boolean()
  def printable?(%Key{key: key}) when is_binary(key), do: true
  def printable?(_), do: false
end
