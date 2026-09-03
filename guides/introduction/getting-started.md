# Getting Started

Astral builds static sites from Elixir configuration, Markdown, HTML, and `.astral` templates. Volt handles browser assets.

## Create a project

Install Igniter's project generator, then create and configure a named Astral site in one command:

```bash
mix archive.install hex igniter_new
mix igniter.new my_site --install astral
cd my_site
```

## Add Astral to an existing project

Run the installer from the existing Mix project root:

```bash
mix igniter.install astral
```

Or add Astral and Igniter manually:

```elixir
def deps do
  [
    {:astral, "~> 0.2"},
    {:igniter, "~> 0.8", only: [:dev, :test]}
  ]
end
```

Then fetch dependencies and scaffold the site:

```bash
mix deps.get
mix astral.install
```

## Run the site

```bash
mix astral.dev
```

Open the printed local URL. The dev server serves pages, public files, Volt assets, and HMR. Use `--open` to launch a browser automatically:

```bash
mix astral.dev --open
```

## Build static output

```bash
mix astral.build
```

Astral writes static HTML and copied public files to `dist/` by default. The build prints a route table so you can see which source routes were written. Upload that directory to any static host.

To preview exactly what you last built, serve `dist/` with any static file server. Re-run `mix astral.build` after changes; a static preview does not update live like `mix astral.dev`.

For browser formatting, linting, TypeScript checks, and `import.meta.env`, see [Editor Setup and TypeScript](../features/editor-and-typescript.md) and [Environment Variables](../features/environment-variables.md).

## Starter layout

A typical project looks like this:

```text
AGENTS.md
.gitignore
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

## Configure the site

`astral.config.exs` is ordinary Elixir:

```elixir
import Astral.Config

root "."
outdir "dist"

layouts do
  default "default.html"
end

assets do
  entry "app.ts"
end
```

Use the configuration cheatsheet for common options. Site metadata such as titles, descriptions, canonical links, and Open Graph tags belongs in layouts or components, not global config.
