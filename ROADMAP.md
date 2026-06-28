# Astral Roadmap

Astral's long-term goal is to become an Elixir-native static and hybrid site framework with Astro-class site features, while keeping Volt focused on frontend assets, bundling, dev-server primitives, and HMR.

## Architecture principles

- **Volt stays Vite-like.** Volt owns JavaScript/TypeScript/CSS compilation, bundling, imported assets, embedded modules, dev-server primitives, and HMR.
- **Astral owns site semantics.** Astral owns pages, routes, content collections, layouts, frontmatter, feeds, sitemaps, metadata patterns, images, islands, and deployment adapters.
- **Elixir-first configuration.** Site config is real Elixir returning structs and DSL data, not app-env state or a JavaScript config clone.
- **HEEx-first templates.** `.astral` uses Phoenix/HEEx semantics instead of inventing a JSX-like component language.
- **Parser-backed processing.** Use real parsers for Markdown, HEEx-like templates, HTML-like markup, JavaScript/TypeScript, CSS, XML/SVG, and frontmatter.
- **Value before abstraction.** Add hooks and APIs when they unlock user-facing capabilities, not just to mirror another framework's names.

## Implemented foundation

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
- Collection schemas and validation.
- Collection entry routes from `permalink` patterns.
- Collection query helpers such as `entries/2`, `published/1`, `sort_by_date/2`, and `tags/1`.
- Route patterns with Plug/Phoenix-style `:param` and `*glob` segments.
- Pagination primitives and collection pagination plugin.
- Plugin foundation: behaviour, runner, tuple options, ordering, generated routes, route rendering, page transforms, and lifecycle hooks.
- Feed and sitemap plugins.
- Markdown heading anchors and heading metadata for table-of-contents layouts.
- XM extracted as a standalone XML DSL package used by feed/sitemap plugins.
- User guides, cheatsheets, and a Volt-style README.

### v0.1.2 — Dynamic routes, images, and islands MVP

- Dynamic file routes for `.md`, `.html`, and `.astral` using bracket filename sugar such as `[slug]` and `[...path]`.
- Route params in page/layout assigns as string-keyed `@params`.
- Collection-backed detail routes such as `pages/blog/[slug].astral`.
- Dynamic route diagnostics.
- Ecto-style content collection schema fields with defaults and casting.
- Markdown rendering with Astral HEEx components.
- Optimized local and remote image pipeline, including image, picture, figure, metadata, Markdown image, dev-server, and collection image field support.
- Client-only islands for Vue, Svelte, React, and Solid.
- Island client directives for `:load`, `:idle`, `:visible`, and `:media`.
- JSON-safe island props through JSON-shaped values, JSONCodec structs, and Jason encoders.
- Type-aware Volt JavaScript checks for Astral island runtime assets.
- Vue and React islands in the basic example site.

### Unreleased — Route and asset ergonomics

- Static HEEx children for client islands, passed through the default slot/children channel.
- Server-rendered Iconify icons through PhoenixIconify's `<.icon>` component in `.astral` templates.
- Inline local SVG files through `<.svg src="..." />`, resolved with Volt asset aliases and rendered as HTML-safe SVG.
- Phoenix-shaped `get` declarations in `astral.config.exs` for one-off generated static routes.
- Plug-compatible middleware for generated config routes via `plug`.
- Userland head metadata component pattern in the basic example and pages/layouts guide, including canonical URLs, Open Graph/Twitter tags, and feed discovery links.
- Root custom 404 pages that build to `dist/404.html` and return 404 in development.
- Deterministic static output precedence documented and tested: public files, then pages, then generated routes.
- Custom 404 page in the basic example site.
- Setup-declared dynamic `.astral` pages for userland route enumeration such as tag pages, backed by strict `Astral.Route.Path` contracts.
- Documentation classifying current i18n, prefetch, and view-transition boundaries after auditing Astro's navigation features.
- Documentation classifying current CSS, font, syntax-highlighting, script, and framework-island boundaries after auditing Astro's UI-building features.
- Documentation classifying current Markdown, content collection, data-fetching, and live-content boundaries after auditing Astro's content guides.
- Documentation classifying current on-demand rendering, server island, action, session, and route caching boundaries after auditing Astro's server-rendering guides.
- Documentation classifying current static deployment and future adapter boundaries after auditing Astro's deployment and adapter guides.
- Documentation classifying current CMS, backend-service, authentication, and testing composition boundaries after auditing Astro's guides.

## Current priorities

The original v0.2/v0.5 work landed earlier than planned: dynamic routes, images, and an islands MVP are already in place. The roadmap now shifts from foundation building to hardening the site-authoring experience.

### v0.2 — Content and routing polish

Goal: make Astral feel complete for practical blogs, docs, and marketing sites.

