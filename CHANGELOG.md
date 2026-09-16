# Changelog

## Unreleased

## 0.3.2 - 2026-09-16

### Added

- Add site-scoped `markdown` options for MDEx rendering across pages, collections, and feeds, including optional Lumis syntax highlighting with light/dark themes.
- Add `Astral.Formatter` for `mix format`: format Elixir setup blocks, HEEx templates, and embedded JavaScript/TypeScript through Volt. The installer configures the plugin and `.astral` inputs for new and existing projects.

### Fixed

- Preserve whitespace between highlighted code tokens and inline elements when injecting the development HMR client.

## 0.3.1 - 2026-09-15

### Added

- Add `Astral.Plugin.LLMs` for metadata-driven `llms.txt` generation in builds and development, with automatic discovery, exclusions, curated sections, and external links. New starters enable it with the project title.

### Fixed

- Include Volt's shared browser declarations in starter TypeScript configurations instead of generating application-local `ImportMeta` definitions.

## 0.3.0 - 2026-09-15

### Breaking changes

- Require explicit `islands do component :vue, "path.vue" end` declarations for runtime-selected components that cannot be discovered from literal template references.

### Changed

- Replace generated TypeScript island files in `assets/.astral/islands` with shared virtual component entries; serialize instance props and hydration settings in HTML.
- Compose development assets through one supervised Volt session and use Volt's complete production build API.
- Normalize configured asset entries to lists and support multiple entries.
- Build browser assets before rendering documents so asset URLs can be used in HTML, island props, and generated data routes without rendering pages twice.

### Fixed

- Include production island stylesheet dependencies in the active document head, including dependencies first encountered inside inert slot templates.
- Mount late-appearing nested islands when another instance has already loaded their shared component entry.
- Respect explicitly disabled Tailwind configuration during builds and development startup.
- Reject colliding destinations within pages or generated routes instead of silently overwriting documents, while preserving generated-route precedence over pages.
- Coordinate concurrent first renders of a template so requests do not fail while its module is being compiled.
- Resolve component-relative SVG references from the component file while preserving the caller's source context in slots.

### Security

- Require Bandit 1.12.5 or later to address HTTP/2 header validation and connection-window starvation (CVE-2026-75484, CVE-2026-74836).
- Require Igniter 0.8.4 or later to prevent terminal escape injection through package metadata in installer confirmation prompts (CVE-2026-82584).
- Reject symlinked document and image destinations, including copied public links, to prevent generated output from writing outside the output directory.
- Reject symlinked output-directory parents within the project before clearing the previous build.

### Compatibility

- Require Volt 0.18 for the shared build and supervised development-session APIs.

## 0.2.6 - 2026-09-04

### Fixed

- Exclude generated `assets/.astral/` browser entries from the formatter configuration created by the Astral installer.

## 0.2.5 - 2026-09-04

### Fixed

- Prevent generated client-island entries from causing repeated full-page reloads in the development server.

### Changed

- Update Volt to 0.17.11 for configurable watcher exclusions and normalized filesystem events.

## 0.2.4 - 2026-09-03

### Added

- Added Astral- and Volt-focused `AGENTS.md` guidance to starter projects while preserving existing project instructions.
- Added starter `.gitignore` coverage for static output, browser dependencies, generated island entries, and local environment files.

### Changed

- Starter pages, layouts, and generated README files now use the Mix application name instead of generic Astral branding.
- Replaced Mix's placeholder README in new sites with concise Astral development and build instructions while preserving existing project documentation.
- Updated setup documentation with the one-command `mix igniter.new my_site --install astral` project creation flow.

## 0.2.3 - 2026-07-10

### Added

- Added nested hydrated island support for islands rendered inside another island's slot.
- Hardened island tests for nested JSON-safe props, repeated same-component mounts, async mount idempotency, and static browser integration coverage.

### Fixed

- Reused content-addressed compiled template modules instead of creating a new BEAM module and atom on every render.
- Hardened public-file, image-cache, island-component, page, plugin-route, and output-directory path boundaries.
- Prevented unsafe explicit island IDs and collisions between explicit and generated island IDs.
- Made `client={:media}` islands hydrate when their media query starts matching after page load.
- Made React island mounts synchronous so nested island entry scripts are activated reliably.
- Made `mix astral.dev` reject invalid command-line options consistently with `mix astral.build`.

## 0.2.2 - 2026-07-07

### Added

- Documented and tested mixed Vue, Svelte, React, and Solid islands on the same page, including repeated same-framework islands and mixed client directives.
- Added Solid island build support using `.solid.jsx` and `.solid.tsx` component filenames.

### Changed

- Production island assets now build as ES modules and share common framework/runtime chunks through Volt 0.15.5.
- Moved island browser tests under `test/astral/islands/browser/` and added Elixir build/integration coverage for mixed framework islands.
- Updated Volt to 0.15.5.

## 0.2.1 - 2026-07-06

### Added

- Added Volt browser tests for island runtime behavior and framework adapters across React, Vue, Solid, and Svelte.

### Changed

- Updated Volt to 0.15.2 for package import specifier resolution used by Svelte's browser runtime internals.

## 0.2.0 - 2026-06-29

### Changed

- Rebuilt the configuration DSL on the shared `dsl` package while preserving existing `site do ... end` syntax and generated route behavior.

## 0.1.8 - 2026-06-29

### Fixed

- Preserved external `<script src="...">` tags in `.astral` templates while still extracting inline script blocks into Volt modules.

## 0.1.7 - 2026-06-28

### Changed

- Replaced the `collections do ... end` config wrapper with top-level `collection` declarations.

## 0.1.6 - 2026-06-28

### Changed

- Replaced the top-level `plugins [...]` config declaration with singular `plugin` declarations for cleaner config files.

## 0.1.5 - 2026-06-28

### Changed

- Dynamic route params rendered in `@params` are now atom-keyed, matching setup-declared route params and schema-normalized entry data.

## 0.1.4 - 2026-06-28

### Added

- Top-level `astral.config.exs` declarations for site configuration, preserving legacy `site do ... end` support.

### Changed

- Starter scaffolding, the basic example, and documentation now use the top-level config style.

## 0.1.3 - 2026-06-28

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
