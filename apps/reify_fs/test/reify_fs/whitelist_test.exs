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
