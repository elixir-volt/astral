# Astral

Astral is a Volt-powered static site generator for Elixir applications.

It is inspired by Astro's separation of responsibilities: Volt remains the generic frontend asset/dev/build layer, while Astral owns site semantics such as pages, routes, layouts, content, and static HTML output.

## Status

Astral is in early development. The first milestone supports plain HTML pages, an optional single layout, public static files, and an optional Volt asset entry.

## Usage

Create a small site:

```text
pages/index.html
pages/about.html
layouts/default.html
assets/app.js
public/robots.txt
```

Use `{{ content }}` in `layouts/default.html` where page HTML should be inserted:

```html
<!doctype html>
<html>
  <body>{{ content }}</body>
</html>
```

Build the site:

```elixir
Astral.build(
  root: ".",
  pages: "pages",
  layouts: "layouts",
  outdir: "dist",
  assets: "assets"
)
```

Output routes:

```text
pages/index.html      -> dist/index.html
pages/about.html      -> dist/about/index.html
pages/blog/post.html  -> dist/blog/post/index.html
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
