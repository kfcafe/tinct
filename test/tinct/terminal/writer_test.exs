defmodule Tinct.Terminal.WriterTest do
  use ExUnit.Case, async: true

  alias Tinct.Terminal.Writer

  defp start_writer(opts \\ []) do
    opts = Keyword.put_new(opts, :output, self())
    {:ok, writer} = Writer.start_link(opts)
    writer
  end

  describe "start_link/1" do
    test "starts with default options" do
      writer = start_writer()
      assert is_pid(writer)
      assert Process.alive?(writer)
    end

    test "accepts name option" do
      {:ok, writer} = Writer.start_link(output: self(), name: :test_writer)
      assert Process.whereis(:test_writer) == writer
    end
  end

  describe "write/2" do
    test "queues data without sending" do
      writer = start_writer()
      assert :ok = Writer.write(writer, "hello")
      refute_receive {:terminal_output, _}
    end

    test "accepts iodata" do
      writer = start_writer()
      assert :ok = Writer.write(writer, ["he", ?l, "lo"])
      refute_receive {:terminal_output, _}
    end
  end

  describe "flush/1" do
    test "sends all queued data" do
      writer = start_writer()
      Writer.write(writer, "hello")
      Writer.flush(writer)
      assert_receive {:terminal_output, "hello"}
    end

    test "empty flush sends nothing" do
      writer = start_writer()
      Writer.flush(writer)
      refute_receive {:terminal_output, _}
    end

    test "clears buffer after flush" do
      writer = start_writer()
      Writer.write(writer, "first")
      Writer.flush(writer)
      assert_receive {:terminal_output, "first"}

      Writer.flush(writer)
      refute_receive {:terminal_output, _}
    end

    test "multiple writes are batched into one flush" do
      writer = start_writer()
      Writer.write(writer, "one")
      Writer.write(writer, "two")
      Writer.write(writer, "three")
      Writer.flush(writer)

      assert_receive {:terminal_output, output}
      assert output == "onetwothree"
      refute_receive {:terminal_output, _}
    end
  end

  describe "sync rendering" do
    test "wraps output in begin/end sync markers" do
      writer = start_writer(sync_rendering: true)
      Writer.write(writer, "content")
      Writer.flush(writer)

      assert_receive {:terminal_output, output}
      assert output == "\e[?2026h" <> "content" <> "\e[?2026l"
    end

    test "does not wrap when sync_rendering is false" do
      writer = start_writer(sync_rendering: false)
      Writer.write(writer, "content")
      Writer.flush(writer)

      assert_receive {:terminal_output, "content"}
    end

    test "empty flush sends nothing even with sync rendering" do
      writer = start_writer(sync_rendering: true)
      Writer.flush(writer)
      refute_receive {:terminal_output, _}
    end
  end

  describe "write_and_flush/2" do
    test "sends data immediately" do
      writer = start_writer()
      Writer.write_and_flush(writer, "immediate")
      assert_receive {:terminal_output, "immediate"}
    end

    test "includes previously buffered data" do
      writer = start_writer()
      Writer.write(writer, "buffered")
      Writer.write_and_flush(writer, "immediate")

      assert_receive {:terminal_output, output}
      assert output == "bufferedimmediate"
      refute_receive {:terminal_output, _}
    end

    test "with sync rendering wraps in sync markers" do
      writer = start_writer(sync_rendering: true)
      Writer.write_and_flush(writer, "frame")

      assert_receive {:terminal_output, output}
      assert output == "\e[?2026h" <> "frame" <> "\e[?2026l"
    end
  end

  describe "successive flushes" do
    test "each flush is independent" do
      writer = start_writer()

      Writer.write(writer, "frame1")
      Writer.flush(writer)
      assert_receive {:terminal_output, "frame1"}

      Writer.write(writer, "frame2")
      Writer.flush(writer)
      assert_receive {:terminal_output, "frame2"}
    end
  end
end
