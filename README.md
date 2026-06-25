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

Astral is early, but the first release is useful for small static sites and documentation prototypes. Initial content collections and plugins have landed on `master` after v0.1.0; feeds, sitemap generation, and richer routing are intentionally left for follow-up releases. See [`ROADMAP.md`](ROADMAP.md) for the planned path toward an Astro-class framework.

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

Collection entries are exposed to layouts as `@collections`:

```eex
<%= for post <- @collections.posts do %>
  <a href={post.route_path}><%= post.data.title %></a>
<% end %>
```

`post.metadata` keeps the original string-keyed frontmatter. `post.data` contains schema-normalized data.

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

Available hooks include `config/1`, `build_start/1`, `site_discovered/1`, `render_page/3`, and `build_done/1`. Tuple options are passed to callbacks that define one extra argument, such as `render_page/4`.

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
