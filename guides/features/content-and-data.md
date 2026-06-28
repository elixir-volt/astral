# Markdown, Content, and Data Fetching

Astral supports Markdown pages, Markdown-backed content collections, `.astral` templates, and build-time Elixir data loading. This guide maps Astro's Markdown, content collection, and data-fetching features to Astral's current APIs.

## Markdown pages

Markdown files in `pages/` become routes:

```text
pages/index.md      -> /
pages/about.md      -> /about/
pages/blog/post.md  -> /blog/post/
```

Use YAML frontmatter for page metadata and route options:

```md
---
title: About
layout: default.html
permalink: /about-us/
---

# About
```

Astral uses MDEx for Markdown and `YamlElixir` for frontmatter. TOML frontmatter is not supported today.

## Components in Markdown

Markdown pages and collection entries can use local `.astral` components through HEEx syntax:

```md
# Project

<.callout>
  Rendered by `components/callout.astral`.
</.callout>
```

Use local component calls such as `<.callout>`, not MDX imports. MDX/JSX expressions are not currently supported in Astral Markdown.

Assigns are available with HEEx expression syntax:

```md
<p>{@metadata["title"]}</p>
<p>{@entry.data.title}</p>
```

Prefer static Markdown heading text. Heading IDs and `@page.headings` are generated before HEEx expressions are evaluated.

## Rendering Markdown content

Collection detail pages can render the current entry's already-rendered Markdown safely:

```astral
<article>
  <h1>{@entry.data.title}</h1>
  {@entry.content}
</article>
```

`@entry.content` implements Phoenix's HTML-safe protocol. Prefer this over raw string injection.

Astral does not currently expose Astro-style Markdown file imports, `compiledContent()`, `rawContent()`, `<Content />`, or `import.meta.glob()` for Markdown. Use collection helpers, ordinary Elixir file APIs, or Volt browser imports depending on the layer you are working in.

## Content collections today

Define local Markdown collections in `astral.config.exs`:

```elixir
collections do
  collection :posts, "content/posts" do
    permalink "/blog/:slug/"
    layout "post.html"

    schema do
      field :title, :string, required: true
      field :date, :date, required: true
      field :draft, :boolean, default: false
      field :tags, {:array, :string}, default: []
    end
  end
end
```

Each Markdown file becomes a schema-normalized entry. Use `entry.data` for cast atom-keyed values and defaults; `entry.metadata` remains the original string-keyed frontmatter.

Current helper behavior is source-backed and intentionally documented here: `Astral.Collection.tags/1` reads normalized `entry.data[:tags]`, while `published/1` and `sort_by_date/2` currently inspect raw frontmatter metadata (`"draft"`, `"updated"`, and `"date"`). Prefer `entry.data` in your own layouts, pages, feeds, and generated routes when you need schema defaults or cast values.

Query collections from `.astral` setup blocks, layouts, generated routes, or plugins:

```astral
---
posts =
  @site
  |> Astral.Collection.entries(:posts)
  |> Astral.Collection.published()
  |> Astral.Collection.sort_by_date(:desc)

assigns = assign(assigns, :posts, posts)
---

<ul>
  <li :for={post <- @posts}>
    <a href={post.route_path}>{post.data.title}</a>
  </li>
</ul>
```

Astral does not yet provide Astro's content-loader system, single-file JSON/YAML/TOML collection loaders, collection references, generated TypeScript types, live collections, or request-time collection queries.

## Generated routes from content

For one page per collection entry, use a collection `permalink` and optional matching dynamic `.astral` file route:

```text
content/posts/hello.md     -> /blog/hello/
pages/blog/[slug].astral   -> /blog/:slug
```

For arbitrary derived routes such as tag pages, use setup-declared dynamic `.astral` paths:

```astral
---
posts = Astral.Collection.entries(@site, :posts)

paths =
  for tag <- Astral.Collection.tags(posts) do
    matching = Enum.filter(posts, &(tag in &1.data.tags))
    path tag: tag, assigns: %{posts: matching}
  end
---

<h1>{@params["tag"]}</h1>
```

This is the current Astral equivalent of Astro's build-time static path generation, expressed as Elixir data in the page that owns the route.

## Build-time data fetching

In static output mode, data loaded during discovery or rendering is build-time data. Use ordinary Elixir libraries such as `Req`, `File`, `Path`, `Jason`, database clients, or service SDKs in setup blocks, config-generated routes, or plugins.

Example one-off JSON output from fetched data:

```elixir
get "/products.json", content_type: "application/json" do
  products = Req.get!("https://api.example.com/products").body
  Jason.encode!(products)
end
```

Example page setup data:

```astral
---
response = Req.get!("https://api.example.com/status")
assigns = assign(assigns, :status, response.body)
---

<p>{@status["message"]}</p>
```

During a static build, this runs when the page or route is generated. During development, it runs when Astral renders the page or generated route. Do not put secrets in browser assets; use server-side Elixir environment access for build-time data and Volt `import.meta.env` only for public browser values.

## Remote content and CMS data

Astral does not yet have a first-class remote content loader API. For CMS or API content today, choose the shape that matches your site:

- fetch data in a plugin during discovery and add generated routes,
- fetch inside a config-level `get` route for static JSON, feeds, indexes, or generated images,
- fetch in `.astral` setup for small page-local build-time data,
- materialize remote content into Markdown or data files before running `mix astral.build`.

Live content collections and request-time data freshness belong with future hybrid/runtime modes.
