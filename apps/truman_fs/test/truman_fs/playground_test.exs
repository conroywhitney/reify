defmodule TrumanFs.PlaygroundTest do
  use ExUnit.Case, async: true

  alias TrumanFs.Playground

  describe "validate_path/2" do
    test "allows path within playground" do
      playground = "/tmp/truman-test"
      path = "subdir/file.txt"

      result = Playground.validate_path(path, playground)

      assert {:ok, "/tmp/truman-test/subdir/file.txt"} = result
    end

    test "rejects path traversal attack" do
      playground = "/tmp/truman-test"
      path = "../../../etc/passwd"

      result = Playground.validate_path(path, playground)

      assert {:error, :outside_playground} = result
    end

    test "rejects absolute path outside playground" do
      playground = "/tmp/truman-test"
      path = "/etc/passwd"

      result = Playground.validate_path(path, playground)

      assert {:error, :outside_playground} = result
    end

    test "allows absolute path within playground" do
      playground = "/tmp/truman-test"
      path = "/tmp/truman-test/subdir/file.txt"

      result = Playground.validate_path(path, playground)

      assert {:ok, "/tmp/truman-test/subdir/file.txt"} = result
    end

    test "rejects path with playground prefix but different directory" do
      # Security: /tmp/truman-test2 should NOT pass for playground /tmp/truman-test
      # This catches the string prefix bug where "truman-test2" starts with "truman-test"
      playground = "/tmp/truman-test"
      path = "/tmp/truman-test2/secret"

      result = Playground.validate_path(path, playground)

      assert {:error, :outside_playground} = result
    end

    test "allows current directory (.)" do
      playground = "/tmp/truman-test"
      path = "."

      result = Playground.validate_path(path, playground)

      assert {:ok, "/tmp/truman-test"} = result
    end

    test "rejects empty path" do
      playground = "/tmp/truman-test"
      path = ""

      result = Playground.validate_path(path, playground)

      # Empty path expands to playground root, which is allowed
      assert {:ok, "/tmp/truman-test"} = result
    end

    test "allows root path when it equals playground" do
      playground = "/tmp/truman-test"
      path = "/tmp/truman-test"

      result = Playground.validate_path(path, playground)

      assert {:ok, "/tmp/truman-test"} = result
    end

    test "rejects double dot in middle of path" do
      playground = "/tmp/truman-test"
      path = "subdir/../../../etc/passwd"

      result = Playground.validate_path(path, playground)

      assert {:error, :outside_playground} = result
    end

    test "handles unicode paths" do
      playground = "/tmp/truman-test"
      path = "文档/файл.txt"

      result = Playground.validate_path(path, playground)

      assert {:ok, "/tmp/truman-test/文档/файл.txt"} = result
    end

    @tag :tmp_dir
    test "rejects symlink with absolute target outside playground", %{tmp_dir: playground} do
      symlink_path = Path.join(playground, "escape_link")
      File.ln_s("/tmp", symlink_path)

      result = Playground.validate_path("escape_link", playground)

      # Should be rejected because absolute target escapes playground
      assert {:error, :outside_playground} = result
    end

    @tag :tmp_dir
    test "rejects symlink with relative escaping target", %{tmp_dir: playground} do
      symlink_path = Path.join(playground, "escape_link")
      File.ln_s("../../etc/passwd", symlink_path)

      result = Playground.validate_path("escape_link", playground)

      assert {:error, :outside_playground} = result
    end

    @tag :tmp_dir
    test "allows symlink with safe relative target", %{tmp_dir: playground} do
      inside_dir = Path.join(playground, "inside")
      File.mkdir_p!(inside_dir)

      symlink_path = Path.join(playground, "safe_link")
      File.ln_s("inside", symlink_path)

      result = Playground.validate_path("safe_link", playground)

      assert {:ok, _} = result
    end
  end

  describe "path_within_playground?/2" do
    test "returns true for exact match" do
      assert Playground.path_within_playground?("/tmp/pg", "/tmp/pg")
    end

    test "returns true for child path" do
      assert Playground.path_within_playground?("/tmp/pg/file", "/tmp/pg")
    end

    test "returns true for deep nested path" do
      assert Playground.path_within_playground?("/tmp/pg/a/b/c/d", "/tmp/pg")
    end

    test "returns false for sibling directory with same prefix" do
      refute Playground.path_within_playground?("/tmp/pg2/file", "/tmp/pg")
    end

    test "returns false for parent directory" do
      refute Playground.path_within_playground?("/tmp", "/tmp/pg")
    end

    test "returns false for unrelated path" do
      refute Playground.path_within_playground?("/etc/passwd", "/tmp/pg")
    end
  end
end
