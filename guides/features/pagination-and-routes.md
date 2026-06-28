# Routing, Pagination, and Generated Routes

Astral uses file-based routes for pages and generated routes for non-page outputs. Use dynamic `.astral` pages when one template should produce several HTML pages, top-level `get` declarations for site-specific static outputs, and plugins for reusable route generators.

## File-based page routes

Files under `pages/` become routes automatically:

```text
pages/index.md              -> /
pages/about.md             -> /about/
pages/about/index.astral   -> /about/
pages/docs/intro.html      -> /docs/intro/
pages/404.astral           -> /404/ and dist/404.html
```

Use ordinary `<a>` elements for navigation:

```astral
<a href="/about/">About</a>
```

See the navigation guide for current i18n, prefetch, and view-transition boundaries.

Dynamic filenames use Astro-style brackets at the file boundary and Plug/Phoenix-style route params internally:

```text
pages/blog/[slug].astral   -> /blog/:slug
pages/docs/[...path].md    -> /docs/*path
```

Rendered params are available as string-keyed `@params`:

```astral
<h1>{@params["slug"]}</h1>
```

## Collection-backed dynamic pages

If a dynamic page matches collection entry routes, Astral renders one page per matching entry and assigns `@entry`:

```text
content/posts/hello.md     -> /blog/hello/
pages/blog/[slug].astral   -> /blog/:slug
```

```astral
<article data-slug={@params["slug"]}>
  <h1>{@entry.data.title}</h1>
  {@entry.content}
</article>
```

`@entry.content` implements Phoenix's HTML-safe protocol. Use a collection schema for fields you read from `@entry.data`; raw frontmatter remains available as string-keyed `@entry.metadata`.

## Setup-declared dynamic `.astral` pages

A dynamic page filename such as `pages/tags/[tag].astral` declares a route pattern. In the setup block, assign `paths` to a list of route path contracts with `path/1`:

```astral
---
posts = Astral.Collection.entries(@site, :posts)

paths =
  for tag <- Astral.Collection.tags(posts) do
    posts_for_tag = Enum.filter(posts, &(tag in &1.data.tags))
    path tag: tag, assigns: %{posts: posts_for_tag}
  end
---

<h1>{@params["tag"]}</h1>
<ul>
  <li :for={post <- @posts}>{post.data.title}</li>
</ul>
```

The setup `paths` list is evaluated during discovery. Each `path/1` item carries atom-keyed route params plus optional atom-keyed page assigns. Astral generates concrete routes such as `/tags/elixir/` and makes rendered params available as string-keyed `@params` for template compatibility.

## Static endpoints with generated routes

For static data files and endpoint-like outputs, declare one-off generated routes directly in `astral.config.exs`:

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

Generated routes are static-build endpoints: they produce files such as `/search-index.json`, `/feed.xml`, `/sitemap.xml`, `/robots.txt`, or generated images. Astral does not yet provide live server API routes for `POST`, `PUT`, `DELETE`, or request-body handling; those belong to a future runtime/hybrid adapter.

Use `plug` declarations for Plug-compatible middleware around generated responses:

```elixir
site do
  plug MySite.GeneratedRouteHeaders, cache: "public, max-age=3600"

  get "/data.json", content_type: "application/json" do
    Jason.encode!(%{ok: true})
  end
end
```

This `plug` support is intentionally scoped to config-generated routes. It is not full page middleware: it does not run around every page render and does not provide per-request locals for ordinary static pages.

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

The pagination layout receives `@page`, `@collection`, `@site`, `@collections`, `@routes`, and `@route`. Declare a collection schema for any fields you read through `entry.data`, such as `entry.data.title` below.

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

## Output precedence

Astral writes static output in deterministic layers:

```text
public files < pages < generated routes
```

If a generated route writes the same output path as a page or public file, the generated route wins. Prefer unique output paths unless the override is intentional.

Astral reports duplicate page routes. Broader output-conflict diagnostics for public files and generated routes are planned.

## Redirects, rewrites, i18n, and middleware scope

Astral does not yet have core redirect or rewrite rules. For static redirects today, use your host's redirect configuration or generate host-specific files with `get` routes or plugins.

Astral also does not yet have first-class i18n routing middleware. Use localized folders, collection locale fields, and site-owned link helpers for static multilingual sites today. Locale fallbacks, domain-based locales, browser-language detection, and route verification belong with future runtime/hybrid routing work.

Full page middleware is not implemented yet. Current middleware-like support is limited to `plug` declarations around config-generated routes. Use the `render_page` plugin callback for build-time HTML transforms across rendered pages. See the server runtime guide for the current on-demand rendering, action, session, and route caching boundaries.
