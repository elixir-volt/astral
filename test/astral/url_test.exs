defmodule Astral.URLTest do
  use ExUnit.Case, async: true

  alias Astral.URL

  test "normalizes base paths with leading and trailing slashes" do
    assert URL.normalize_base_path!("/") == "/"
    assert URL.normalize_base_path!("") == "/"
    assert URL.normalize_base_path!("docs") == "/docs/"
    assert URL.normalize_base_path!("/docs") == "/docs/"
    assert URL.normalize_base_path!("/docs/") == "/docs/"
    assert URL.normalize_base_path!("/docs//v1") == "/docs/v1/"
  end

  test "rejects base paths that are not plain URL paths" do
    for invalid <- [
          "https://example.com/docs/",
          "//cdn.example.com/",
          "/docs/?q=1",
          "/docs/#top",
          "/docs/../"
        ] do
      assert_raise ArgumentError, fn -> URL.normalize_base_path!(invalid) end
    end

    assert_raise ArgumentError, fn -> URL.normalize_base_path!(:docs) end
  end

  test "prefixes root-relative paths with the base path" do
    config = Astral.Config.new(root: "/tmp/site", base_path: "/docs/")

    assert URL.path(config, "/") == "/docs/"
    assert URL.path(config, "/about/") == "/docs/about/"
    assert Astral.url(%Astral.Site{config: config}, "/feed.xml") == "/docs/feed.xml"
  end

  test "leaves absolute, protocol-relative, fragment and relative URLs unchanged" do
    config = Astral.Config.new(root: "/tmp/site", base_path: "/docs/")

    for url <- [
          "https://example.com/",
          "//cdn.example.com/app.js",
          "#top",
          "mailto:a@b.c",
          "next/"
        ] do
      assert URL.path(config, url) == url
    end
  end

  test "keeps root-relative paths unchanged without a base path" do
    config = Astral.Config.new(root: "/tmp/site")

    assert URL.path(config, "/about/") == "/about/"
  end

  test "builds absolute URLs from site_url and base_path" do
    config =
      Astral.Config.new(root: "/tmp/site", site_url: "https://example.com/", base_path: "/docs")

    assert URL.absolute(config, "/about/") == "https://example.com/docs/about/"
    assert Astral.absolute_url(config, "https://other.example/") == "https://other.example/"

    assert URL.absolute("https://example.com", "/", "//cdn.example.com/x") ==
             "//cdn.example.com/x"

    assert_raise ArgumentError, ~r/without site_url/, fn ->
      URL.absolute(Astral.Config.new(root: "/tmp/site"), "/about/")
    end
  end

  test "strips the base path from request paths" do
    assert URL.strip("/", "/about/") == {:ok, "/about/"}
    assert URL.strip("/docs/", "/docs/about/") == {:ok, "/about/"}
    assert URL.strip("/docs/", "/docs/") == {:ok, "/"}
    assert URL.strip("/docs/", "/docs") == {:ok, "/"}
    assert URL.strip("/docs/", "/docsearch/") == :error
    assert URL.strip("/docs/", "/about/") == :error
  end

  test "validates site URLs" do
    assert URL.validate_site_url!(nil) == nil
    assert URL.validate_site_url!("https://example.com") == "https://example.com"

    for invalid <- ["example.com", "/docs/", "ftp://example.com", 42] do
      assert_raise ArgumentError, fn -> URL.validate_site_url!(invalid) end
    end
  end
end
