defmodule Astral.Route.PathTest do
  use ExUnit.Case, async: true

  alias Astral.Route.Path

  test "normalizes route params once into the path contract" do
    assert Path.new(tag: "elixir") == %Path{params: %{tag: "elixir"}, assigns: %{}}
  end

  test "accepts page assigns through the setup helper" do
    assert Path.path(tag: "elixir", assigns: %{posts: [:one]}) == %Path{
             params: %{tag: "elixir"},
             assigns: %{posts: [:one]}
           }
  end

  test "rejects non-atom assign keys" do
    assert_raise ArgumentError, ~r/assign names must be atoms/, fn ->
      Path.new([tag: "elixir"], %{"posts" => []})
    end
  end
end
