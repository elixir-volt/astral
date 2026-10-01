defmodule AstralTest do
  use ExUnit.Case, async: true

  doctest Astral

  test "returns the package version" do
    assert Astral.version() == "0.5.0"
  end
end
