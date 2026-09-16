# `.astral` Templates

## Formatting

Astral integrates with the normal Elixir formatting pipeline. The installer adds
`Astral.Formatter` and template inputs to `.formatter.exs`; existing projects can
add them explicitly:

```elixir
[
  plugins: [Astral.Formatter, Volt.Formatter],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}",
    "{pages,layouts,components}/**/*.astral",
    "assets/**/*.{js,ts,jsx,tsx}"
  ],
  excludes: ["assets/.astral/**/*"]
]
```

Run `mix format` to apply formatting or `mix format --check-formatted` in CI.
The formatter uses the same setup-block boundary as Astral's renderer. It formats
setup code with Elixir, the template body with Phoenix's HEEx formatter, and
inline JavaScript/TypeScript scripts through Volt. HEEx options such as
`:heex_line_length`, `:attribute_formatters` and `:tag_formatters` pass through;
an explicit script tag formatter overrides Volt's default adapter.

CSS styles, external scripts and non-JavaScript data scripts are preserved rather
than sent to a JavaScript formatter. Markdown is not claimed by this plugin.


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

## Icons

Astral imports PhoenixIconify's `<.icon>` component into `.astral` templates. Use Iconify's `prefix:name` format and normal HEEx attributes:

```astral
<.icon name="ri:external-link-fill" class="inline-block mb-0.5" width="12" height="12" />
```

Astral prepares the PhoenixIconify manifest during `mix astral.build` and development rendering, so sites do not need to add the `:phoenix_iconify` Mix compiler manually. Configure icon discovery at the intent level when needed:

```elixir
config :phoenix_iconify,
  source_globs: [
    "pages/**/*.astral",
    "components/**/*.astral",
    "layouts/**/*.astral",
    "content/**/*.md"
  ],
  extra_icons: ["ri:external-link-fill"]
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

Astral discovers literal component references in `.astral` and Markdown sources
without executing their setup or render code. Volt builds the corresponding
virtual modules before document rendering. Each document includes the stylesheets
required by its islands, with shared dependencies deduplicated.

For components selected at render time, declare all possible entries explicitly:

```elixir
islands do
  component :vue, "islands/Gallery.vue"
  component :vue, "islands/CompactGallery.vue"
end
```

Then a template can select one with `component={@gallery_component}`. The keyword
configuration equivalent is `islands: [component: {:vue, "islands/Gallery.vue"}]`.
Components invoked from arbitrary Elixir helpers also need explicit declarations.
An undeclared runtime-selected component raises a build error.

Islands are client-only. Keep essential static content outside the island so it
remains available without JavaScript; slot templates are inert until mounting.

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

Astral removes those blocks from the server-rendered HTML template. Volt builds and serves them as first-class browser modules. See the styling and browser code guide for details on how this differs from Astro's scoped styles, script processing, fonts, syntax highlighting, and framework components.
