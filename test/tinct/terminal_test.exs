defmodule Tinct.TerminalTest do
  use ExUnit.Case, async: false

  alias Tinct.Terminal
  alias Tinct.Terminal.State

  # Tests run without a TTY in CI, so terminal-dependent operations
  # are guarded. State management and logic are always testable.

  setup do
    # Ensure a fresh state agent for each test.
    # Stop any existing agent first.
    case Process.whereis(Terminal) do
      nil ->
        :ok

      pid ->
        if Process.alive?(pid) do
          Agent.stop(pid)
        end
    end

    Terminal.ensure_started()
    :ok
  end

  describe "State management" do
    test "default state has raw_mode false and alt_screen false" do
      state = Terminal.get_state()
      assert %State{raw_mode: false, alt_screen: false, original_opts: nil} = state
    end

    test "ensure_started/0 is idempotent" do
      assert :ok = Terminal.ensure_started()
      assert :ok = Terminal.ensure_started()
    end
  end

  describe "tty?/0" do
    test "returns a boolean" do
      result = Terminal.tty?()
      assert is_boolean(result)
    end
  end

  describe "iex?/0" do
    test "returns false in test environment" do
      refute Terminal.iex?()
    end
  end

  describe "size/0" do
    test "returns {:ok, {cols, rows}} with positive integers or an error tuple" do
      case Terminal.size() do
        {:ok, {cols, rows}} ->
          assert is_integer(cols) and cols > 0
          assert is_integer(rows) and rows > 0

        {:error, reason} ->
          # Expected in CI where no TTY is attached
          assert is_atom(reason)
      end
    end
  end

  describe "enable_raw_mode/0 and disable_raw_mode/0" do
    test "raw mode is not active by default" do
      refute Terminal.get_state().raw_mode
    end

    test "disable_raw_mode/0 is a no-op when not in raw mode" do
      assert :ok = Terminal.disable_raw_mode()
      refute Terminal.get_state().raw_mode
    end

    test "enable_raw_mode/0 is idempotent when already enabled" do
      # If we're on a TTY, enable will succeed and we should clean up.
      # If not on a TTY (CI), stty may fail — that's fine, we test the logic path.
      case Terminal.enable_raw_mode() do
        :ok ->
          assert Terminal.get_state().raw_mode
          # Second call should be a no-op
          assert :ok = Terminal.enable_raw_mode()
          assert Terminal.get_state().raw_mode
          # Clean up
          Terminal.disable_raw_mode()

        {:error, _reason} ->
          # stty not available or no TTY — state should remain unchanged
          refute Terminal.get_state().raw_mode
      end
    end

    test "disable_raw_mode/0 clears forced raw_mode state without original opts" do
      Agent.update(Terminal, fn _ ->
        %State{raw_mode: true, alt_screen: false, original_opts: nil}
      end)

      assert Terminal.disable_raw_mode() in [:ok, {:error, :not_a_tty}, {:error, :stty_timeout}]

      state = Terminal.get_state()
      refute state.raw_mode
      assert state.original_opts == nil
    end

    test "disable_raw_mode/0 restores original io opts when present" do
      Agent.update(Terminal, fn _ ->
        %State{raw_mode: true, alt_screen: false, original_opts: []}
      end)

      assert Terminal.disable_raw_mode() in [:ok, {:error, :not_a_tty}, {:error, :stty_timeout}]

      state = Terminal.get_state()
      refute state.raw_mode
      assert state.original_opts == nil
    end

    test "disable_raw_mode/0 resets state after enable" do
      case Terminal.enable_raw_mode() do
        :ok ->
          assert Terminal.get_state().raw_mode
          assert :ok = Terminal.disable_raw_mode()
          refute Terminal.get_state().raw_mode

        {:error, _} ->
          :ok
      end
    end
  end

  describe "enter_alt_screen/0 and exit_alt_screen/0" do
    test "enter_alt_screen/0 sets alt_screen state to true" do
      # Capture IO so we don't pollute test output
      ExUnit.CaptureIO.capture_io(fn ->
        assert :ok = Terminal.enter_alt_screen()
        assert Terminal.get_state().alt_screen
      end)
    end

    test "exit_alt_screen/0 sets alt_screen state to false" do
      ExUnit.CaptureIO.capture_io(fn ->
        Terminal.enter_alt_screen()
        assert :ok = Terminal.exit_alt_screen()
        refute Terminal.get_state().alt_screen
      end)
    end
  end

  describe "with_raw_mode/1" do
    test "restores state even when the function raises" do
      # We test the state management path regardless of whether stty works.
      # If stty fails, with_raw_mode returns {:error, _} and never enters the block.
      # If stty succeeds, we verify cleanup happens after an exception.
      case Terminal.enable_raw_mode() do
        :ok ->
          # Disable so we can test with_raw_mode from a clean state
          Terminal.disable_raw_mode()

          assert_raise RuntimeError, "boom", fn ->
            Terminal.with_raw_mode(fn ->
              assert Terminal.get_state().raw_mode
              raise "boom"
            end)
          end

          # State must be restored after the exception
          refute Terminal.get_state().raw_mode

        {:error, _} ->
          # stty unavailable — with_raw_mode should return error, not enter block
          assert {:error, _} = Terminal.with_raw_mode(fn -> :should_not_run end)
          refute Terminal.get_state().raw_mode
      end
    end

    test "executes and cleans up when raw mode flag is already active" do
      Agent.update(Terminal, fn _ ->
        %State{raw_mode: true, alt_screen: false, original_opts: nil}
      end)

      result = Terminal.with_raw_mode(fn -> :ran end)
      assert result == :ran
      refute Terminal.get_state().raw_mode
    end

    test "returns the function's result on success" do
      case Terminal.enable_raw_mode() do
        :ok ->
          Terminal.disable_raw_mode()

          result = Terminal.with_raw_mode(fn -> {:ok, 42} end)
          assert result == {:ok, 42}
          refute Terminal.get_state().raw_mode

        {:error, _} ->
          :ok
      end
    end
  end
end
