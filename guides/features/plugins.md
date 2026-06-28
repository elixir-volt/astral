# Plugins and Integrations

Astral plugins extend static site discovery, rendering, and build lifecycle behavior. Volt plugins extend the browser asset graph. Together they cover the same broad territory that Astro calls integrations, but the responsibilities are split by layer.

Use an **Astral plugin** for site semantics:

- generated routes such as feeds, sitemaps, search indexes, and API-like static files,
- content or route discovery changes,
- rendered HTML transforms,
- build lifecycle hooks.

Use a **Volt plugin** or Volt config for browser assets:

- JavaScript, TypeScript, CSS, and imported assets,
- Vue, React, Svelte, Solid, and other framework compilation,
- virtual browser modules and entries,
- compile-time constants and `import.meta.env`,
- asset HMR and production bundling.

## Configure plugins

```elixir
plugin MySite.SEOPlugin
plugin MySite.AnalyticsPlugin, id: "G-XXXX"
```

Plugins are modules implementing `Astral.Plugin`. Options are passed to callbacks that define an extra argument.

## Render hook example

```elixir
defmodule MySite.AnalyticsPlugin do
  @behaviour Astral.Plugin

  @impl true
  def name, do: "analytics"

  @impl true
  def render_page(html, _page, _site, opts) do
    id = Keyword.fetch!(opts, :id)
    {:ok, String.replace(html, "</body>", ~s(<script data-id="#{id}"></script></body>))}
  end
end
```

## Generated route example

```elixir
defmodule MySite.SearchIndex do
  @behaviour Astral.Plugin

  @impl true
  def name, do: "search-index"

  @impl true
  def routes(site) do
    [Astral.Route.new("/search.json", site.config, content_type: "application/json")]
  end

  @impl true
  def render_route(%Astral.Route{path: "/search.json"}, site) do
    entries = Map.get(site.entries, :posts, [])
    {:ok, JSON.encode!(Enum.map(entries, &%{title: &1.data.title, url: &1.route_path}))}
  end

  def render_route(_route, _site), do: nil
end
```

## Config-generated routes

For one-off static outputs, prefer top-level `get` declarations in `astral.config.exs` instead of writing a reusable plugin:

```elixir
get "/robots.txt", content_type: "text/plain" do
  "User-agent: *\nAllow: /\n"
end

get "/search-index.json", content_type: "application/json" do
  Jason.encode!(MySite.Search.index(site))
end
```

Use `plug` for middleware around these generated responses:

```elixir
plug MySite.GeneratedHeaders, cache: "public, max-age=3600"
```

## Framework and asset integrations

Frontend frameworks are configured through Volt and Astral islands, not Astral site plugins. The basic example enables Vue and React with Volt plugins:

```elixir
# config/config.exs
config :volt,
  plugins: [Volt.Plugin.Vue, Volt.Plugin.React],
  import_source: "react"
```

Then `.astral` pages can mount client islands:

```astral
<.vue component="islands/Gallery.vue" client={:visible} props={%{title: "Gallery"}} />
<.react component="islands/ReactCounter.jsx" client={:load} props={%{count: 1}} />
```

See the assets, islands, and Volt plugin documentation when the integration affects browser code rather than site discovery or rendering.

## Installation and scaffolding

Astral does not currently have an `astro add`-style command for arbitrary integrations. Use normal Mix and Hex workflows:

- install Astral in a project with `mix igniter.install astral`,
- scaffold starter files with `mix astral.new`,
- add Elixir packages to `mix.exs`,
- add browser packages to `package.json` only when your chosen Volt/browser tooling needs them,
- configure Astral plugins in `astral.config.exs` and Volt plugins in `config/config.exs`.

## Hooks

Available hooks include:

- `config/1`
- `build_start/1`
- `site_discovered/1`
- `routes/1`
- `render_route/2`
- `render_page/3`
- `build_done/1`

Use `enforce/0` to return `:pre` or `:post` when ordering matters.
