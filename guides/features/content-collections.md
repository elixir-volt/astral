# Content Collections

Collections group Markdown entries such as posts, docs, changelog items, or authors.

## Define a collection

```elixir
site do
  collections do
    collection :posts, "content/posts" do
      permalink "/blog/:slug/"
      layout "post.html"

      schema %{
        required(:title) => String.t(),
        required(:date) => String.t(),
        optional(:draft) => boolean(),
        optional(:tags) => [String.t()]
      }
    end
  end
end
```

Each Markdown file in `content/posts/` becomes a validated entry and a static page at the collection permalink.

## Entry data

`entry.metadata` contains original string-keyed frontmatter. `entry.data` contains schema-normalized values:

```eex
<%= for post <- @collections.posts do %>
  <a href={post.route_path}><%= post.data.title %></a>
<% end %>
```

Collection entry layouts receive `@entry` for the current entry.

## Zoi schemas

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
