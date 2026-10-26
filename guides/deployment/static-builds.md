# Static Builds

Astral builds a fully static site into `dist/` by default.

```bash
mix astral.build
```

Change the output directory in `astral.config.exs`:

```elixir
outdir "dist"
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

## Serving under a base path

Some hosts serve a site below the domain root. GitHub Pages serves project sites at `https://<user>.github.io/<repo>/`, and a Phoenix app can mount docs at `/docs/`. Set `base_path` so Astral emits URLs under that path:

```elixir
site_url "https://example.github.io"
base_path "/my-site/"
```

`base_path` defaults to `"/"`. Output files stay at the root of `dist/`: publish `dist/` as the content of the sub-path.

Astral keeps two values for every page and entry. The route path, such as `page.route_path`, `entry.route_path`, or `@route`, is relative to the base path: it identifies the route and decides its output file, and plugin options such as `exclude:` match against it. The `url`, such as `page.url`, `entry.url`, or `@url`, is the browser path with the base path applied. Link with the `url`:

```astral
<a :for={post <- @collections.posts} href={post.url}>{post.data.title}</a>
```

Astral also applies the base path wherever it produces a URL:

- `Astral.asset_path/2`, Volt's asset prefix, `url()` references in built CSS, and island chunk imports,
- optimized image URLs,
- `@page.urls` in pagination routes,
- feed, sitemap, and `llms.txt` links.

Build any other root-relative link in a template with `Astral.url/2`:

```astral
<!-- layouts/default.astral -->
<nav>
  <a href={Astral.url(@site, "/")}>Home</a>
  <a href={Astral.url(@site, "/about/")}>About</a>
</nav>
```

Absolute URLs, fragments, and relative links pass through unchanged. Astral does not rewrite links written directly in Markdown or HTML, such as `[About](/about/)`: write those with the base path, or use relative links. `mix astral.dev` serves the site only under `base_path`, so a link missing the prefix returns 404 in development as it would when deployed.

`site_url` is the site's origin. Feed, sitemap, and `llms.txt` plugins use it when their own `:site_url` option is omitted, and `Astral.absolute_url/2` combines it with the base path.

## Assets

Astral delegates JavaScript, TypeScript, CSS, and referenced asset processing to Volt. Configure the source entry in `astral.config.exs`:

```elixir
assets do
  entry "app.ts"
end
```

Reference the source entry from layouts:

```astral
<script type="module" src={Astral.asset_path(@site, "app.ts")}></script>
```

In static builds, `Astral.asset_path/2` reads Volt's manifest and returns emitted files such as `/assets/app-5e6f7a8b.js`.

`url_prefix` is an absolute URL prefix and is not nested under `base_path`. When it is omitted, it defaults to the base path followed by `assets`: with `base_path "/docs/"`, the same file is `/docs/assets/app-5e6f7a8b.js`. Set it to serve assets from somewhere else, such as `url_prefix "https://cdn.example.com/assets"`.

## Content hashes

Volt emits content-hashed assets by default. This is the recommended deployment mode because files can be cached aggressively by a CDN.

For simple prototypes or examples, disable hashing:

```elixir
assets do
  entry "app.ts"
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