- Richer dynamic route examples for blogs, docs, categories, and paginated archives.
- Continue documenting userland tag/category pages without making taxonomy a core abstraction.
- Harden setup-declared dynamic route enumeration diagnostics and examples.
- Improve route diagnostics beyond the existing unmatched dynamic route and duplicate route errors, especially ambiguous collection matches and output conflicts.
- Decide and document first-class redirect support for static hosts.
- More complete content collection guide examples, including schema field defaults.
- Decide whether local data-file collections such as JSON/YAML belong in core, or whether they should be expressed as plugins/userland loaders.
- Static multilingual site examples using localized folders, locale fields, and site-owned link helpers, without adding first-class i18n config prematurely.

### v0.3 — Metadata and document head

Goal: make production pages easier to build without ad hoc layout code while preserving userland composition.

- Decide whether Astral needs a core `site_url`/`base_url` config.
- Decide whether to promote userland `base_head` patterns into core helpers for canonical URLs, Open Graph/Twitter tags, and feed/sitemap discovery links.
- Decide whether per-route `<head>` contribution from pages, layouts, and plugins is worth a core API.
- If needed, add a plugin hook for head entries, likely `head/2` or equivalent.

### v0.4 — Starter templates and product polish

Goal: make Astral easy to try for real sites.

- `mix astral.new --template blog`.
- `mix astral.new --template docs`.
- `mix astral.new --template marketing`.
- Search integration for docs/blog templates.
- Syntax highlighting defaults.
- Font examples and, if warranted, a small Elixir-native font helper for local fonts/preload links.
- Related posts examples.
- Redirects.
- Stronger deployment docs for common static hosts.
- Dogfooded Astral docs site.

### v0.5 — Islands hardening

Goal: turn the existing islands MVP into a dependable production feature.

- Expand existing island diagnostics in dev and build.
- Refine the existing per-island entry generation into a clearer route/component-level code splitting strategy.
- Refine static children/slot behavior across Vue, React, Svelte, and Solid.
- Add `client:only` if it fits Astral's native API.
- Decide whether island/framework docs need SSR examples or whether client-only islands remain the intentionally small core.
- Document framework-specific island patterns.
- Stress-test island props serialization and hydration ordering.

### v0.6 — Hybrid/runtime modes

Goal: move beyond static-only without making Volt responsible for site semantics.

- Static output mode remains default.
- Plug runtime adapter.
- Phoenix integration adapter.
- Hybrid prerender plus dynamic routes.
- Runtime route manifest.
- Runtime/live endpoints beyond static generated routes, including non-GET methods and request-body handling.
- Runtime/live content collection shape for CMS/API-backed data that should not require a static rebuild.
- Build-time CMS/backend loader conventions for reusable plugins without making service-specific integrations core.
- Full page/request middleware with per-request locals for runtime modes, if it fits Elixir/Phoenix idioms.
- Request-time response controls for status, headers, redirects, cookies, and streaming where they fit Plug/Phoenix semantics.
- Server-side session integration through Plug/Phoenix-compatible storage rather than static page assigns.
- Decide whether an Astral-native action/form layer is worth adding on top of Plug/Phoenix endpoints.
- Decide where authentication examples belong: first-party guides around Phoenix/Plug composition versus optional packages.
- Decide whether runtime route caching needs an Astral API or should stay deployment/host-owned for Elixir targets.
- First-class i18n routing decisions for locale prefixes, fallbacks, domain mapping, link helpers, route verification, and browser-language detection.
- Deployment adapter shape for common static and server targets, including which host-specific static files belong in adapters versus userland `public/` files or generated routes.

### v0.7 — Client navigation runtime

Goal: add optional navigation enhancement without changing the static-first default.

- Optional route-aware prefetch runtime, delivered through Volt-managed browser assets.
- Browser cache and deployment guidance for prefetched static pages.
- Decide whether Astral needs a client router, or whether browser-native cross-document view transitions plus userland scripts are enough.
- If a client router is added, design Elixir/HEEx-native APIs for transition names, animation policy, link opt-outs, lifecycle events, and island persistence.

### v1.0 — Stable Astro-class foundation

- Stable config DSL.
- Stable content collection API.
- Stable plugin API.
- Stable `.astral` template API.
- Stable image and SVG APIs.
- Stable island API.
- Stable testing guidance for templates, plugins, generated routes, and browser assets.
- Strong HexDocs and examples.
- Dogfooded docs site built with Astral.
- Production deployment guides for common static hosts.

## Later / experimental

These are intentionally not near-term roadmap items.

- `.astro` compatibility as a separate compatibility package or mode, likely after native Astral APIs are stable.
- QuickBEAM runtime shims for compiled Astro output.
- MDX compatibility beyond current Markdown + HEEx component support.
