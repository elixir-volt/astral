# Static Builds

Astral builds a fully static site into `dist/` by default.

```bash
mix astral.build
```

Change the output directory in `astral.config.exs`:

```elixir
site do
  outdir "dist"
end
```

Upload the generated directory to any static host or CDN.

## Routes

Each route is written as an `index.html` file:

```text
/                 -> dist/index.html
/about/           -> dist/about/index.html
/blog/post/       -> dist/blog/post/index.html
/robots.txt       -> dist/robots.txt
```

Public files are copied from `public/` without transformation.

## Assets

Astral delegates JavaScript, TypeScript, CSS, and referenced asset processing to Volt. Configure the source entry in `astral.config.exs`:

```elixir
assets "assets" do
  entry "app.ts"
  url_prefix "/assets"
end
```

Reference the source entry from layouts:

```eex
<script type="module" src="<%= Astral.asset_path(@site, "app.ts") %>"></script>
```

In static builds, `Astral.asset_path/2` reads Volt's manifest and returns emitted files such as `/assets/app-5e6f7a8b.js`.

## Content hashes

Volt emits content-hashed assets by default. This is the recommended deployment mode because files can be cached aggressively by a CDN.

For simple prototypes or examples, disable hashing:

```elixir
assets "assets" do
  entry "app.ts"
  url_prefix "/assets"
  hash false
end
```

## Build output

`mix astral.build` prints a summary, route table, and asset manifest path:

```text
[Astral] Built 6 page(s) into dist

Routes:
  /about/              dist/about/index.html
  /                    dist/index.html
  /blog/hello-astral/  dist/blog/hello-astral/index.html

Assets:
  dist/assets/manifest.json
```
