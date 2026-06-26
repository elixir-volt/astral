# Astral Roadmap

Astral's long-term goal is to become an Elixir-native static site and hybrid site framework with Astro-class site features, while keeping Volt focused on frontend assets, bundling, dev server primitives, and HMR.

## Architecture principles

- **Volt stays Vite-like.** Volt owns JavaScript/TypeScript/CSS compilation, bundling, imported assets, embedded modules, dev server primitives, and HMR.
- **Astral owns site semantics.** Astral owns pages, routes, content collections, layouts, frontmatter, feeds, sitemaps, metadata, islands, and deployment adapters.
- **Elixir-first configuration.** Site config is real Elixir returning structs, not global app env or JavaScript object clones.
- **HEEx-first templates.** `.astral` uses Phoenix/HEEx semantics instead of inventing a JSX-like component language.
- **Parser-backed processing.** Use real parsers for Markdown, HEEx-like templates, HTML-like markup, JavaScript/TypeScript, CSS, and frontmatter.
- **Value before abstraction.** Add hooks and APIs when they unlock user-facing capabilities.

## Shipped foundation

### v0.1.0 — Initial static site generator

- Static HTML and Markdown build pipeline.
- Elixir `astral.config.exs` site DSL.
- MDEx-backed Markdown and YAML frontmatter support.
- EEx layouts with page, metadata, route, and site assigns.
- Per-page layout selection and layout disabling.
- Public static file copying.
- Plug/Bandit development server composed with Volt.
- `mix astral.dev`, `mix astral.build`, `mix astral.new`, and `mix astral.install`.
- `Astral.asset_path/2` for Volt-managed layout assets.
- Runnable `examples/basic` starter site.

### v0.1.1 — Content, plugins, and `.astral` templates

- HEEx-first `.astral` pages, layouts, and local components.
- Elixir setup blocks in `.astral` templates.
- Parser-backed `.astral` `<style>` and `<script>` extraction through Volt embedded modules.
- Local component discovery from `components/**/*.astral`.
- Content collections.
- Collection schemas and validation with JSONSpec-style typespec maps and Zoi.
- Collection entry routes from `permalink` patterns.
- Collection query helpers such as `entries/2`, `published/1`, `sort_by_date/2`, and `tags/1`.
- Route patterns with Plug/Phoenix-style `:param` and `*glob` segments.
- Pagination primitives and collection pagination plugin.
- Plugin foundation modeled after Volt: behaviour, runner, tuple options, ordering, generated routes, route rendering, page transforms, and lifecycle hooks.
- Feed and sitemap plugins.
- Markdown heading anchors and heading metadata for table-of-contents layouts.
- XM extracted as a standalone XML DSL package used by feed/sitemap plugins.
- User guides, cheatsheets, and a Volt-style README.

## Near-term priority: dynamic file routes

The next major feature should be dynamic file routes. This is the biggest missing SSG primitive for blogs, docs, and userland route generation.

Target file shapes:

```text
pages/blog/[slug].astral
pages/blog/[slug].md
pages/docs/[...path].md
pages/tags/[tag]/[...page].astral
```

Route equivalents:

```text
/blog/:slug
/docs/*path
/tags/:tag/*page
```

Dynamic file routes should integrate with collections without making tags/categories a core taxonomy abstraction. A common blog detail page should be expressible as a user-owned route template backed by collection data:

```text
content/posts/hello.md
pages/blog/[slug].astral
```

The page template owns the HTML while Astral provides the matching entry and route params.

### Design goals

- Keep route syntax Elixir/Phoenix-like at the API level: `:slug` and `*path`.
- Use bracket filenames only as file-route sugar.
- Avoid `:` and `*` in filenames for Windows and shell portability.
- Support `.md`, `.html`, and `.astral` pages.
- Make collection-backed dynamic routes feel like ordinary page rendering.
- Keep tags/categories userland.
- Preserve generated route plugins for feeds, sitemaps, pagination, and custom files.

### Likely work

- Add parser-backed file-route conversion from `[slug]` / `[...path]` filenames to `Astral.Route.Pattern`.
- Add route params to page/layout assigns.
- Add collection matching for route params, initially by `slug`.
- Decide how `get_static_paths`-style enumeration should look in Elixir, if needed for non-collection dynamic pages.
- Add dev/build diagnostics for dynamic routes with missing params or unmatched entries.
- Add guide coverage and example site pages.

## Next milestones

### v0.2 — Dynamic content routes

Goal: make Astral a practical blog/docs framework with user-owned dynamic templates.

- Dynamic file routes for `.md`, `.html`, and `.astral`.
- Collection-backed detail routes such as `pages/blog/[slug].astral`.
- Route params available in pages and layouts.
- Dynamic route diagnostics.
- Userland tag pages documented with dynamic routes and pagination.
- Frontmatter defaults.
- More complete content collection guide examples.

### v0.3 — Metadata and document head

Goal: make production pages easier to build without ad hoc layout code.

- Page metadata helpers.
- Canonical URL helpers.
- Open Graph and Twitter card helpers.
- Feed/sitemap discovery links.
- Per-route `<head>` contribution from pages, layouts, and plugins.
- Plugin hook for head entries, likely `head/2` or equivalent.

### v0.4 — Starter templates and product polish

Goal: make Astral easy to try for real sites.

- `mix astral.new --template blog`.
- `mix astral.new --template docs`.
- `mix astral.new --template marketing`.
- Search integration for docs/blog templates.
- Syntax highlighting defaults.
- Related posts examples.
- Redirects.
- Stronger deployment docs for common static hosts.

### v0.5 — Islands MVP

Goal: deliver Astro's biggest differentiator in an Elixir/Volt-native way.

- Island declarations in `.astral`/HEEx templates.
- Initial hydration modes:
  - `client:load`
  - `client:idle`
  - `client:visible`
- Island manifest generation.
- Prop serialization.
- Volt entries for island client boot code.
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

### v0.7 — Hybrid/runtime modes

Goal: move beyond static-only without making Volt responsible for site semantics.

- Static output mode remains default.
- Plug runtime adapter.
- Phoenix integration adapter.
- Hybrid prerender plus dynamic routes.
- Runtime route manifest.

### v1.0 — Stable Astro-class foundation

- Stable config DSL.
- Stable content collection API.
- Stable plugin API.
- Stable `.astral` template API.
- Stable island API.
- Strong HexDocs and examples.
- Dogfooded docs site built with Astral.
- Production deployment guides for common static hosts.
