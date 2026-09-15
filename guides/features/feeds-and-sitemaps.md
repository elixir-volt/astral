# Feeds and Sitemaps

Astral ships built-in plugins for feed and sitemap generation in static sites.

## Feed

```elixir
plugin Astral.Plugin.Feed,
  site_url: "https://example.com",
  title: "My Blog",
  author: "Astral",
  collection: :posts
```

The feed plugin renders a generated route, usually `/feed.xml`, from collection entries. It reads entry titles, dates, descriptions, authors, and draft status from schema-normalized `entry.data`, so declare those fields in the collection schema when you want them in feeds.

## Sitemap

```elixir
plugin Astral.Plugin.Sitemap,
  site_url: "https://example.com",
  changefreq: :weekly,
  priority: fn page -> if page.route_path == "/", do: 1.0, else: 0.7 end
```

The sitemap plugin renders `/sitemap.xml` from discovered and generated routes. For collection entry pages, default `<lastmod>` uses schema-normalized `entry.data[:updated]` or `entry.data[:date]`; standalone pages use their page frontmatter metadata.

## llms.txt

Generate a metadata-only index following the [llms.txt proposal](https://llmstxt.org/):

```elixir
plugin Astral.Plugin.LLMs,
  site_url: "https://example.com",
  title: "My Site",
  description: "Documentation and news about the project."
```

By default, `/llms.txt` contains a single “Pages” section with links in URL order.
Titles and optional descriptions come from page metadata or normalized collection
entry data. Without a title, the first level-one Markdown heading is used, then
the route path (`Home` for `/`). Site identity is explicit, not guessed from HTML
or the Mix application name. Without `site_url`, URLs are root-relative; the
starter uses this mode until you configure your deployment URL.

Drafts, error pages, non-HTML outputs, and pages declaring `noindex: true`,
`robots: "noindex"`, or `llms: false` in metadata are omitted. Use `exclude: ["/legal/"]`
for additional route exclusions. Generated routes override source pages at the
same output destination, matching normal build behavior. Generated HTML routes
can provide titles and descriptions through their `metadata` map.

For larger sites, curate sections without duplicating link metadata:

```elixir
plugin Astral.Plugin.LLMs,
  title: "My Site",
  sections: [
    {"Start here", ["/", "/about/"]},
    {"Writing", [{:collection, :posts}]},
    {"Optional", [
      %{url: "/legal/", title: "Legal information"},
      %{url: "https://github.com/example/project", title: "Source code"}
    ]}
  ]
```

Sections replace automatic selection. Their order and explicit link order are
preserved; collection selections are sorted by URL. Map selectors can override
`:title` and `:description`; external links require an explicit title. Unknown
local routes and collections raise errors. Exclusions still apply to curated
sections. Empty sections are omitted, and `sections: []` produces only site identity.

The same generated route works in static builds and development. Only `llms.txt`
is produced: no page-body rendering or conversion, Markdown alternates, or
`llms-full.txt` dumps. This index is discovery guidance, not crawler permissions
or access control; `robots.txt` remains separate.

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

Use this pattern for feeds, JSON indexes, search documents, or other static generated assets. Prefer `entry.data` for schema-normalized collection values and `entry.metadata` only when you intentionally need raw frontmatter.
