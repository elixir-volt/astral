# Getting Started

Astral builds static sites from Elixir configuration, Markdown, HTML, and `.astral` templates. Volt handles browser assets.

## Install

```bash
mix igniter.install astral
```

Or add the dependency manually:

```elixir
def deps do
  [{:astral, "~> 0.1.1"}]
end
```

Then scaffold a starter site:

```bash
mix astral.new
```

## Run the site

```bash
mix astral.dev
```

Open the printed local URL. The dev server serves pages, public files, Volt assets, and HMR.

## Build static output

```bash
mix astral.build
```

Astral writes static HTML and copied public files to `dist/` by default. Upload that directory to any static host.

## Starter layout

A typical project looks like this:

```text
astral.config.exs
pages/
  index.md
layouts/
  default.html
assets/
  app.ts
  styles.css
public/
  robots.txt
```

Add Markdown or `.astral` files under `pages/`. Add layouts under `layouts/`. Configure assets under `assets/` and reference them with `Astral.asset_path/2`.
