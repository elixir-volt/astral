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

Component files receive the same `assigns` map as Phoenix function components, but without requiring module boilerplate. Use `assign/3`, `assigns_to_attributes/2`, `render_slot/1`, and Phoenix's built-in `<.dynamic_tag>` for wrapper components:

```astral
<!-- components/width_wrapper.astral -->
---
assigns =
  assigns
  |> assign(:tag, assigns[:as] || "div")
  |> assign(:class, assigns[:class])
  |> assign(:rest, assigns_to_attributes(assigns, [:as, :class]))
---

<.dynamic_tag
  tag_name={@tag}
  class={[
    "px-6 sm:px-8 md:max-w-screen-md xl:max-w-screen-lg md:px-12 mx-auto",
    @class
  ]}
  {@rest}
>
  {render_slot(@inner_block)}
</.dynamic_tag>
```

```astral
<.width_wrapper as="section" id="projects" class="pt-8 pb-12 md:py-12">
  ...
</.width_wrapper>
```

This is the HEEx equivalent of Astro's `Astro.props`, `{...props}`, `<slot />`, and dynamic `<Tag>` wrapper pattern.

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

## Client islands

Astral can mount client-only framework components from Volt-managed assets. All Volt framework adapters are enabled by default; configure `islands do adapter :vue end` only when you want to restrict the allowed set.

Place the browser component under your assets directory:

```text
assets/islands/Gallery.vue
```

Then mount it from a `.astral` page or component:

```astral
<.vue
  component="islands/Gallery.vue"
  client={:load}
  props={%{images: @images}}
/>
```

Use `<.vue>`, `<.svelte>`, `<.react>`, or `<.solid>` for framework-specific islands. Supported client directives are:

- `:load` — mount as soon as the entry module runs.
- `:idle` — mount from `requestIdleCallback`, falling back to a short timeout.
- `:visible` — mount when the island enters the viewport.
- `:media` — mount only when a media query matches:

```astral
<.vue
  component="islands/Gallery.vue"
  client={:media}
  media="(min-width: 768px)"
  props={%{images: @images}}
/>
```

Props must be JSON-shaped data. Maps, lists, strings, numbers, booleans, nil, and atoms are accepted. Structs should either use `JSONCodec` or explicitly implement `Jason.Encoder`; unsupported values such as PIDs, references, and functions raise errors that include the component and prop path.

Islands can receive static HEEx children through the default framework slot/children channel. Astral keeps slot HTML separate from JSON props and passes it to the browser runtime as static HTML:

```astral
<.vue component="islands/Gallery.vue" props={%{images: @images}}>
  <div class="thumbnail-strip">
    <.image :for={image <- @images} src={image} alt="Office" height={320} />
  </div>
</.vue>
```

Astral writes a generated island entry module and Volt compiles the imported framework component, so framework compilation remains Volt-owned. The initial implementation is client-only; SSR hydration can be layered on later.

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
