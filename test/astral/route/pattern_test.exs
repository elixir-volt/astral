defmodule Astral.Route.PatternTest do
  use ExUnit.Case, async: true

  alias Astral.Route.Pattern

  test "generates static and param routes" do
    assert Pattern.generate("/blog/:slug", slug: "hello") == "/blog/hello"

    assert Pattern.generate("/docs/:section/:slug", %{section: :guides, slug: "intro"}) ==
             "/docs/guides/intro"
  end

  test "generates optional glob routes" do
    assert Pattern.generate("/blog/*page", page: nil) == "/blog"
    assert Pattern.generate("/blog/*page", page: "2") == "/blog/2"
    assert Pattern.generate("/docs/*path", path: ["guides", "intro"]) == "/docs/guides/intro"
  end

  test "matches static, param, and glob routes" do
    assert Pattern.match("/blog/:slug", "/blog/hello") == {:ok, %{"slug" => "hello"}}
    assert Pattern.match("/blog/:slug", "/blog") == :error
    assert Pattern.match("/blog/*page", "/blog") == {:ok, %{"page" => nil}}
    assert Pattern.match("/blog/*page", "/blog/2") == {:ok, %{"page" => "2"}}

    assert Pattern.match("/docs/*path", "/docs/guides/intro") ==
             {:ok, %{"path" => "guides/intro"}}
  end

  test "normalizes leading and trailing slashes" do
    pattern = Pattern.parse("blog/:slug/")

    assert pattern.source == "/blog/:slug"
    assert Pattern.generate(pattern, slug: "hello") == "/blog/hello"
    assert Pattern.match(pattern, "/blog/hello/") == {:ok, %{"slug" => "hello"}}
  end

  test "raises for missing params and invalid patterns" do
    assert_raise ArgumentError, ~r/missing route parameter/, fn ->
      Pattern.generate("/blog/:slug", %{})
    end

    assert_raise ArgumentError, ~r/glob must be the last segment/, fn ->
      Pattern.parse("/docs/*path/edit")
    end

    assert_raise ArgumentError, ~r/invalid route parameter/, fn ->
      Pattern.parse("/blog/:bad-name")
    end
  end
end
