# Content Collections

Collections group Markdown entries such as posts, docs, changelog items, or authors. See the Markdown, content, and data guide for the broader boundary around Astro-style Markdown imports, loaders, data fetching, and live collections.

## Define a collection

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
      field :cover, :image
    end
  end
end
```

Each Markdown file in `content/posts/` becomes a validated entry and a static page at the collection permalink. The `schema do` field DSL mirrors Ecto's field shape; Astral uses Ecto casting behind the scenes for types, required fields, defaults, and image source resolution. Declare a schema when you want fields in `entry.data`; collections without a schema expose `%{}` as normalized data while preserving raw frontmatter in `entry.metadata`. Astral's current collections are local Markdown collections; Astro-style content loaders, single-file JSON/YAML/TOML loaders, collection references, generated TypeScript types, and live collections are not implemented yet.

## Schema defaults

Field defaults are applied to `entry.data` during schema normalization:

```elixir
schema do
  field :title, :string, required: true
  field :draft, :boolean, default: false
  field :tags, {:array, :string}, default: []
end
```

A post with only a title:

```yaml
---
title: Hello
---
```

is exposed as normalized data with defaults:

```elixir
%{title: "Hello", draft: false, tags: []}
```

`entry.metadata` remains the original string-keyed frontmatter map. `entry.data` contains schema-declared fields only. Use `entry.data` in layouts, pages, feeds, generated routes, and collection helpers when you want cast values and defaults.

Image fields resolve local paths relative to the entry file and expose an `Astral.Image.Source` struct:

```yaml
---
title: Hello
cover: ./cover.jpg
---
```

Use image fields directly with Astral image components:

```astral
<.image src={@entry.data.cover} alt={@entry.data.title} width={800} />
```

## Entry data

`entry.metadata` contains original string-keyed frontmatter. `entry.data` contains schema-normalized values:

```eex
<%= for post <- @collections.posts do %>
  <a href={post.route_path}><%= post.data.title %></a>
<% end %>
```

Collection entry layouts receive `@entry` for the current entry.

## Dynamic detail pages

By default, collection entries render their own Markdown body through the configured layout. Add a matching dynamic file route when you want a page template to own the detail page HTML:

```text
content/posts/hello.md
pages/blog/[slug].astral
```

The dynamic page route matches the collection permalink `/blog/:slug/` and receives `@entry` plus string-keyed route params. Render the entry body directly with `{@entry.content}`; Astral content implements Phoenix's HTML-safe protocol, so already-rendered Markdown and Markdown components are not escaped:

```astral
<article>
  <h1>{@entry.data.title}</h1>
  {@entry.content}
  <p>Slug: {@params.slug}</p>
</article>
```

Nested collection slugs can use a glob route:

```text
content/docs/guide/intro.md
pages/docs/[...path].md
```

Use `@params.path` to read the captured path.

## Components in collection Markdown

Collection Markdown can use local `.astral` components with HEEx syntax:

```md
# {@entry.data.title}

<.callout>
  Rendered from collection Markdown.
</.callout>
```

This is Astral's Markdown-component path. Use local component syntax (`<.callout>`) instead of MDX imports.

## JSONSpec and Zoi schemas

JSONSpec-style typespec maps are also supported:

```elixir
collection :posts, "content/posts" do
  schema %{
    required(:title) => String.t(),
    required(:date) => String.t(),
    optional(:draft) => boolean()
  }
end
```

Use Zoi when runtime coercion or refinements are useful:

```elixir
collection :posts, "content/posts" do
  schema Zoi.map(%{
    title: Zoi.string(),
    tags: Zoi.array(Zoi.string()) |> Zoi.optional()
  }, coerce: true)
end
```

## Collection helpers

Astral includes helpers for common entry filtering and sorting:

```elixir
posts =
  @site
  |> Astral.Collection.entries(:posts)
  |> Astral.Collection.published()
  |> Astral.Collection.sort_by_date(:desc)
```

Tags and categories are userland. If your site needs tag pages, build them from schema-normalized `entry.data` and dynamic pages instead of waiting for a core taxonomy abstraction. Declare fields such as `tags` in your collection schema so helpers can use normalized atom-keyed data.

For a tag index page, ordinary `.astral` pages can read collection data directly:

```astral
---
posts = Astral.Collection.entries(@site, :posts)
assigns = assign(assigns, :tags, Astral.Collection.tags(posts))
---

<ul>
  <li :for={tag <- @tags}>
    <a href={"/tags/#{tag}/"}>{tag}</a>
  </li>
</ul>
```

For one generated page per tag, create a dynamic `.astral` page and declare its `paths` in the setup block:

```astral
---
posts = Astral.Collection.entries(@site, :posts)

paths =
  for tag <- Astral.Collection.tags(posts) do
    posts_for_tag = Enum.filter(posts, &(tag in &1.data.tags))
    path tag: tag, assigns: %{posts: posts_for_tag}
  end
---

<h1>{@params.tag}</h1>
<ul>
  <li :for={post <- @posts}>
    <a href={post.route_path}>{post.data.title}</a>
  </li>
</ul>
```

Save this as `pages/tags/[tag].astral`. Each item in `paths` is an `Astral.Route.Path` contract produced by `path/1`, not an arbitrary map. The `path/1` params, rendered `@params`, and page assigns all use atom keys.
