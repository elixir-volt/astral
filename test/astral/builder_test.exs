defmodule Astral.BuilderTest do
  use ExUnit.Case, async: false

  import JSONSpec

  defmodule RenderPlugin do
    @behaviour Astral.Plugin

    @impl true
    def name, do: "render-test"

    @impl true
    def render_page(html, page, _site, opts) do
      {:ok, html <> "<!-- #{page.route_path}:#{Keyword.fetch!(opts, :suffix)} -->"}
    end
  end

  defmodule SitePlugin do
    @behaviour Astral.Plugin

    @impl true
    def name, do: "site-test"

    @impl true
    def site_discovered(site) do
      %{site | pages: Enum.map(site.pages, &%{&1 | route_path: "/plugin" <> &1.route_path})}
    end
  end

  defmodule ConfigPlugin do
    @behaviour Astral.Plugin

    @impl true
    def name, do: "config-test"

    @impl true
    def config(config, opts) do
      %{config | layout: Keyword.fetch!(opts, :layout)}
    end
  end

  defmodule FeedPlugin do
    @behaviour Astral.Plugin

    @impl true
    def name, do: "feed-test"

    @impl true
    def routes(site) do
      [Astral.Route.new("/feed.xml", site.config, content_type: "application/atom+xml")]
    end

    @impl true
    def render_route(%Astral.Route{path: "/feed.xml"}, site) do
      titles = Enum.map_join(site.entries.posts, ",", & &1.data.title)
      {:ok, "<feed>#{titles}</feed>"}
    end

    def render_route(_route, _site), do: nil
  end

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    Process.put(:astral_test_tmp, tmp_dir)
    :ok
  end

  test "builds HTML pages with optional layout" do
    write("pages/index.html", "<h1>Home</h1>")
    write("pages/about.html", "<h1>About</h1>")
    write("pages/blog/post.html", "<h1>Post</h1>")
    write("layouts/default.html", "<html><body><%= @content %></body></html>")

    assert {:ok, result} = Astral.build(root: tmp())

    assert Enum.map(result.site.pages, & &1.route_path) == ["/about/", "/blog/post/", "/"]
    assert read("dist/index.html") == "<html><body><h1>Home</h1></body></html>"
    assert read("dist/about/index.html") == "<html><body><h1>About</h1></body></html>"
    assert read("dist/blog/post/index.html") == "<html><body><h1>Post</h1></body></html>"
  end

  test "builds Markdown pages through MDEx" do
    write("pages/index.md", "# Home")
    write("pages/about.md", "# About")
    write("layouts/default.html", "<main><%= @content %></main>")

    assert {:ok, result} = Astral.build(root: tmp())

    assert Enum.map(result.site.pages, & &1.route_path) == ["/about/", "/"]
    assert read("dist/index.html") == "<main>#{heading("Home", "home")}</main>"
    assert read("dist/about/index.html") == "<main>#{heading("About", "about")}</main>"
  end

  test "builds HEEx-first Astral pages with local components" do
    write("components/pill.astral", ~S'''
    <div class="pill">
      {render_slot(@inner_block)}
    </div>
    ''')

    write("pages/index.astral", ~S'''
    ---
    assigns = assign(assigns, :title, "Home")
    ---
    <h1>{@title}</h1>
    <.pill>Elixir</.pill>
    ''')

    write("layouts/default.astral", ~S'''
    <main data-route={@route}>
      {@content}
    </main>
    ''')

    assert {:ok, result} = Astral.build(root: tmp(), layout: "default.astral")

    assert Enum.map(result.site.pages, & &1.route_path) == ["/"]
    assert read("dist/index.html") =~ ~s(<main data-route="/">)
    assert read("dist/index.html") =~ "<h1>Home</h1>"
    assert read("dist/index.html") =~ ~s(<div class="pill">)
    assert read("dist/index.html") =~ "Elixir"
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

    assert {:ok, result} = Astral.build(root: tmp())

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

    assert {:ok, _result} = Astral.build(root: tmp())

    assert read("dist/index.html") == "<page>Home:#{heading("Home", "home")}</page>"
  end

  test "supports disabling layout from page frontmatter" do
    write("pages/index.md", """
    ---
    layout: false
    ---
    # Home
    """)

    write("layouts/default.html", "<default><%= @content %></default>")

    assert {:ok, _result} = Astral.build(root: tmp())

    assert read("dist/index.html") == heading("Home", "home")
  end

  test "returns an error for missing frontmatter layout" do
    write("pages/index.md", """
    ---
    layout: missing.html
    ---
    # Home
    """)

    assert {:error, {:missing_layout, path, "missing.html"}} = Astral.build(root: tmp())
    assert path == Path.join(tmp(), "pages/index.md")
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

    assert {:ok, _result} = Astral.build(root: tmp())

    assert read("dist/index.html") == """
           <title>Home Page</title>
           <meta name="description" content="Welcome">
           <main data-route="/" data-assets="/assets">#{heading("Home", "home")}</main>
           """
  end

  test "copies public files into the output directory" do
    write("pages/index.html", "<h1>Home</h1>")
    write("public/robots.txt", "User-agent: *")

    assert {:ok, _result} = Astral.build(root: tmp())

    assert read("dist/robots.txt") == "User-agent: *"
  end

  test "builds from an astral config file" do
    write("site_pages/index.html", "<h1>Home</h1>")

    config_path = Path.join(tmp(), "astral.config.exs")

    File.write!(config_path, """
    import Astral.Config

    site do
      root #{inspect(tmp())}
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

    assert {:ok, result} = Astral.build(root: tmp())

    assert result.assets != nil
    assert File.regular?(Path.join(tmp(), "dist/assets/manifest.json"))
  end

  test "runs plugin hooks during static builds" do
    write("pages/index.html", "<h1>Home</h1>")
    write("layouts/plugin.html", "<main><%= @content %></main>")

    assert {:ok, result} =
             Astral.build(
               root: tmp(),
               plugins: [
                 {ConfigPlugin, layout: "plugin.html"},
                 SitePlugin,
                 {RenderPlugin, suffix: "done"}
               ]
             )

    assert [%{route_path: "/plugin/"}] = result.site.pages

    assert read("dist/index.html") == "<main><h1>Home</h1></main><!-- /plugin/:done -->"
  end

  test "discovers and renders JSONSpec-backed collection entries" do
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
        root: tmp(),
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
    assert read("dist/blog/hello/index.html") == ~s(["Hello"])
  end

  test "renders plugin generated routes" do
    write("pages/index.html", "<h1>Home</h1>")

    write("content/posts/hello.md", """
    ---
    title: Hello
    ---

    # Hello
    """)

    config =
      Astral.Config.new(
        root: tmp(),
        plugins: [FeedPlugin],
        collections: [
          [
            name: :posts,
            dir: "content/posts",
            schema: schema(%{required(:title) => String.t()})
          ]
        ]
      )

    assert {:ok, result} = Astral.build(config)

    assert [%Astral.Route{path: "/feed.xml", content_type: "application/atom+xml"}] =
             result.site.routes

    assert read("dist/feed.xml") == "<feed>Hello</feed>"
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
        root: tmp(),
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
        root: tmp(),
        collections: [
          [name: :posts, dir: "content/posts", schema: schema(%{required(:title) => String.t()})]
        ]
      )

    assert {:error, {:invalid_metadata, _error}} = Astral.build(config)
  end

  test "returns an error when pages directory is missing" do
    assert {:error, {:missing_pages_dir, path}} = Astral.build(root: tmp())
    assert path == Path.join(tmp(), "pages")
  end

  defp heading(text, id) do
    ~s(<h1><a href="##{id}" aria-hidden="true" class="anchor" id="#{id}"></a>#{text}</h1>)
  end

  defp tmp, do: Process.get(:astral_test_tmp) || raise("missing tmp_dir")

  defp write(path, content) do
    path = Path.join(tmp(), path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end

  defp read(path) do
    tmp()
    |> Path.join(path)
    |> File.read!()
  end
end
