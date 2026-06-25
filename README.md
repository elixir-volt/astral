# Astral

Astral is a Volt-powered static site generator for Elixir applications.

It is inspired by Astro's separation of responsibilities: Volt remains the generic frontend asset/dev/build layer, while Astral owns site semantics such as pages, routes, layouts, content, and static HTML output.

## Status

Astral is in early development. The first milestone supports HTML and Markdown pages, MDEx-backed frontmatter extraction, an optional single layout, public static files, and an optional Volt asset entry.

## Usage

Create a small site:

```text
pages/index.html
pages/about.md
layouts/default.html
assets/app.ts
public/robots.txt
```

Layouts are EEx templates. Use `@content` where page HTML should be inserted, and `@page`, `@metadata`, `@route`, and `@site` for page/site data:

```html
<!doctype html>
<html>
  <head>
    <title><%= @page.title || "Astral" %></title>
  </head>
  <body>
    <%= @content %>
    <script type="module" src="<%= Astral.asset_path(@site, "app.ts") %>"></script>
  </body>
</html>
```

Configure the site with Elixir:

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

Build the site:

```sh
mix astral.build
```

Or call the library API directly:

```elixir
Astral.build(config: "astral.config.exs")
```

You can also pass keyword options directly:

```elixir
Astral.build(
  root: ".",
  pages: "pages",
  layouts: "layouts",
  outdir: "dist",
  assets: "assets"
)
```

Markdown pages are rendered with MDEx. YAML frontmatter is extracted by MDEx and decoded with YamlElixir:

```markdown
---
title: About Astral
permalink: /about-us/
---

# About
```

Output routes:

```text
pages/index.html      -> dist/index.html
pages/about.md        -> dist/about/index.html
pages/blog/post.html  -> dist/blog/post/index.html
```

A `permalink` frontmatter value overrides the default route. A `layout` value selects a layout from the layouts directory, and `layout: false` renders without a layout:

```markdown
---
title: Landing
layout: marketing.html
---

# Landing
```

```markdown
---
layout: false
---

# Raw Page
```

If the configured asset entry exists, Astral builds it with Volt into `dist/assets`. Asset output uses Volt's content hashes by default; use `Astral.asset_path(@site, "app.ts")` in layouts so production pages reference the manifest output. Set `hash false` inside the `assets` block when a simple stable filename is better for examples or prototypes.

## Development server

Start the development server with:

```bash
mix astral.dev --config astral.config.exs --port 4000
mix astral.dev --open
```

Or from Elixir:

```elixir
Astral.dev(config: "astral.config.exs", port: 4000)
```

The dev server composes Volt under the asset URL prefix, serves Astral page routes, serves public files, injects Volt's HMR client into rendered pages, watches pages/layouts/public files for full reloads, and renders development error pages for site failures.

## Installation

Once published, add Astral to your dependencies:

```elixir
def deps do
  [
    {:astral, "~> 0.1.0"}
  ]
end
```

## Create a starter site

In an existing Mix project with Astral installed:

```sh
mix astral.new
```

Or install and scaffold through Igniter:

```sh
mix igniter.install astral
```

The Igniter-powered scaffold creates `astral.config.exs`, starter Markdown pages, an EEx layout, TypeScript/CSS assets, public files, `tsconfig.json`, and Volt JS/TS formatting/linting configuration.

## Example site

A runnable example lives in `examples/basic`:

```sh
cd examples/basic
mix deps.get
mix astral.dev
mix astral.build
```

It demonstrates Markdown, HTML pages, layouts, public files, Volt TypeScript/CSS assets, and Volt JS/TS formatting/linting.

See `guides/deployment.md` for static hosting and production asset behavior.

## Development

```sh
mix deps.get
mix ci
```
