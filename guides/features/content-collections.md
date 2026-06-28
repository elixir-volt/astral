# Content Collections

Collections group Markdown entries such as posts, docs, changelog items, or authors.

## Define a collection

```elixir
site do
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
end
```

Each Markdown file in `content/posts/` becomes a validated entry and a static page at the collection permalink. The `schema do` field DSL mirrors Ecto's field shape; Astral uses Ecto casting behind the scenes for types, required fields, defaults, and image source resolution.

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
  <p>Slug: {@params["slug"]}</p>
</article>
```

Nested collection slugs can use a glob route:

```text
content/docs/guide/intro.md
pages/docs/[...path].md
```

Use `@params["path"]` to read the captured path.

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

Tags and categories are userland. If your site needs tag pages, build them from collection data and generated routes.
