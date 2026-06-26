# Plugins

Astral plugins extend static site discovery, rendering, and build lifecycle behavior.

## Configure plugins

```elixir
site do
  plugins [
    MySite.SEOPlugin,
    {MySite.AnalyticsPlugin, id: "G-XXXX"}
  ]
end
```

Plugins are modules implementing `Astral.Plugin`. Tuple options are passed to callbacks that define an extra argument.

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
