defmodule Astral.Route.FileTest do
  use ExUnit.Case, async: true

  alias Astral.Route.File

  test "converts static page filenames to route patterns" do
    assert File.static_path("index.md") == "/"
    assert File.static_path("about.html") == "/about/"
    assert File.static_path("blog/post.astral") == "/blog/post/"
    assert File.static_path("blog/index.md") == "/blog/"
  end

  test "converts bracket params to Elixir-style route params" do
    route = File.parse("blog/[slug].astral")

    assert route.dynamic?
    assert route.pattern.source == "/blog/:slug"
    assert route.params == ["slug"]
    assert File.match(route, "/blog/hello/") == {:ok, %{"slug" => "hello"}}
  end

  test "converts spread params to Elixir-style route globs" do
    route = File.parse("docs/[...path].md")

    assert route.dynamic?
    assert route.pattern.source == "/docs/*path"
    assert route.params == ["path"]

    assert File.match(route, "/docs/intro/getting-started/") ==
             {:ok, %{"path" => "intro/getting-started"}}
  end
end
