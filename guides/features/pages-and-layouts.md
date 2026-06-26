# Pages and Layouts

Astral discovers pages from the configured `pages/` directory and renders them into static HTML routes.

## Markdown pages

Markdown pages use MDEx and YAML frontmatter:

```markdown
---
title: About
layout: default.html
---

# About
```

Routes are derived from file paths:

```text
pages/index.md      -> /
pages/about.md      -> /about/
pages/blog/post.md  -> /blog/post/
```

Set `permalink` to override the route:

```markdown
---
title: About
permalink: /about-us/
---
```

Set `layout: false` to render a page without a layout.

## HTML pages

Plain `.html` files in `pages/` are supported for pages that do not need Markdown processing.

## Layouts

Layouts live in the configured layouts directory. EEx layouts use `@content` where the page HTML should be inserted:

```html
<!doctype html>
<html lang="en">
  <head>
    <title><%= @page.title || "My Site" %></title>
  </head>
  <body>
    <main data-route="<%= @route %>">
      <%= @content %>
    </main>
  </body>
</html>
```

Common assigns:

- `@content` — rendered page HTML.
- `@page` — current `%Astral.Content{}`.
- `@metadata` — decoded frontmatter map.
- `@route` — route path such as `/about/`.
- `@site` — discovered `%Astral.Site{}`.
- `@collections` — content entries grouped by collection name.
- `@entry` — current collection entry, otherwise `nil`.
- `@routes` — generated routes.

## Heading anchors

Markdown headings get stable `id` attributes. Heading metadata is available as `@page.headings` for table-of-contents layouts:

```eex
<nav>
  <%= for heading <- @page.headings do %>
    <a href="#<%= heading.id %>"><%= heading.text %></a>
  <% end %>
</nav>
```
