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

## Configure the site

`astral.config.exs` is ordinary Elixir:

```elixir
import Astral.Config

site do
  root "."
  outdir "dist"
  pages "pages"
  public "public"
  components "components"

  layouts "layouts" do
    default "default.html"
  end
end
```

Use the configuration cheatsheet for common options. Site metadata such as titles, descriptions, canonical links, and Open Graph tags belongs in layouts or components, not global config.
