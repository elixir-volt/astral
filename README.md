# Astral ✨

[![Hex.pm](https://img.shields.io/hexpm/v/astral.svg)](https://hex.pm/packages/astral) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/astral)

Static site generation for Elixir. Astral gives you Astro-class site features — pages, Markdown, layouts, content collections, pagination, feeds, sitemaps, and component templates — while Volt handles TypeScript, CSS, assets, dev serving, and HMR.

```bash
mix igniter.install astral
mix astral.dev
mix astral.build
```

Build docs, blogs, marketing pages, and content sites with Elixir config and templates. No JavaScript site config, no separate bundler process, no Node.js requirement for the default toolchain.

## Why Astral

Most static site generators put your content model, routing, and build configuration in JavaScript. Astral keeps the site layer in Elixir and delegates frontend assets to Volt.

You get the pieces expected from a modern static site framework:

- File-based static pages from Markdown, HTML, and `.astral` templates.
- Markdown content with HEEx-style local components through MDEx.
- Dynamic file routes such as `pages/blog/[slug].astral` and `pages/docs/[...path].md`.
- HEEx-first `.astral` pages, layouts, and local components.
- Schema-backed content collections with Ecto-style fields, JSONSpec maps, or Zoi schemas.
- Static pagination and generated routes for blogs, docs, and indexes.
- Built-in feed and sitemap plugins.
- Stable Markdown heading anchors for table-of-contents layouts.
- Optimized build-time images with `<.image>`, `<.picture>`, and `<.figure>` components.
- Client-only islands for Volt-powered framework components.
- Public files copied as-is.
- TypeScript, CSS, imported assets, dev serving, and HMR through Volt.
- Plug/Bandit dev server with full reloads for pages, layouts, components, and public files.
- Igniter-powered starter scaffolding.

Astral is early but usable for small static sites, documentation prototypes, and blogs. See the [roadmap](https://hexdocs.pm/astral/roadmap.html) for planned work.

## Elixir site config

`astral.config.exs` is ordinary Elixir:

```elixir
import Astral.Config

site do
  pages "pages"
  public "public"
  components "components"

  layouts "layouts" do
    default "site.astral"
  end

  assets "assets" do
    entry "app.ts"
    url_prefix "/assets"
  end
end
```

See the [Getting Started guide](https://hexdocs.pm/astral/getting-started.html) and [Configuration cheatsheet](https://hexdocs.pm/astral/configuration.html).

## HEEx-first static templates

`.astral` templates use Phoenix HEEx syntax but render static HTML:

```astral
---
assigns = assign(assigns, :title, "Home")
---

<h1>{@title}</h1>
<.pill :for={feature <- @features}>{feature}</.pill>
```

Local components and slots use HEEx conventions:

```astral
<!-- components/card.astral -->
<article class="card">
  {render_slot(@inner_block)}
</article>
```

Browser assets inside `.astral` templates are extracted into Volt's asset graph:

```astral
<style>.hero { padding: 4rem; }</style>
<script lang="ts">console.log("ready")</script>
```

Markdown can use the same local components:

```md
# Project

<.card>
  Rendered inside Markdown by MDEx and HEEx.
</.card>
```

See the [`.astral` Templates guide](https://hexdocs.pm/astral/astral-templates.html) and [Pages and Layouts guide](https://hexdocs.pm/astral/pages-and-layouts.html).

## Content collections

Define typed content collections in Elixir:

```elixir
collections do
  collection :posts, "content/posts" do
    permalink "/blog/:slug/"
    layout "post.html"

    schema do
      field :title, :string, required: true
      field :date, :date, required: true
      field :draft, :boolean, default: false
      field :tags, {:array, :string}, default: []
      field :cover, :image
    end
  end
end
```

Image fields resolve relative to their entry file, expose dimensions and format, and can be passed directly to `<.image>`, `<.picture>`, or `<.figure>`.

Allow trusted remote image optimization with URL-shaped policies:

```elixir
image do
  allow_remote "https://images.example.com/**"
end
```

Use validated data from layouts and templates:

```eex
<%= for post <- @collections.posts do %>
  <a href={post.route_path}><%= post.data.title %></a>
<% end %>
```

Collection-backed dynamic file routes let page templates own the detail page HTML:

```text
content/posts/hello.md
pages/blog/[slug].astral
```

See the [Content Collections guide](https://hexdocs.pm/astral/content-collections.html) and [Pages and Layouts guide](https://hexdocs.pm/astral/pages-and-layouts.html).

## Pagination, feeds, and sitemaps

Build common site routes with plugins:

```elixir
plugins [
  {Astral.Plugin.CollectionPages,
   collection: :posts,
   pattern: "/blog/*page",
   page_size: 10,
   layout: "blog.html"},
  {Astral.Plugin.Feed,
   site_url: "https://example.com",
   title: "My Blog",
   author: "Me",
   collection: :posts},
  {Astral.Plugin.Sitemap,
   site_url: "https://example.com"}
]
```

See [Pagination and Generated Routes](https://hexdocs.pm/astral/pagination-and-routes.html) and [Feeds and Sitemaps](https://hexdocs.pm/astral/feeds-and-sitemaps.html).

## Optimized images and Volt-powered assets

Render optimized images from `.astral` pages or component-aware Markdown:

```astral
<.image src="images/hero.jpg" alt="Hero" width={1200} format={:webp} />

<.picture
  src="images/hero.jpg"
  alt="Hero"
  widths={[480, 768, 1200]}
  formats={[:webp, :avif]}
/>

<.figure src="images/hero.jpg" alt="Hero" caption="Product hero" width={1200} />
```

Astral writes compressed, content-hashed variants to `dist/assets/` during static builds. Local Markdown image syntax is optimized too:

```md
![Hero](./hero.jpg "Optional title")
```

Reference source frontend assets from layouts:

```eex
<script type="module" src="<%= Astral.asset_path(@site, "app.ts") %>"></script>
```

In development this points to Volt's dev server. In static builds it resolves through Volt's manifest to content-hashed output files.

See the [Assets guide](https://hexdocs.pm/astral/assets.html) and the [Volt documentation](https://hexdocs.pm/volt) for frontend tooling details.

## Client islands

Mount a browser component from your Volt assets:

```astral
<.vue
  component="islands/Gallery.vue"
  client={:visible}
  props={%{images: @images}}
/>
```

Astral provides framework-specific island components for every framework Volt supports: `<.vue>`, `<.svelte>`, `<.react>`, and `<.solid>`. All adapters are enabled by default; configure `islands do adapter :vue end` only if you want to restrict the allowed set. Client directives include `:load`, `:idle`, `:visible`, and `:media` with a media query string. The first island milestone is client-only: Astral renders a container and generated entry module, while Volt compiles the imported framework component.

## Development and builds

```bash
mix astral.dev --open
mix astral.build
```

`mix astral.dev` serves routes, public files, Volt assets, HMR, and useful HTML error pages. `mix astral.build` writes static files to `dist/` for any static host or CDN.

See the [Development Server guide](https://hexdocs.pm/astral/development-server.html) and [Static Builds guide](https://hexdocs.pm/astral/static-builds.html).

## Example site

A runnable example lives in `examples/basic`:

```bash
cd examples/basic
mix deps.get
mix astral.dev
mix astral.build
mix check
```

It demonstrates Markdown, HTML pages, `.astral` pages/layouts/components, public files, Volt TypeScript/CSS assets, feeds, sitemaps, and Volt JS/TS formatting/linting.

## Documentation

Full documentation, guides, and cheatsheets are available on [HexDocs](https://hexdocs.pm/astral).

## Development

```bash
mix deps.get
mix ci
```

## License

MIT © 2026 Danila Poyarkov
