# Astral ✨

[![Hex.pm](https://img.shields.io/hexpm/v/astral.svg)](https://hex.pm/packages/astral) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/astral)

Volt-powered static site generation for Elixir. Astral owns site semantics — pages, routes, Markdown, frontmatter, layouts, public files, and static HTML output — while [Volt](https://hex.pm/packages/volt) handles TypeScript, CSS, assets, dev-server integration, and HMR.

```bash
mix igniter.install astral
mix astral.dev
mix astral.build
```

Astral is intentionally separate from Volt. Volt remains the Vite-like frontend toolchain; Astral is the site framework built on top.

## Why Astral

Static site generators often force site configuration, content rules, and frontend tooling into JavaScript. Astral keeps the site layer in ordinary Elixir while reusing Volt's BEAM-native asset pipeline.

You get:

- Elixir `astral.config.exs` instead of JavaScript config objects.
- Markdown pages rendered with MDEx and YAML frontmatter.
- EEx layouts with `@content`, `@page`, `@metadata`, `@route`, and `@site` assigns.
- Per-page layout selection through frontmatter.
- Plain HTML pages for simple routes.
- Public static files copied as-is.
- TypeScript/CSS/assets built and served by Volt.
- A Plug/Bandit dev server with Volt HMR client injection and full reloads for pages/layouts/public files.
- Igniter-powered starter scaffolding.
- Volt-style Astral plugins for config, discovery, rendering, and build lifecycle hooks.

## Status

Astral is early, but the first release is useful for small static sites and documentation prototypes. Content collections, plugin-generated routes, feed/sitemap plugins, and collection pagination have landed on `master` after v0.1.0. See [`ROADMAP.md`](ROADMAP.md) for the planned path toward an Astro-class framework.

## Installation

Install into an existing Mix project with Igniter:

```bash
mix igniter.install astral
```

Or add the dependency manually:

```elixir
def deps do
  [
    {:astral, "~> 0.1.0"}
  ]
end
```

Then scaffold a starter site:

```bash
mix astral.new
```

The scaffold creates `astral.config.exs`, starter Markdown pages, an EEx layout, TypeScript/CSS assets, public files, `tsconfig.json`, and Volt JS/TS formatting/linting configuration.

## Project layout

```text
astral.config.exs
pages/
  index.md
  about.md
layouts/
  default.html
assets/
  app.ts
  styles.css
public/
  robots.txt
```

## Configuration

Astral config is real Elixir and returns an `%Astral.Config{}` struct. No global app env is required for site settings.

```elixir
# astral.config.exs
import Astral.Config

site do
  root "."
  outdir "dist"
  pages "pages"
  public "public"

  layouts "layouts" do
    default "default.html"
  end

  assets "assets" do
    entry "app.ts"
    url_prefix "/assets"
  end
end
```

## Content collections

Astral collections group Markdown entries such as posts, docs, changelog items, or authors. JSONSpec-style typespec maps are the preferred schema definition style, with Zoi also supported.

```elixir
import Astral.Config

site do
  collections do
    collection :posts, "content/posts" do
      permalink "/blog/:slug/"
      layout "post.html"

      schema %{
        required(:title) => String.t(),
        required(:date) => String.t(),
        optional(:draft) => boolean(),
        optional(:tags) => [String.t()]
      }
    end
  end
end
```

Zoi schemas can be used when runtime transformations or refinements are useful:

```elixir
collection :posts, "content/posts" do
  schema Zoi.map(%{title: Zoi.string(), tags: Zoi.array(Zoi.string()) |> Zoi.optional()}, coerce: true)
end
```

Collection entries are validated, exposed to layouts as `@collections`, and rendered as static pages at their collection permalink:

```eex
<%= for post <- @collections.posts do %>
  <a href={post.route_path}><%= post.data.title %></a>
<% end %>
```

`post.metadata` keeps the original string-keyed frontmatter. `post.data` contains schema-normalized data. Entry layouts also receive `@entry` for the current collection entry.

Markdown pages also expose headings for table-of-contents layouts. Astral renders stable heading anchors and stores heading metadata on `@page.headings`:

```eex
<nav>
  <%= for heading <- @page.headings do %>
    <a href="#<%= heading.id %>"><%= heading.text %></a>
  <% end %>
</nav>
```

Each heading is an `%Astral.Heading{level, id, text}`.

Collection helpers are available for layouts and plugins:

```elixir
posts =
  @site
  |> Astral.Collection.entries(:posts)
  |> Astral.Collection.published()
  |> Astral.Collection.sort_by_date(:desc)

tags = Astral.Collection.tags(posts)
```

## Collection pagination

Astral includes a small collection pagination plugin built from generic route and pagination primitives. It keeps tags/categories userland instead of inventing a taxonomy API.

```elixir
site do
  plugins [
    {Astral.Plugin.CollectionPages,
     collection: :posts,
     pattern: "/blog/*page",
     page_size: 10,
     layout: "blog.html"}
  ]
end
```

The `*page` route parameter omits page one, producing routes such as:

```text
/blog/
/blog/2/
/blog/3/
```

The pagination layout receives `@page`, `@collection`, `@site`, `@collections`, `@routes`, and `@route` assigns:

```eex
<h1>Blog</h1>

<%= for entry <- @page.entries do %>
  <article>
    <h2><a href="<%= entry.route_path %>"><%= entry.data.title %></a></h2>
  </article>
<% end %>

<nav>
  <%= if @page.urls.previous do %>
    <a href="<%= @page.urls.previous %>">Previous</a>
  <% end %>

  <%= if @page.urls.next do %>
    <a href="<%= @page.urls.next %>">Next</a>
  <% end %>
</nav>
```

For custom generated indexes, use the lower-level helpers directly:

```elixir
entries
|> Astral.Pagination.pages(pattern: "/blog/*page", page_size: 10)
|> Astral.Pagination.routes(site.config, assigns: %{collection: :posts})
```

### Userland tag pages

Astro treats tag pages as userland dynamic routes. Astral follows the same approach: use ordinary Elixir with the pagination primitives instead of a built-in taxonomy abstraction.

```elixir
defmodule MySite.TagPages do
  @behaviour Astral.Plugin

  def name, do: "tag-pages"

  def routes(site) do
    entries =
      site
      |> Astral.Collection.entries(:posts)
      |> Astral.Collection.published()
      |> Astral.Collection.sort_by_date(:desc)

    entries
    |> all_tags()
    |> Enum.flat_map(fn tag ->
      tagged_entries = Enum.filter(entries, &(tag in Map.get(&1.data, :tags, [])))

      tagged_entries
      |> Astral.Pagination.pages(
        pattern: "/tags/:tag/*page",
        params: %{tag: tag},
        page_size: 10
      )
      |> Astral.Pagination.routes(site.config,
        kind: :tag_pages,
        assigns: %{tag: tag, collection: :posts}
      )
    end)
  end

  def render_route(%Astral.Route{kind: :tag_pages} = route, site) do
    layout = Map.fetch!(site.layouts, "tag.html")
    Astral.Layout.render_route("", layout, route, site)
  end

  def render_route(_route, _site), do: nil

  defp all_tags(entries) do
    entries
    |> Enum.flat_map(&Map.get(&1.data, :tags, []))
    |> Enum.uniq()
    |> Enum.sort()
  end
end
```

A tag layout can use both `@tag` and the normal pagination assigns:

```eex
<h1>Posts tagged <%= @tag %></h1>

<%= for entry <- @page.entries do %>
  <a href="<%= entry.route_path %>"><%= entry.data.title %></a>
<% end %>
```

## Plugins

Astral plugins mirror Volt's plugin shape: implement `Astral.Plugin`, configure modules or `{module, opts}` tuples, and optionally return `:pre` or `:post` from `enforce/0` to control ordering.

```elixir
# astral.config.exs
import Astral.Config

site do
  plugins [
    MySite.SEOPlugin,
    {MySite.AnalyticsPlugin, id: "G-XXXX"}
  ]
end
```

```elixir
defmodule MySite.AnalyticsPlugin do
  @behaviour Astral.Plugin

  @impl true
  def name, do: "analytics"

  @impl true
  def render_page(html, _page, _site, opts) do
    id = Keyword.fetch!(opts, :id)
    {:ok, String.replace(html, "</body>", ~s(<script data-id="#{id}"></script></body>))}
  end
end
```

Available hooks include `config/1`, `build_start/1`, `site_discovered/1`, `routes/1`, `render_route/2`, `render_page/3`, and `build_done/1`. Tuple options are passed to callbacks that define one extra argument, such as `render_page/4`.

Astral includes plugin-shaped feed and sitemap generators:

```elixir
site do
  plugins [
    {Astral.Plugin.Feed,
     site_url: "https://example.com",
     title: "My Blog",
     author: "Astral",
     collection: :posts},
    {Astral.Plugin.Sitemap,
     site_url: "https://example.com",
     changefreq: :weekly,
     priority: fn page -> if page.route_path == "/", do: 1.0, else: 0.7 end}
  ]
end
```

Plugins can add generated routes for feeds, sitemaps, pagination, or tag pages:

```elixir
defmodule MySite.FeedPlugin do
  @behaviour Astral.Plugin

  @impl true
  def name, do: "feed"

  @impl true
  def routes(site) do
    [Astral.Route.new("/feed.xml", site.config, content_type: "application/atom+xml")]
  end

  @impl true
  def render_route(%Astral.Route{path: "/feed.xml"}, site) do
    {:ok, MySite.Feed.render(site.entries.posts)}
  end

  def render_route(_route, _site), do: nil
end
```

## XML DSL

Astral uses [XM](../xm) for feed and sitemap XML. XM is a small Saxy-backed XML DSL extracted from Astral so XML generation stays generic and reusable.

```elixir
import XM

document do
  urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
    for page <- pages do
      url do
        loc site_url <> page.route_path
        lastmod page.date
      end
    end
  end
end
```

XM supports attributes, nested elements, dynamic `tag "name"` nodes, loops, conditionals, comments, text nodes, CDATA, binary rendering, and iodata rendering while Saxy handles XML escaping and encoding.

## Pages and frontmatter

Markdown pages are rendered with MDEx. YAML frontmatter is extracted by MDEx and decoded with YamlElixir:

```markdown
---
title: About Astral
permalink: /about-us/
layout: default.html
---

# About
```

Output routes:

```text
pages/index.md        -> dist/index.html
pages/about.md        -> dist/about/index.html
pages/blog/post.html  -> dist/blog/post/index.html
```

`permalink` overrides the default route. `layout` selects a layout from the layouts directory. Use `layout: false` to render without a layout.

Plain `.html` files in `pages/` are supported too.

## Layouts

Layouts are EEx templates. Use `@content` where page HTML should be inserted:

```html
<!doctype html>
<html lang="en">
  <head>
    <title><%= @page.title || "Astral" %></title>
    <script type="module" src="<%= Astral.asset_path(@site, "app.ts") %>"></script>
  </head>
  <body>
    <main data-route="<%= @route %>">
      <%= @content %>
    </main>
  </body>
</html>
```

Available assigns:

- `@content` — rendered page HTML.
- `@page` — `%Astral.Content{}` for the current page.
- `@metadata` — decoded frontmatter map.
- `@route` — route path such as `/about/`.
- `@site` — discovered `%Astral.Site{}`.
- `@collections` — collection entries grouped by collection name.
- `@entry` — current `%Astral.Entry{}` for collection entry pages, otherwise `nil`.
- `@routes` — generated `%Astral.Route{}` values.

## Assets

Astral delegates assets to Volt. Reference source assets from layouts with `Astral.asset_path/2`:

```eex
<script type="module" src="<%= Astral.asset_path(@site, "app.ts") %>"></script>
```

In development this returns the source path served by Volt, for example `/assets/app.ts`. In static builds it reads Volt's manifest and returns the emitted file, for example `/assets/app-5e6f7a8b.js`.

Volt content hashes are enabled by default. For examples or prototypes that need stable filenames:

```elixir
assets "assets" do
  entry "app.ts"
  url_prefix "/assets"
  hash false
end
```

## Development server

```bash
mix astral.dev
mix astral.dev --open
mix astral.dev --config astral.config.exs --port 4000
```

The dev server:

- serves Astral routes,
- serves public files,
- delegates Volt asset/HMR routes to `Volt.DevServer`,
- injects Volt's HMR client into rendered HTML,
- watches pages/layouts/public files for full reloads,
- renders useful HTML error pages for Markdown/layout/config failures.

## Static builds

```bash
mix astral.build
```

Example output:

```text
[Astral] Built 2 page(s) into dist

Routes:
  /        dist/index.html
  /about/  dist/about/index.html

Assets:
  dist/assets/manifest.json
```

Upload `dist/` to any static host or CDN. See [`guides/deployment.md`](guides/deployment.md) for production asset behavior and deployment notes.

## Example site

A runnable example lives in `examples/basic`:

```bash
cd examples/basic
mix deps.get
mix astral.dev
mix astral.build
mix check
```

It demonstrates Markdown, HTML pages, layouts, public files, Volt TypeScript/CSS assets, and Volt JS/TS formatting/linting.

## Programmatic API

```elixir
Astral.build(config: "astral.config.exs")
Astral.dev(config: "astral.config.exs", port: 4000)
Astral.asset_path(site, "app.ts")
```

## Development

```bash
mix deps.get
mix ci
```

## License

MIT © 2026 Danila Poyarkov
