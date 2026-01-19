defmodule ReifyFs.WhitelistTest do
  use ExUnit.Case, async: true

  alias ReifyFs.Whitelist

  describe "new/1" do
    test "creates whitelist with initial paths" do
      whitelist = Whitelist.new(["/home/user/projects", "/tmp"])

      assert Whitelist.allowed?(whitelist, "/home/user/projects")
      assert Whitelist.allowed?(whitelist, "/tmp")
    end

    test "creates empty whitelist when given no paths" do
      whitelist = Whitelist.new([])

      refute Whitelist.allowed?(whitelist, "/home/user/projects")
      refute Whitelist.allowed?(whitelist, "/tmp")
    end
  end

  describe "add/2" do
    test "adds a single path to the whitelist" do
      whitelist = Whitelist.new([])
      whitelist = Whitelist.add(whitelist, "/home/user/documents")

      assert Whitelist.allowed?(whitelist, "/home/user/documents")
    end

    test "adding existing path is idempotent" do
      whitelist = Whitelist.new(["/home/user/projects"])
      whitelist = Whitelist.add(whitelist, "/home/user/projects")

      assert Whitelist.allowed?(whitelist, "/home/user/projects")
    end
  end

  describe "remove/2" do
    test "removes a path from the whitelist" do
      whitelist = Whitelist.new(["/home/user/projects", "/tmp"])
      whitelist = Whitelist.remove(whitelist, "/home/user/projects")

      refute Whitelist.allowed?(whitelist, "/home/user/projects")
      assert Whitelist.allowed?(whitelist, "/tmp")
    end

    test "removing non-existent path is idempotent" do
      whitelist = Whitelist.new(["/tmp"])
      whitelist = Whitelist.remove(whitelist, "/nonexistent")

      assert Whitelist.allowed?(whitelist, "/tmp")
    end
  end

  describe "allowed?/2 with prefix matching" do
    test "allows child paths under whitelisted directory" do
      whitelist = Whitelist.new(["/home/user/projects"])

      assert Whitelist.allowed?(whitelist, "/home/user/projects/myapp/lib/app.ex")
    end

    test "rejects sibling paths" do
      whitelist = Whitelist.new(["/home/user/projects"])

      refute Whitelist.allowed?(whitelist, "/home/user/documents/secret.txt")
    end

    test "rejects paths that share prefix but aren't children" do
      whitelist = Whitelist.new(["/home/user/projects"])

      # /home/user/projects-backup is NOT a child of /home/user/projects
      refute Whitelist.allowed?(whitelist, "/home/user/projects-backup/file.txt")
    end
  end
end
