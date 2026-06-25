# Deployment

Astral builds a fully static site into `dist/` by default.

```sh
mix astral.build
```

The output directory can be changed in `astral.config.exs`:

```elixir
site do
  outdir "dist"
end
```

Upload the generated directory to any static host or CDN.

## Routes

Each page route is written as an `index.html` file:

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

Use `Astral.asset_path/2` from EEx layouts:

```eex
<script type="module" src="<%= Astral.asset_path(@site, "app.ts") %>"></script>
```

In development this points to the source module served by Volt, for example `/assets/app.ts`. In production builds it reads Volt's `manifest.json` and returns the emitted file, for example `/assets/app-5e6f7a8b.js`.

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

With hashing disabled, `app.ts` emits as `dist/assets/app.js`.

## Build output

`mix astral.build` prints a summary, route table, and asset manifest path:

```text
[Astral] Built 2 page(s) into dist

Routes:
  /        dist/index.html
  /about/  dist/about/index.html

Assets:
  dist/assets/manifest.json
```
