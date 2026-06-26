# Pagination and Generated Routes

Astral plugins can add generated routes during static builds. Built-in pagination helpers cover common collection index pages.

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
