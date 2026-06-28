defmodule AstralTest do
  use ExUnit.Case, async: true

  doctest Astral

  test "returns the package version" do
    assert Astral.version() == "0.1.4"
  end
end
