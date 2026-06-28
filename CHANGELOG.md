# Changelog

## Unreleased

### Added

- Static HEEx children for client islands, passed to framework runtimes through the default slot/children channel.
- Server-rendered Iconify icons through PhoenixIconify's `<.icon>` component in `.astral` templates.
- Inline local SVG files through `<.svg src="..." />`, resolved with Volt asset aliases and rendered as HTML-safe SVG.
- Phoenix-shaped `get` declarations in `astral.config.exs` for one-off generated static routes, with Plug-compatible middleware via `plug`.
- A userland head metadata component pattern in the basic example and pages/layouts guide.

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
