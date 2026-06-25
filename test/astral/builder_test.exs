defmodule Astral.BuilderTest do
  use ExUnit.Case, async: false

  import JSONSpec

  @tmp Path.expand("../tmp/builder", __DIR__)

  setup do
    File.rm_rf!(@tmp)
    File.mkdir_p!(@tmp)

    on_exit(fn -> File.rm_rf!(@tmp) end)

    :ok
  end

  test "builds HTML pages with optional layout" do
    write("pages/index.html", "<h1>Home</h1>")
    write("pages/about.html", "<h1>About</h1>")
    write("pages/blog/post.html", "<h1>Post</h1>")
    write("layouts/default.html", "<html><body><%= @content %></body></html>")

    assert {:ok, result} = Astral.build(root: @tmp)

    assert Enum.map(result.site.pages, & &1.route_path) == ["/about/", "/blog/post/", "/"]
    assert read("dist/index.html") == "<html><body><h1>Home</h1></body></html>"
    assert read("dist/about/index.html") == "<html><body><h1>About</h1></body></html>"
    assert read("dist/blog/post/index.html") == "<html><body><h1>Post</h1></body></html>"
  end

  test "builds Markdown pages through MDEx" do
    write("pages/index.md", "# Home")
    write("pages/about.md", "# About")
    write("layouts/default.html", "<main><%= @content %></main>")

    assert {:ok, result} = Astral.build(root: @tmp)

    assert Enum.map(result.site.pages, & &1.route_path) == ["/about/", "/"]
    assert read("dist/index.html") == "<main><h1>Home</h1></main>"
    assert read("dist/about/index.html") == "<main><h1>About</h1></main>"
  end

  test "uses MDEx frontmatter metadata for Markdown pages" do
    write("pages/about.md", """
    ---
    title: About Astral
    permalink: /about-us/
    layout: page.html
    ---
    # About
    """)

    write("layouts/page.html", "<%= @content %>")

    assert {:ok, result} = Astral.build(root: @tmp)

    [page] = result.site.pages
    assert page.route_path == "/about-us/"
    assert page.content.title == "About Astral"
    assert page.content.layout == "page.html"
    assert page.content.metadata["title"] == "About Astral"
  end

  test "uses page frontmatter layout override" do
    write("pages/index.md", """
    ---
    title: Home
    layout: page.html
    ---
    # Home
    """)

    write("layouts/default.html", "<default><%= @content %></default>")
    write("layouts/page.html", "<page><%= @page.title %>:<%= @content %></page>")

    assert {:ok, _result} = Astral.build(root: @tmp)

    assert read("dist/index.html") == "<page>Home:<h1>Home</h1></page>"
  end

  test "supports disabling layout from page frontmatter" do
    write("pages/index.md", """
    ---
    layout: false
    ---
    # Home
    """)

    write("layouts/default.html", "<default><%= @content %></default>")

    assert {:ok, _result} = Astral.build(root: @tmp)

    assert read("dist/index.html") == "<h1>Home</h1>"
  end

  test "returns an error for missing frontmatter layout" do
    write("pages/index.md", """
    ---
    layout: missing.html
    ---
    # Home
    """)

    assert {:error, {:missing_layout, path, "missing.html"}} = Astral.build(root: @tmp)
    assert path == Path.join(@tmp, "pages/index.md")
  end

  test "renders layout assigns from page metadata" do
    write("pages/index.md", """
    ---
    title: Home Page
    description: Welcome
    ---
    # Home
    """)

    write("layouts/default.html", """
    <title><%= @page.title %></title>
    <meta name="description" content="<%= @metadata["description"] %>">
    <main data-route="<%= @route %>" data-assets="<%= @site.config.asset_url_prefix %>"><%= @content %></main>
    """)

    assert {:ok, _result} = Astral.build(root: @tmp)

    assert read("dist/index.html") == """
           <title>Home Page</title>
           <meta name="description" content="Welcome">
           <main data-route="/" data-assets="/assets"><h1>Home</h1></main>
           """
  end

  test "copies public files into the output directory" do
    write("pages/index.html", "<h1>Home</h1>")
    write("public/robots.txt", "User-agent: *")

    assert {:ok, _result} = Astral.build(root: @tmp)

    assert read("dist/robots.txt") == "User-agent: *"
  end

  test "builds from an astral config file" do
    write("site_pages/index.html", "<h1>Home</h1>")

    config_path = Path.join(@tmp, "astral.config.exs")

    File.write!(config_path, """
    import Astral.Config

    site do
      root #{inspect(@tmp)}
      pages "site_pages"
      outdir "site_dist"
    end
    """)

    assert {:ok, _result} = Astral.build(config: config_path)

    assert read("site_dist/index.html") == "<h1>Home</h1>"
  end

  test "builds Volt assets when an asset entry exists" do
    write("pages/index.html", "<h1>Home</h1>")
    write("assets/app.js", "console.log('astral')")

    assert {:ok, result} = Astral.build(root: @tmp)

    assert result.assets != nil
    assert File.regular?(Path.join(@tmp, "dist/assets/manifest.json"))
  end

  test "discovers JSONSpec-backed collection entries" do
    write("pages/index.html", "")

    write(
      "layouts/default.html",
      "<%= inspect(@collections.posts |> Enum.map(& &1.data.title)) %>"
    )

    write("content/posts/hello.md", """
    ---
    title: Hello
    tags:
      - elixir
    ---

    # Hello
    """)

    config =
      Astral.Config.new(
        root: @tmp,
        collections: [
          [
            name: :posts,
            dir: "content/posts",
            permalink: "/blog/:slug/",
            schema:
              schema(%{
                required(:title) => String.t(),
                optional(:tags) => [String.t()]
              })
          ]
        ]
      )

    assert {:ok, result} = Astral.build(config)

    assert [%Astral.Entry{} = entry] = result.site.entries.posts
    assert entry.slug == "hello"
    assert entry.route_path == "/blog/hello/"
    assert entry.data == %{title: "Hello", tags: ["elixir"]}
    assert read("dist/index.html") == ~s(["Hello"])
  end

  test "discovers Zoi-backed collection entries" do
    write("pages/index.html", "<h1>Home</h1>")

    write("content/posts/hello.md", """
    ---
    title: Hello
    ---

    # Hello
    """)

    config =
      Astral.Config.new(
        root: @tmp,
        collections: [
          [
            name: :posts,
            dir: "content/posts",
            schema: Zoi.map(%{title: Zoi.string()}, coerce: true)
          ]
        ]
      )

    assert {:ok, result} = Astral.build(config)
    assert [%{data: %{title: "Hello"}}] = result.site.entries.posts
  end

  test "returns collection validation errors" do
    write("pages/index.html", "<h1>Home</h1>")
    write("content/posts/hello.md", "# Hello")

    config =
      Astral.Config.new(
        root: @tmp,
        collections: [
          [name: :posts, dir: "content/posts", schema: schema(%{required(:title) => String.t()})]
        ]
      )

    assert {:error, {:invalid_metadata, _error}} = Astral.build(config)
  end

  test "returns an error when pages directory is missing" do
    assert {:error, {:missing_pages_dir, path}} = Astral.build(root: @tmp)
    assert path == Path.join(@tmp, "pages")
  end

  defp write(path, content) do
    path = Path.join(@tmp, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end

  defp read(path) do
    @tmp
    |> Path.join(path)
    |> File.read!()
  end
end
