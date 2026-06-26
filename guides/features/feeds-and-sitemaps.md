# Feeds and Sitemaps

Astral includes plugin-shaped feed and sitemap generators for static sites.

## Feed

```elixir
site do
  plugins [
    {Astral.Plugin.Feed,
     site_url: "https://example.com",
     title: "My Blog",
     author: "Astral",
     collection: :posts}
  ]
end
```

The feed plugin renders a generated route, usually `/feed.xml`, from collection entries.

## Sitemap

```elixir
site do
  plugins [
    {Astral.Plugin.Sitemap,
     site_url: "https://example.com",
     changefreq: :weekly,
     priority: fn page -> if page.route_path == "/", do: 1.0, else: 0.7 end}
  ]
end
```

The sitemap plugin renders `/sitemap.xml` from discovered and generated routes.

## Custom generated XML routes

For site-specific generated files, implement `Astral.Plugin` and return routes:

```elixir
defmodule MySite.FeedPlugin do
  @behaviour Astral.Plugin

  @impl true
  def name, do: "feed"

  @impl true
  def routes(site) do
    [Astral.Route.new("/feed.xml", site.config, content_type: "application/atom+xml")]
  end

  @impl true
  def render_route(%Astral.Route{path: "/feed.xml"}, site) do
    {:ok, MySite.Feed.render(site.entries.posts)}
  end

  def render_route(_route, _site), do: nil
end
```

Use this pattern for feeds, JSON indexes, search documents, or other static generated assets.
