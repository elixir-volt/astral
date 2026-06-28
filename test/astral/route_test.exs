defmodule Astral.RouteTest do
  use ExUnit.Case, async: true

  alias Astral.Route

  test "resolves route output paths" do
    assert Route.output_relative("/") == "index.html"
    assert Route.output_relative("/about/") == "about/index.html"
    assert Route.output_relative("/robots.txt") == "robots.txt"
  end

  test "writes the root 404 page as a static-host error file" do
    assert Route.output_relative("/404") == "404.html"
    assert Route.output_relative("/404/") == "404.html"
  end
end
