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

Upload the generated directory to any static host or CDN. Common host settings are:

```text
Build command: mix deps.get && mix astral.build
Publish directory: dist
```

If the host lets you choose a language/runtime image, use an Elixir image compatible with the project's `mix.exs` requirement. If your site uses Volt-managed browser assets or client islands, make sure the host also has the JavaScript package manager/runtime needed by those assets.

To preview the deployable output locally, serve `dist/` with any static file server after building. This preview is intentionally different from `mix astral.dev`: it shows the files from the last build and does not update until you run `mix astral.build` again.

## Routes

Most extensionless routes are written as `index.html` files:

```text
/                 -> dist/index.html
/about/           -> dist/about/index.html
/blog/post/       -> dist/blog/post/index.html
/robots.txt       -> dist/robots.txt
```

Public files are copied from `public/` without transformation. This is the right place for host-specific static deployment files such as `_redirects`, `_headers`, `CNAME`, or `.well-known/*` when your host supports them.

For generated host files that depend on site data, use config `get` routes or plugins to write files into `dist/` during the build.

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

## Static redirects and headers

Astral does not yet have first-class redirect, rewrite, or static header rules. Use your deployment host's native configuration today:

- place static config files in `public/`, or
- generate host-specific files with config `get` routes or plugins when they depend on collections or config data.

Config-generated route plugs can set headers for generated route responses in development and can influence generated route output, but Astral does not currently collect page-level headers into host-specific files like Netlify `_headers`.

## Adapters and server deployments

Astro uses adapters to produce host-specific server entrypoints and deployment layouts for on-demand rendering, server islands, actions, sessions, route caching, middleware modes, and platform services such as image CDNs.

Astral does not currently have deployment adapters. Static output does not need one: `mix astral.build` writes deployable files directly to `dist/`. Future hybrid/runtime modes should add Astral-owned adapters for Plug, Phoenix, and selected hosts while keeping Volt focused on browser assets and HMR.

Until then, deploy live behavior with your own Phoenix/Plug application and deploy Astral's `dist/` as static assets, or serve the built files from that application.

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
