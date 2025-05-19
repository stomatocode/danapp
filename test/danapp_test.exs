defmodule DanappTest do
  use ExUnit.Case
  doctest Danapp

  test "greets the world" do
    assert Danapp.hello() == :world
  end
end
