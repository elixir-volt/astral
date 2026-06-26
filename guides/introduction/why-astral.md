# Why Astral

Astral is a static site generator for Elixir projects. It keeps the site layer in Elixir while using Volt for frontend assets.

## Elixir site configuration

Astral uses `astral.config.exs` instead of a JavaScript config file:

```elixir
import Astral.Config

site do
  pages "pages"
  public "public"

  layouts "layouts" do
    default "default.html"
  end
end
```

Because the config is Elixir, you can share ordinary functions, modules, and data structures with the rest of your project.

## Static output

Astral builds plain files:

```text
dist/index.html
dist/about/index.html
dist/assets/manifest.json
```

There is no server runtime requirement after `mix astral.build`.

## Volt-powered assets

Astral delegates TypeScript, CSS, imported assets, dev serving, and HMR to Volt. That means the site layer does not need to become a frontend build tool.

## HEEx-first templates

`.astral` templates use Phoenix HEEx syntax for interpolation, attributes, `:if`/`:for`, components, and slots while rendering static HTML.

## Content features

Astral includes Markdown pages, schema-backed collections, static pagination, feed and sitemap plugins, generated routes, and plugin hooks for site-specific behavior.
