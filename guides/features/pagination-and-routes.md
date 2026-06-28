# Pagination and Generated Routes

Astral can add generated routes during static builds. Use top-level `get` declarations for site-specific static outputs, and plugins for reusable route generators.

## Config-declared generated routes

Declare one-off static outputs directly in `astral.config.exs`:

```elixir
site do
  get "/robots.txt", content_type: "text/plain" do
    "User-agent: *\nAllow: /\n"
  end

  get "/search-index.json", content_type: "application/json" do
    site
    |> MySite.Search.index()
    |> Jason.encode!()
  end

  get "/social-image.png", content_type: "image/png" do
    MySite.SocialImage.render_png!(site)
  end
end
```

The block runs in dev for matching requests and during static builds when Astral writes the output file. The block can use `site`, `route`, `config`, and `assigns`.

Use `plug` declarations for Plug-compatible middleware around generated responses:

```elixir
site do
  plug MySite.GeneratedRouteHeaders, cache: "public, max-age=3600"

  get "/data.json", content_type: "application/json" do
    Jason.encode!(%{ok: true})
  end
end
```

## Collection pagination plugin

```elixir
site do
  plugins [
    {Astral.Plugin.CollectionPages,
     collection: :posts,
     pattern: "/blog/*page",
     page_size: 10,
     layout: "blog.html"}
  ]
end
```

The `*page` route parameter omits page one:

```text
/blog/
/blog/2/
/blog/3/
```

The pagination layout receives `@page`, `@collection`, `@site`, `@collections`, `@routes`, and `@route`.

```eex
<h1>Blog</h1>

<%= for entry <- @page.entries do %>
  <article>
    <h2><a href="<%= entry.route_path %>"><%= entry.data.title %></a></h2>
  </article>
<% end %>

<nav>
  <%= if @page.urls.previous do %>
    <a href="<%= @page.urls.previous %>">Previous</a>
  <% end %>

  <%= if @page.urls.next do %>
    <a href="<%= @page.urls.next %>">Next</a>
  <% end %>
</nav>
```

## Lower-level pagination helpers

Use `Astral.Pagination` directly for custom generated indexes:

```elixir
entries
|> Astral.Pagination.pages(pattern: "/blog/*page", page_size: 10)
|> Astral.Pagination.routes(site.config, assigns: %{collection: :posts})
```

## Route patterns

Astral route patterns use Plug/Phoenix-style segments:

```text
/blog/:slug
/blog/*page
/tags/:tag/*page
```

Use generated routes when a page is not backed by a single file in `pages/`.

Generated routes are rendered after ordinary pages during static builds. If a generated route writes the same output path as a page or public file, the generated route wins. Prefer unique output paths unless the override is intentional.
