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
assets/app.js
public/robots.txt
```

Layouts are EEx templates. Use `@content` where page HTML should be inserted, and `@page`, `@metadata`, and `@route` for page data:

```html
<!doctype html>
<html>
  <head>
    <title><%= @page.title || "Astral" %></title>
  </head>
  <body><%= @content %></body>
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
    entry "app.js"
    url_prefix "/assets"
  end
end
```

Build the site:

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

If `assets/app.js` exists, Astral builds it with Volt into `dist/assets`.

## Installation

Once published, add Astral to your dependencies:

```elixir
def deps do
  [
    {:astral, "~> 0.1.0"}
  ]
end
```

## Development

```sh
mix deps.get
mix ci
```
