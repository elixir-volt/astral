# `.astral` Templates

`.astral` files are HEEx-first static templates. They can be used as pages, layouts, and local components.

## Components

Place local components under the configured component directory, `components/` by default:

```astral
<!-- components/pill.astral -->
<span class="pill">
  {render_slot(@inner_block)}
</span>
```

Use local components with HEEx syntax:

```astral
<.pill>Elixir</.pill>
```

## Pages

`.astral` pages live in `pages/`:

```astral
---
assigns = assign(assigns, :title, "Home")
---

<h1>{@title}</h1>
<.pill>Static HTML</.pill>
```

The setup block is Elixir. It receives `assigns` and should return updated assigns when adding values.

## Layouts

`.astral` layouts receive the same assigns as EEx layouts:

```astral
<!doctype html>
<html lang="en">
  <body>
    <main data-route={@route}>{@content}</main>
  </body>
</html>
```

## HEEx syntax

Use Phoenix HEEx conventions:

```astral
<h1>{@title}</h1>

<ul>
  <li :for={item <- @items}>{item}</li>
</ul>

<p :if={@draft}>Draft</p>
```

Slots use HEEx slot rendering:

```astral
<div class="card">
  {render_slot(@inner_block)}
</div>
```

## Browser assets

`<style>` and `<script>` blocks are extracted into Volt's asset graph:

```astral
<style>
  .hero { padding: 4rem; }
</style>

<script lang="ts">
  document.querySelector(".hero")?.classList.add("ready");
</script>
```

Astral removes those blocks from the server-rendered HTML template. Volt builds and serves them as first-class browser modules.
