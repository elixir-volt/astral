# Astral Roadmap

Astral's long-term goal is to compete with Astro as an Elixir-native static site and hybrid site framework, while keeping Volt focused on frontend assets, bundling, dev server, and HMR primitives.

## Architecture principles

- **Volt stays Vite-like.** Volt owns JavaScript/TypeScript/CSS compilation, bundling, assets, virtual modules, dev server primitives, and HMR.
- **Astral owns site semantics.** Astral owns pages, routes, content collections, layouts, frontmatter, feeds, sitemap, metadata, islands, and deployment adapters.
- **Elixir-first configuration.** Site config should be real Elixir returning structs, not global app env or JavaScript object clones.
- **Parser-backed processing.** Use real parsers for Markdown, HTML-like markup, JavaScript/TypeScript, CSS, and frontmatter.
- **Value before abstraction.** Add hooks and APIs when they unlock user-facing capabilities.

## Plugin architecture direction

Astral plugins should feel familiar to Volt plugin authors.

Volt's plugin design has several properties worth preserving:

- a behaviour module (`Volt.Plugin`),
- required `name/0`,
- mostly optional callbacks,
- plugins configured as modules or `{module, opts}` tuples,
- opts passed by supporting one extra callback arity,
- Vite-style `enforce/0` ordering with `:pre`, normal, and `:post`,
- a runner module that centralizes ordering and optional callback dispatch,
- first-match hooks for ownership decisions,
- pipeline hooks that transform data in sequence.

Astral now has the initial plugin foundation on `master` after v0.1.0: `Astral.Plugin`, `Astral.PluginRunner`, config DSL support, Volt-style ordering, and tuple opts support. The first hooks are intentionally focused on the existing pipeline: `config/1`, `build_start/1`, `site_discovered/1`, `render_page/3`, and `build_done/1`.

Future plugins should grow into richer site-level hooks instead of asset-level hooks:

```elixir
defmodule MySite.Plugin do
  @behaviour Astral.Plugin

  def name, do: "my-site-plugin"
  def enforce, do: :pre

  def collections(config), do: [%Astral.Collection{name: :posts, dir: "content/posts"}]
  def routes(site), do: [%Astral.Route{path: "/feed.xml", kind: :generated}]
  def render_route(route, site), do: {:ok, xml}
end
```

Likely next plugin callbacks:

- `collections/1` — provide content collection definitions.
- `load_content/3` — load/normalize content entries for plugin-owned formats.
- `routes/1` — add generated routes such as feeds, sitemaps, tag pages, or pagination pages. *(Initial foundation landed on `master` after v0.1.0.)*
- `render_route/2` — render plugin-owned generated routes. *(Initial foundation landed on `master` after v0.1.0.)*
- `transform_markdown/3` — transform MDEx document or rendered Markdown before layout.
- `transform_html/3` or expanded `render_page/3`/route hooks — transform rendered route HTML before writing/serving.
- `head/2` — contribute metadata/link/script tags.
- `dev_server/2` — optional dev-only Plug composition or route hooks.

Implementation should mirror Volt's runner discipline:

- `Astral.Plugin` behaviour with optional callbacks.
- `Astral.PluginRunner` to normalize modules / `{module, opts}` tuples.
- Stable plugin ordering through `enforce/0`.
- Callback extra-arity opts support.
- No ad hoc plugin calls scattered through builder/dev/discovery modules.

## Milestones

### v0.2 — Content framework

Goal: make Astral useful for blogs, docs, changelogs, and small content-heavy sites.

- Content collections. *(Initial discovery landed on `master` after v0.1.0.)*
- Collection schemas and validation. JSONSpec-generated JSON Schema maps are the preferred schema format; Zoi schemas are also supported. *(Initial adapter landed on `master` after v0.1.0.)*
- Draft support.
- Slugs and permalinks.
- Dynamic routes such as `pages/blog/[slug].md`.
- Generated routes from collections. *(Initial collection entry routes landed on `master` after v0.1.0.)*
- Pagination.
- Tags and categories.
- RSS/Atom feed generation.
- Sitemap generation.
- Frontmatter defaults.
- Table of contents and heading anchors.

### v0.3 — Plugin foundation

Goal: make content/build behavior extensible without hard-coding every SSG feature into core.

- `Astral.Plugin` behaviour modeled after `Volt.Plugin`. *(Initial foundation landed on `master` after v0.1.0.)*
- `Astral.PluginRunner` with Volt-style optional callback dispatch. *(Initial foundation landed on `master` after v0.1.0.)*
- Config DSL support for plugins. *(Initial foundation landed on `master` after v0.1.0.)*
- Plugin docs and examples. *(Initial README coverage landed on `master` after v0.1.0.)*
- Built-in feed/sitemap functionality either as internal plugins or plugin-shaped modules.
- Generated route hooks for feeds/sitemaps/pagination. *(Initial `routes/1` + `render_route/2` hooks landed on `master` after v0.1.0.)*
- Compatibility story for passing Astral-generated virtual entries/modules to Volt.

### v0.4 — HEEx components

Goal: provide an Elixir-native component authoring story before inventing a custom file format.

- `.heex` pages and layouts.
- Function components.
- Slots.
- Compile-time template checks where practical.
- Shared assigns and helpers for layouts/pages.
- Metadata/head helpers.

### v0.5 — Islands MVP

Goal: deliver Astro's biggest differentiator in an Elixir/Volt-native way.

- Island declarations in HEEx/EEx layouts/pages.
- Initial hydration modes:
  - `client:load`
  - `client:idle`
  - `client:visible`
- Island manifest generation.
- Prop serialization.
- Volt virtual entries for island client boot code.
- One framework adapter first, then expand.

Candidate API direction:

```heex
<.island component="Counter" client="visible" props={%{count: 0}} />
```

### v0.6 — Framework adapters and richer islands

- React islands.
- Vue islands.
- Svelte islands.
- Solid islands.
- `client:media` and `client:only` hydration modes.
- Route-level and component-level code splitting.
- Island dev diagnostics.

### v0.7 — Documentation/blog product layer

Goal: compete for real docs and blog sites.

- Starter templates:
  - blog
  - docs
  - marketing
- Search integration.
- Syntax highlighting.
- Related posts.
- Redirects.
- Canonical URLs.
- Social metadata helpers.
- `mix astral.new --template docs`.

### v0.8 — Hybrid/runtime modes

Goal: move beyond static-only without making Volt responsible for site semantics.

- Static output mode remains default.
- Plug runtime adapter.
- Phoenix integration adapter.
- Hybrid prerender + dynamic routes.
- Runtime route manifest.

### v1.0 — Stable Astro-class foundation

- Stable config DSL.
- Stable content collection API.
- Stable plugin API.
- Stable island API.
- Strong HexDocs and examples.
- Dogfooded docs site built with Astral.
- Production deployment guides for common static hosts.

## Near-term priority

The next major feature should be **content collections + dynamic routes**, with the plugin system designed in parallel so feeds, sitemap, pagination, and future integrations can be implemented plugin-first instead of as one-off core features.
