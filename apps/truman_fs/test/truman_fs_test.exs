defmodule TrumanFsTest do
  use ExUnit.Case
  doctest TrumanFs

  test "greets the world" do
    assert TrumanFs.hello() == :world
  end
end
