defmodule Tinct.Event.ReaderTest do
  use ExUnit.Case, async: true

  alias Tinct.Event.Key
  alias Tinct.Event.Reader

  describe "start_link/1" do
    test "starts with test input mode" do
      {:ok, reader} = Reader.start_link(target: self(), input_mode: {:test, self()})
      assert Process.alive?(reader)
      Reader.stop(reader)
    end
  end

  describe "event parsing — printable characters" do
    test "sends key event for a printable character" do
      {:ok, reader} = Reader.start_link(target: self(), input_mode: {:test, self()})

      send(reader, {:test_input, "a"})
      assert_receive {:event, %Key{key: "a", mod: [], type: :press, text: "a"}}

      Reader.stop(reader)
    end
  end

  describe "event parsing — escape sequences" do
    test "sends key event for up arrow" do
      {:ok, reader} = Reader.start_link(target: self(), input_mode: {:test, self()})

      send(reader, {:test_input, "\e[A"})
      assert_receive {:event, %Key{key: :up, mod: [], type: :press}}

      Reader.stop(reader)
    end

    test "sends key event for down arrow" do
      {:ok, reader} = Reader.start_link(target: self(), input_mode: {:test, self()})

      send(reader, {:test_input, "\e[B"})
      assert_receive {:event, %Key{key: :down, mod: [], type: :press}}

      Reader.stop(reader)
    end
  end

  describe "event parsing — multiple events" do
    test "sends all events from a single chunk" do
      {:ok, reader} = Reader.start_link(target: self(), input_mode: {:test, self()})

      send(reader, {:test_input, "abc"})
      assert_receive {:event, %Key{key: "a"}}
      assert_receive {:event, %Key{key: "b"}}
      assert_receive {:event, %Key{key: "c"}}

      Reader.stop(reader)
    end

    test "sends events from mixed printable and escape sequences" do
      {:ok, reader} = Reader.start_link(target: self(), input_mode: {:test, self()})

      send(reader, {:test_input, "x\e[Ay"})
      assert_receive {:event, %Key{key: "x"}}
      assert_receive {:event, %Key{key: :up}}
      assert_receive {:event, %Key{key: "y"}}

      Reader.stop(reader)
    end
  end

  describe "buffering — incomplete sequences" do
    test "buffers incomplete escape sequence until next read" do
      {:ok, reader} = Reader.start_link(target: self(), input_mode: {:test, self()})

      # Send incomplete escape sequence
      send(reader, {:test_input, "\e["})
      refute_receive {:event, _}, 50

      # Complete it with next chunk
      send(reader, {:test_input, "A"})
      assert_receive {:event, %Key{key: :up, mod: [], type: :press}}

      Reader.stop(reader)
    end

    test "buffers lone escape" do
      {:ok, reader} = Reader.start_link(target: self(), input_mode: {:test, self()})

      send(reader, {:test_input, "\e"})
      refute_receive {:event, _}, 50

      # Complete as alt+key
      send(reader, {:test_input, "x"})
      assert_receive {:event, %Key{key: "x", mod: [:alt]}}

      Reader.stop(reader)
    end
  end

  describe "stop/1" do
    test "stops the reader process" do
      {:ok, reader} = Reader.start_link(target: self(), input_mode: {:test, self()})
      assert Process.alive?(reader)

      Reader.stop(reader)
      refute Process.alive?(reader)
    end
  end

  describe "stdio mode callbacks" do
    test "accepts injected port data and eof messages" do
      {:ok, reader} = Reader.start_link(target: self(), input_mode: :stdio)

      state = :sys.get_state(reader)
      assert is_port(state.port)

      send(reader, {state.port, {:data, "z"}})
      assert_receive {:event, %Key{key: "z"}}

      send(reader, {state.port, :eof})
      assert %{active: false} = :sys.get_state(reader)

      Reader.stop(reader)
    end

    test "marks test-mode reader inactive on :eof" do
      {:ok, reader} = Reader.start_link(target: self(), input_mode: {:test, self()})

      send(reader, :eof)
      assert %{active: false} = :sys.get_state(reader)

      Reader.stop(reader)
    end

    test "terminate/2 swallows close errors for already-closed ports" do
      {:ok, reader} = Reader.start_link(target: self(), input_mode: :stdio)
      state = :sys.get_state(reader)

      Port.close(state.port)

      assert :ok = Reader.terminate(:normal, state)

      Reader.stop(reader)
    end
  end
end
