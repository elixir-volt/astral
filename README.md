# Astral ✨

[![Hex.pm](https://img.shields.io/hexpm/v/astral.svg)](https://hex.pm/packages/astral) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/astral)

Static site generation for Elixir, powered by Volt. Astral gives you pages, routes, Markdown, frontmatter, layouts, content collections, feeds, sitemaps, public files, and static HTML output while Volt handles TypeScript, CSS, assets, dev-server integration, and HMR.

```bash
mix igniter.install astral
mix astral.dev
mix astral.build
```

Build content sites, docs, blogs, and marketing pages with ordinary Elixir configuration and templates. No JavaScript site config, no separate bundler process, no Node.js requirement for the default toolchain.

## Why Astral

Most static site generators put the site layer in JavaScript. Astral keeps it in Elixir:

- `astral.config.exs` for site configuration.
- Markdown pages with MDEx and YAML frontmatter.
- HEEx-first `.astral` pages, layouts, and components.
- Schema-backed content collections with JSONSpec-style typespec maps or Zoi.
- Static pagination and plugin-generated routes.
- Built-in feed and sitemap plugins.
- Public static files copied as-is.
- TypeScript, CSS, imported assets, dev serving, and HMR through Volt.
- Plug/Bandit development server with full reloads for site files.
- Igniter-powered starter scaffolding.

Astral is early but usable for small static sites, documentation prototypes, and blogs. See [`ROADMAP.md`](ROADMAP.md) for planned work.

## Installation

Install into an existing Mix project:

```bash
mix igniter.install astral
```

Or add the dependency manually:

```elixir
def deps do
  [{:astral, "~> 0.1.1"}]
end
```

Then scaffold a starter site:

```bash
mix astral.new
```

The scaffold creates `astral.config.exs`, starter pages, layouts, TypeScript/CSS assets, public files, `tsconfig.json`, and Volt formatting/linting configuration.

## Project layout

```text
astral.config.exs
pages/
  index.md
  about.md
  components.astral
layouts/
  default.html
  site.astral
components/
  card.astral
content/
  posts/
    hello.md
assets/
  app.ts
  styles.css
public/
  robots.txt
```

## Configuration

Astral config is Elixir and returns an `%Astral.Config{}` struct. Site settings live in `astral.config.exs`, not global application env.

```elixir
# astral.config.exs
import Astral.Config

site do
  root "."
  outdir "dist"
  pages "pages"
  public "public"
  components "components"

  layouts "layouts" do
    default "default.html"
  end

  assets "assets" do
    entry "app.ts"
    url_prefix "/assets"
  end
end
```

## Pages and layouts

Markdown pages are rendered with MDEx. YAML frontmatter controls route metadata, permalink, and layout selection:

```markdown
---
title: About Astral
permalink: /about-us/
layout: default.html
---

# About
```

Output routes are derived from files unless `permalink` is set:

```text
pages/index.md       -> dist/index.html
pages/about.md       -> dist/about/index.html
pages/blog/post.md   -> dist/blog/post/index.html
pages/raw.html       -> dist/raw/index.html
```

Use `layout: false` to render a page without a layout. Plain `.html` files in `pages/` are supported too.

EEx layouts receive the rendered page as `@content`:

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

Common layout assigns:

- `@content` — rendered page HTML.
- `@page` — `%Astral.Content{}` for the current page.
- `@metadata` — decoded frontmatter map.
- `@route` — route path such as `/about/`.
- `@site` — discovered `%Astral.Site{}`.
- `@collections` — content collection entries grouped by collection name.
- `@entry` — current collection entry, otherwise `nil`.
- `@routes` — generated `%Astral.Route{}` values.

## `.astral` templates

`.astral` files are HEEx-first static templates. They support interpolation, attributes, `:if`/`:for`, function components, slots, and local components using Phoenix HEEx syntax.

```astral
<!-- components/pill.astral -->
<span class="pill">
  {render_slot(@inner_block)}
</span>
```

```astral
<!-- pages/index.astral -->
---
assigns = assign(assigns, :title, "Home")
---

<h1>{@title}</h1>
<.pill>Elixir</.pill>
```

```astral
<!-- layouts/site.astral -->
<!doctype html>
<html lang="en">
  <body>
    <main data-route={@route}>{@content}</main>
  </body>
</html>
```

Top-level template setup blocks are Elixir. Assign values with Phoenix-style `assign/3`:

```astral
---
assigns = assign(assigns, :title, "Docs")
---

<h1>{@title}</h1>
```

Browser assets inside `.astral` templates are extracted into Volt's asset graph:

```astral
<style>
  .hero { padding: 4rem; }
</style>

<script lang="ts">
  document.querySelector(".hero")?.classList.add("ready");
</script>
```

Those blocks are built, served, checked, and hot-reloaded as normal Volt modules instead of being treated as server-rendered HTML.

## Content collections

Collections group Markdown entries such as posts, docs, changelog items, or authors. JSONSpec-style typespec maps are the preferred schema style, with Zoi available when runtime transformations are useful.

```elixir
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

Collection entries are validated and exposed to layouts as `@collections`:

```eex
<%= for post <- @collections.posts do %>
  <a href={post.route_path}><%= post.data.title %></a>
<% end %>
```

`entry.metadata` keeps original string-keyed frontmatter. `entry.data` contains schema-normalized data. Entry layouts also receive `@entry` for the current collection entry.

Markdown headings are rendered with stable anchors and stored on `@page.headings` for table-of-contents layouts:

```eex
<nav>
  <%= for heading <- @page.headings do %>
    <a href="#<%= heading.id %>"><%= heading.text %></a>
  <% end %>
</nav>
```

## Pagination, feeds, and sitemaps

Astral includes plugin-generated routes for common static-site needs.

Collection pagination:

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

Feed and sitemap plugins:

```elixir
site do
  plugins [
    {Astral.Plugin.Feed,
     site_url: "https://example.com",
     title: "My Blog",
     author: "Astral",
     collection: :posts},
    {Astral.Plugin.Sitemap,
     site_url: "https://example.com"}
  ]
end
```

Tags and categories are ordinary userland routes. Build them with collection helpers, `Astral.Pagination`, and a small plugin when your site needs them.

## Assets

Astral delegates assets to Volt. Reference source assets from layouts with `Astral.asset_path/2`:

```eex
<script type="module" src="<%= Astral.asset_path(@site, "app.ts") %>"></script>
```

In development this returns the source path served by Volt, for example `/assets/app.ts`. In static builds it reads Volt's manifest and returns the emitted file, for example `/assets/app-5e6f7a8b.js`.

Content hashes are enabled by default. Disable them for examples or prototypes that need stable filenames:

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
- delegates asset and HMR routes to `Volt.DevServer`,
- injects Volt's HMR client into rendered HTML,
- watches pages, layouts, components, and public files,
- renders useful HTML error pages for Markdown, layout, and config failures.

## Static builds

```bash
mix astral.build
```

Example output:

```text
[Astral] Built 6 page(s) into dist

Routes:
  /about/              dist/about/index.html
  /components/         dist/components/index.html
  /                    dist/index.html
  /blog/hello-astral/  dist/blog/hello-astral/index.html

Assets:
  dist/assets/manifest.json
```

Upload `dist/` to any static host or CDN. See [`guides/deployment.md`](guides/deployment.md) for production asset behavior and deployment notes.

## Plugins

Extend Astral with the `Astral.Plugin` behaviour. Plugins can update config, inspect the discovered site, add routes, render generated routes, transform rendered pages, or run build lifecycle hooks.

```elixir
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

## Example site

A runnable example lives in `examples/basic`:

```bash
cd examples/basic
mix deps.get
mix astral.dev
mix astral.build
mix check
```

It demonstrates Markdown, HTML pages, HEEx-first `.astral` pages/layouts/components, public files, Volt TypeScript/CSS assets, feeds, sitemaps, and Volt JS/TS formatting/linting.

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/astral). For frontend asset behavior, see [Volt](https://hexdocs.pm/volt).

## Development

```bash
mix deps.get
mix ci
```

## License

MIT © 2026 Danila Poyarkov
