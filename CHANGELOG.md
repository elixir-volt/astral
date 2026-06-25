# Changelog

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
