defmodule Astral.BuilderTest do
  use ExUnit.Case, async: false

  import JSONSpec

  defmodule RemoteImageServer do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    get "/hero.svg" do
      Plug.Conn.send_resp(conn, 200, Astral.BuilderTest.svg_image(120, 60, "purple"))
    end

    match _ do
      Plug.Conn.send_resp(conn, 404, "not found")
    end
  end

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

  test "builds Markdown pages with local Astral components" do
    write("components/pill.astral", ~S'''
    <span class="pill">
      {render_slot(@inner_block)}
    </span>
    ''')

    write("pages/index.md", ~S'''
    ---
    title: Component Markdown
    ---

    # Component Markdown

    <p>{@metadata["title"]}</p>

    <.pill>Elixir</.pill>
    ''')

    write("layouts/default.html", "<main><%= @content %></main>")

    assert {:ok, result} = Astral.build(root: tmp())

    assert Enum.map(result.site.pages, & &1.route_path) == ["/"]

    assert read("dist/index.html") =~
             ~s(<h1><a href="#component-markdown" aria-hidden="true" class="anchor" id="component-markdown"></a>Component Markdown</h1>)

    assert read("dist/index.html") =~ "<p>Component Markdown</p>"
    assert read("dist/index.html") =~ ~s(<span class="pill">)
    assert read("dist/index.html") =~ "Elixir"
  end

  test "builds optimized images from Astral pages" do
    write("assets/images/hero.svg", svg_image(120, 60, "red"))

    write("pages/index.astral", ~S'''
    <.image src="images/hero.svg" alt="Hero" width={60} format={:webp} quality={80} class="hero" />
    ''')

    assert {:ok, _result} = Astral.build(root: tmp(), layout: false)

    html = read("dist/index.html")
    assert html =~ ~s(alt="Hero")
    assert html =~ ~s(width="60")
    assert html =~ ~s(height="30")
    assert html =~ ~s(class="hero")
    assert html =~ ~r/src="\/assets\/hero-60x30-[^"]+\.webp"/

    [image] = Path.wildcard(Path.join(tmp(), "dist/assets/hero-60x30-*.webp"))
    assert File.stat!(image).size > 0
  end

  test "builds client-only Vue island entries with Volt" do
    write("assets/islands/Gallery.vue", ~S'''
    <template><button>{{ label }}</button></template>
    <script setup>
    defineProps({ label: String })
    </script>
    ''')

    write("pages/index.astral", ~S'''
    <.island component="islands/Gallery.vue" adapter={:vue} client={:load} props={%{label: "Open"}} class="gallery-shell" />
    ''')

    assert {:ok, _result} =
             Astral.build(
               root: tmp(),
               layout: false,
               islands: [adapter: :vue],
               asset_hash: false
             )

    html = read("dist/index.html")
    assert html =~ ~s(data-astral-island="vue")
    assert html =~ ~s(data-astral-client="load")
    assert html =~ ~s(class="gallery-shell")
    assert html =~ ~r/<script type="module" src="\/assets\/astral-island-[^"]+\.js"><\/script>/

    [entry] = Path.wildcard(Path.join(tmp(), "dist/assets/astral-island-*.js"))
    code = File.read!(entry)
    assert code =~ "createApp"
    assert code =~ "Open"
  end

  test "builds semantic figures from Astral pages" do
    write("assets/images/figure.svg", svg_image(160, 80, "orange"))

    write("pages/index.astral", ~S'''
    <.figure src="images/figure.svg" alt="Figure" width={80} caption="A useful figure" class="media" image_attrs={%{class: "media-image"}} />
    ''')

    assert {:ok, _result} = Astral.build(root: tmp(), layout: false)

    html = read("dist/index.html")
    assert html =~ ~s(<figure class="media">)
    assert html =~ ~s(class="media-image")
    assert html =~ ~s(alt="Figure")
    assert html =~ ~s(width="80")
    assert html =~ ~s(height="40")
    assert html =~ ~s(<figcaption>)
    assert html =~ "A useful figure"
    assert html =~ ~r/src="\/assets\/figure-80x40-[^"]+\.webp"/
  end

  test "exposes image metadata helpers in Astral pages" do
    write("assets/images/meta.svg", svg_image(90, 45, "black"))

    write("pages/index.astral", ~S'''
    ---
    assigns = assign(assigns, :meta, Astral.Image.metadata("images/meta.svg"))
    ---
    <p>{@meta.width} × {@meta.height} {@meta.format}</p>
    ''')

    assert {:ok, _result} = Astral.build(root: tmp(), layout: false)

    assert read("dist/index.html") =~ "90 × 45 svg"
  end

  test "infers remote image dimensions during static builds" do
    port = unused_port()
    {:ok, server} = Bandit.start_link(plug: RemoteImageServer, port: port)
    on_exit(fn -> Process.exit(server, :normal) end)

    write("pages/index.astral", ~s'''
    <.image src="http://127.0.0.1:#{port}/hero.svg" alt="Remote hero" width={60} format={:webp} />
    ''')

    assert {:ok, _result} =
             Astral.build(
               root: tmp(),
               layout: false,
               image: [allow_remote: ["http://127.0.0.1:#{port}/**"]]
             )

    html = read("dist/index.html")
    assert html =~ ~s(alt="Remote hero")
    assert html =~ ~s(width="60")
    assert html =~ ~s(height="30")
    assert html =~ ~r/src="\/assets\/[^"]+-60x30-[^"]+\.webp"/
    assert [_] = Path.wildcard(Path.join(tmp(), "dist/assets/*-60x30-*.webp"))
  end

  test "builds optimized images from Markdown image syntax" do
    write("pages/index.md", ~S'''
    # Home

    ![Hero](./hero.svg "Hero title")
    ''')

    write("pages/hero.svg", svg_image(80, 40, "green"))

    assert {:ok, _result} = Astral.build(root: tmp(), layout: false)

    html = read("dist/index.html")
    assert html =~ ~s(alt="Hero")
    assert html =~ ~s(title="Hero title")
    assert html =~ ~s(width="80")
    assert html =~ ~s(height="40")
    assert html =~ ~r/src="\/assets\/hero-80x40-[^"]+\.webp"/
    assert [_] = Path.wildcard(Path.join(tmp(), "dist/assets/hero-80x40-*.webp"))
  end

  test "builds responsive picture variants from Astral pages" do
    write("assets/images/card.svg", svg_image(200, 100, "blue"))

    write("pages/index.astral", ~S'''
    <.picture
      src="images/card.svg"
      alt="Card"
      widths={[50, 100]}
      formats={[:webp]}
      fallback_format={:png}
      sizes="100vw"
    />
    ''')

    assert {:ok, _result} = Astral.build(root: tmp(), layout: false)

    html = read("dist/index.html")
    assert html =~ ~s(<picture>)
    assert html =~ ~s(type="image/webp")
    assert html =~ ~s(sizes="100vw")

    assert html =~
             ~r/srcset="\/assets\/card-50x25-[^"]+\.webp 50w, \/assets\/card-100x50-[^"]+\.webp 100w"/

    assert html =~ ~r/src="\/assets\/card-100x50-[^"]+\.png"/

    assert [_] = Path.wildcard(Path.join(tmp(), "dist/assets/card-50x25-*.webp"))
    assert [_] = Path.wildcard(Path.join(tmp(), "dist/assets/card-100x50-*.webp"))
    assert [_] = Path.wildcard(Path.join(tmp(), "dist/assets/card-100x50-*.png"))
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

  test "builds Volt assets extracted from Astral templates" do
    write("pages/index.astral", ~S'''
    <h1>Assets</h1>
    <style>.asset-card { color: red }</style>
    <script lang="ts">const answer: number = 42; console.log(answer)</script>
    ''')

    assert {:ok, result} = Astral.build(root: tmp(), layout: false, asset_hash: false)

    assert result.assets != nil
    assert read("dist/index.html") =~ "<h1>Assets</h1>"
    refute read("dist/index.html") =~ "asset-card"
    refute read("dist/index.html") =~ "console.log"

    manifest = tmp() |> Path.join("dist/assets/manifest.json") |> File.read!() |> :json.decode()
    assert Map.has_key?(manifest, "index.js")
    assert Map.has_key?(manifest, "index.css")
    assert File.read!(Path.join(tmp(), "dist/assets/index.js")) =~ "console.log(42)"
    assert File.read!(Path.join(tmp(), "dist/assets/index.css")) =~ "color:red"
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

  test "renders collection entries with dynamic Astral file routes" do
    write("pages/blog/[slug].astral", ~S'''
    <article data-slug={@params["slug"]}>
      <h1>{@entry.data.title}</h1>
      <div>{@entry.slug}</div>
    </article>
    ''')

    write("content/posts/hello.md", """
    ---
    title: Hello Dynamic
    ---

    # Entry Body
    """)

    config =
      Astral.Config.new(
        root: tmp(),
        layout: false,
        collections: [
          [
            name: :posts,
            dir: "content/posts",
            permalink: "/blog/:slug/",
            schema: schema(%{required(:title) => String.t()})
          ]
        ]
      )

    assert {:ok, result} = Astral.build(config)

    assert [%Astral.Page{route_path: "/blog/hello/", params: %{"slug" => "hello"}}] =
             result.site.pages

    assert read("dist/blog/hello/index.html") =~ ~s(<article data-slug="hello">)
    assert read("dist/blog/hello/index.html") =~ "<h1>Hello Dynamic</h1>"
    refute read("dist/blog/hello/index.html") =~ "Entry Body"
  end

  test "renders glob dynamic Markdown routes with params in layouts" do
    write("pages/docs/[...path].md", "# Dynamic Doc")
    write("layouts/doc.html", ~S(<%= @params["path"] %>:<%= @entry.data.title %>:<%= @content %>))

    write("content/docs/guide/intro.md", """
    ---
    title: Intro Guide
    ---

    # Entry Body
    """)

    config =
      Astral.Config.new(
        root: tmp(),
        layout: "doc.html",
        collections: [
          [
            name: :docs,
            dir: "content/docs",
            permalink: "/docs/:slug/",
            schema: schema(%{required(:title) => String.t()})
          ]
        ]
      )

    assert {:ok, result} = Astral.build(config)

    assert [%Astral.Page{route_path: "/docs/guide/intro/", params: %{"path" => "guide/intro"}}] =
             result.site.pages

    assert read("dist/docs/guide/intro/index.html") ==
             "guide/intro:Intro Guide:#{heading("Dynamic Doc", "dynamic-doc")}"
  end

  test "returns an error when a dynamic file route matches no collection entries" do
    write("pages/blog/[slug].astral", "<h1>{@params[\"slug\"]}</h1>")

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
            permalink: "/posts/:slug/",
            schema: schema(%{required(:title) => String.t()})
          ]
        ]
      )

    assert {:error, {:unmatched_dynamic_route, path, "/blog/:slug"}} = Astral.build(config)
    assert path == Path.join(tmp(), "pages/blog/[slug].astral")
  end

  test "returns an error for duplicate page routes" do
    write("pages/about.md", "# About")
    write("pages/about.html", "<h1>About</h1>")

    assert {:error, {:duplicate_page_route, "/about/", sources}} = Astral.build(root: tmp())

    assert sources == [
             Path.join(tmp(), "pages/about.html"),
             Path.join(tmp(), "pages/about.md")
           ]
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

  test "renders Ecto-style image fields from collection frontmatter" do
    write("content/posts/cover.svg", svg_image(120, 60, "purple"))

    write("content/posts/hello.md", ~S'''
    ---
    title: Image Field
    cover: ./cover.svg
    ---

    # Hello
    ''')

    write("pages/blog/[slug].astral", ~S'''
    <article>
      <h1>{@entry.data.title}</h1>
      <.image src={@entry.data.cover} alt={@entry.data.title} width={60} />
    </article>
    ''')

    config =
      Astral.Config.new(
        root: tmp(),
        layout: false,
        collections: [
          [
            name: :posts,
            dir: "content/posts",
            permalink: "/blog/:slug/",
            schema: %Astral.Schema.Fields{
              fields: [
                %Astral.Schema.Field{name: :title, type: :string, required?: true},
                %Astral.Schema.Field{name: :cover, type: :image, required?: true}
              ]
            }
          ]
        ]
      )

    assert {:ok, result} = Astral.build(config)

    assert [%{data: %{cover: %Astral.Image.Source{} = cover}}] = result.site.entries.posts
    assert cover.src == "./cover.svg"
    assert cover.width == 120
    assert cover.height == 60
    assert cover.format == :svg

    html = read("dist/blog/hello/index.html")
    assert html =~ ~s(<h1>Image Field</h1>)
    assert html =~ ~s(alt="Image Field")
    assert html =~ ~s(width="60")
    assert html =~ ~s(height="30")
    assert html =~ ~r/src="\/assets\/cover-60x30-[^"]+\.webp"/
    assert [_] = Path.wildcard(Path.join(tmp(), "dist/assets/cover-60x30-*.webp"))
  end

  test "renders collection Markdown entries with local Astral components" do
    write("components/callout.astral", ~S'''
    <aside class="callout">
      {render_slot(@inner_block)}
    </aside>
    ''')

    write("pages/index.html", "<h1>Home</h1>")

    write("content/posts/hello.md", ~S'''
    ---
    title: Hello Components
    ---

    # {@entry.data.title}

    <.callout>Rendered from Markdown.</.callout>
    ''')

    config =
      Astral.Config.new(
        root: tmp(),
        layout: false,
        collections: [
          [
            name: :posts,
            dir: "content/posts",
            permalink: "/blog/:slug/",
            schema: schema(%{required(:title) => String.t()})
          ]
        ]
      )

    assert {:ok, _result} = Astral.build(config)

    assert read("dist/blog/hello/index.html") =~ "Hello Components"
    assert read("dist/blog/hello/index.html") =~ ~s(<aside class="callout">)
    assert read("dist/blog/hello/index.html") =~ "Rendered from Markdown."
  end

  test "discovers Ecto-style field schema collection entries" do
    write("pages/index.html", "<h1>Home</h1>")

    write("content/posts/hello.md", """
    ---
    title: Hello Fields
    date: 2026-06-26
    ---

    # Hello
    """)

    config_path = Path.join(tmp(), "astral.config.exs")

    File.write!(config_path, """
    import Astral.Config

    site do
      root #{inspect(tmp())}

      collections do
        collection :posts, "content/posts" do
          schema do
            field :title, :string, required: true
            field :date, :date, required: true
            field :draft, :boolean, default: false
            field :tags, {:array, :string}, default: []
          end
        end
      end
    end
    """)

    assert {:ok, result} = Astral.build(config: config_path)

    assert [%{data: data}] = result.site.entries.posts
    assert data == %{title: "Hello Fields", date: ~D[2026-06-26], draft: false, tags: []}
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

  defp unused_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end

  def svg_image(width, height, color) do
    ~s(<svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}"><rect width="#{width}" height="#{height}" fill="#{color}"/></svg>)
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
