# Changelog

## Unreleased

### Added

- Static HEEx children for client islands, passed to framework runtimes through the default slot/children channel.
- Server-rendered Iconify icons through PhoenixIconify's `<.icon>` component in `.astral` templates.
- Inline local SVG files through `<.svg src="..." />`, resolved with Volt asset aliases and rendered as HTML-safe SVG.
- Phoenix-shaped `get` declarations in `astral.config.exs` for one-off generated static routes, with Plug-compatible middleware via `plug`.
- A userland head metadata component pattern in the basic example and pages/layouts guide.
- Root custom 404 pages (`pages/404.{md,html,astral}`) that build to `dist/404.html` and return 404 in development.
- Documentation and tests for deterministic static output precedence: public files, then pages, then generated routes.
- A custom 404 page in the basic example site.
- Clearer content collection documentation for schema defaults and userland tag page patterns.
- Setup-declared dynamic `.astral` page paths through strict `Astral.Route.Path` values and the `path/1` setup helper.
- Clearer develop/build/configuration docs covering dev server options, static build preview expectations, and metadata placement.
- Editor setup, TypeScript, and environment variable guides that map Astral's Elixir site layer to Volt browser tooling.
- Clearer plugins/integrations documentation separating Astral site plugins from Volt browser asset plugins.
- Clearer routing, static endpoint, and middleware-scope documentation after auditing Astro's routing/endpoints/middleware guides.
- Navigation documentation covering current i18n, prefetch, and view-transition boundaries.
- Styling and browser-code documentation covering current CSS, font, syntax-highlighting, script, and framework-island boundaries.
- Markdown, content, and data-fetching documentation covering current MDX, Markdown import, content loader, and live collection boundaries.
- Server/runtime documentation covering current on-demand rendering, server island, action, session, and route caching boundaries.
- Deployment documentation covering current static-host deployment and future adapter boundaries.
- Backend, authentication, and testing documentation covering current composition boundaries.
- Image documentation covering current build-time image service and future adapter/CDN boundaries.

### Changed

- Collection helpers, feed entry authors/dates, and collection sitemap dates now use schema-normalized `entry.data` instead of falling back to raw string-keyed frontmatter metadata.
- Schema-less collections now expose empty normalized `entry.data` while preserving raw frontmatter in `entry.metadata`.

## 0.1.2 - 2026-06-26

### Added

- Dynamic file routes with route diagnostics.
- Ecto-style content collection schema fields.
- Markdown rendering with Astral HEEx components.
- Optimized local and remote image pipeline with image, picture, figure, metadata, Markdown image, dev-server, and collection image field support.
- Client-only islands for Vue, Svelte, React, and Solid with framework-specific HEEx components.
- Island client directives for `:load`, `:idle`, `:visible`, and `:media`.
- JSON-safe island props handling through JSON-shaped values, JSONCodec structs, and Jason encoders.
- Type-aware Volt JavaScript checks for Astral island runtime assets.
- Vue and React islands in the basic example site.

### Changed

- All Volt-supported island adapters are enabled by default.
- Astral island runtime assets are maintained as TypeScript files under `priv/islands`.

## 0.1.1 - 2026-06-26

### Added

- HEEx-first `.astral` templates for pages, layouts, and local components.
- Parser-backed `.astral` `<style>` and `<script>` extraction through Volt embedded modules.
- Example site pages, layouts, and components that dogfood `.astral` templates.

## 0.1.0 - 2026-06-25

Initial Astral development release.

### Added

- Static HTML and Markdown build pipeline.
- Elixir `astral.config.exs` site DSL.
- MDEx-backed Markdown and frontmatter support.
- EEx layouts with page, metadata, route, and site assigns.
- Per-page layout selection and layout disabling.
- Plug/Bandit development server composed with Volt.
- `mix astral.dev` and `mix astral.build` tasks.
- `Astral.asset_path/2` for Volt-managed layout assets.
- `examples/basic` runnable site with TypeScript, CSS, layouts, Markdown, public files, and Volt lint/format configuration.
- Igniter-powered starter site scaffolding through `mix astral.new`, `mix astral.install`, and `mix igniter.install astral`.
