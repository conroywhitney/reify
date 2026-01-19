defmodule TrumanFs.WhitelistTest do
  use ExUnit.Case, async: true

  alias TrumanFs.Whitelist

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

  describe "add_all/2" do
    test "adds multiple paths at once" do
      whitelist = Whitelist.new([])
      whitelist = Whitelist.add_all(whitelist, ["/a", "/b", "/c"])

      assert Whitelist.allowed?(whitelist, "/a")
      assert Whitelist.allowed?(whitelist, "/b")
      assert Whitelist.allowed?(whitelist, "/c")
    end
  end

  describe "remove_all/2" do
    test "removes multiple paths at once" do
      whitelist = Whitelist.new(["/a", "/b", "/c"])
      whitelist = Whitelist.remove_all(whitelist, ["/a", "/b"])

      refute Whitelist.allowed?(whitelist, "/a")
      refute Whitelist.allowed?(whitelist, "/b")
      assert Whitelist.allowed?(whitelist, "/c")
    end
  end

  describe "list/1" do
    test "returns all whitelisted paths" do
      whitelist = Whitelist.new(["/home/user/projects", "/tmp"])

      paths = Whitelist.list(whitelist)

      assert Enum.sort(paths) == ["/home/user/projects", "/tmp"]
    end

    test "returns empty list for empty whitelist" do
      whitelist = Whitelist.new([])

      assert Whitelist.list(whitelist) == []
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
