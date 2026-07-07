# Styling, Fonts, Scripts, and Frameworks

Astral keeps document rendering in Elixir and delegates browser assets to Volt. This guide maps Astro's styling, font, script, syntax-highlighting, and frontend-framework features to Astral's current APIs.

## CSS and styles

Use Volt-managed CSS for site-wide styles:

```elixir
assets do
  entry "app.ts"
  url_prefix "/assets"
end
```

```ts
// assets/app.ts
import "./styles.css";
```

Reference the asset entry from a layout:

```eex
<script type="module" src="<%= Astral.asset_path(@site, "app.ts") %>"></script>
```

You can also place a `<style>` block directly in a `.astral` page, layout, or component:

```astral
<style>
  .hero { padding: 4rem; }
</style>
```

Astral extracts `.astral` `<style>` blocks into Volt embedded modules. They are browser assets, not server-rendered inline CSS.

Astral does **not** currently implement Astro-style scoped CSS, `is:global`, `:global()`, `class:list`, or `define:vars`. Use HEEx and CSS directly:

```astral
<div class={["card", @featured && "card--featured"]}>
  {@title}
</div>
```

For public, unprocessed stylesheets, put files under `public/` and link them normally:

```html
<link rel="stylesheet" href="/styles/global.css">
```

## Tailwind, PostCSS, and CSS preprocessors

Tailwind, PostCSS, Sass, Less, and similar tools belong to the Volt/browser asset layer. Add the npm packages your asset pipeline needs, import CSS from your Volt entry, and configure the tool in the ordinary browser-tooling files for that package.

Astral does not have an `astro add tailwind` equivalent. Keep the split explicit:

- Astral config defines pages, content, routes, and site plugins.
- Volt config and browser package files define CSS transforms, JS/TS checks, framework plugins, and asset behavior.

## Fonts

Astral does not currently provide an Astro Fonts API or a font-provider abstraction.

Use ordinary web font patterns today:

```css
@font-face {
  font-family: "Inter";
  src: url("/fonts/inter-var.woff2") format("woff2");
  font-weight: 100 900;
  font-display: swap;
}

:root { --font-sans: "Inter", system-ui, sans-serif; }
body { font-family: var(--font-sans); }
```

Place font files in `public/fonts/` when you want stable URLs, or import them from Volt-managed CSS when you want asset hashing. Add preload links in your head component or layout only for fonts that are critical for the first viewport:

```html
<link rel="preload" href="/fonts/inter-var.woff2" as="font" type="font/woff2" crossorigin>
```

A future font helper should be Elixir-native and privacy/performance-oriented rather than a direct JavaScript config clone.

## Syntax highlighting

Astral Markdown is backed by MDEx. Code fences render as Markdown HTML, and you can style `pre` and `code` elements with CSS.

Astral does not yet expose a Shiki/Prism configuration surface or built-in `<.code>` / `<.prism>` components. For now, use CSS-only styling or a site/plugin-owned highlighter if your docs site needs richer code blocks.

Syntax highlighting defaults remain a starter-template/product-polish item on the roadmap.

## Client-side scripts

Use `.astral` `<script>` blocks for page or component browser behavior:

```astral
<button data-confetti-button>Celebrate!</button>

<script lang="ts">
  document.querySelectorAll("[data-confetti-button]").forEach((button) => {
    button.addEventListener("click", () => console.log("celebrate"));
  });
</script>
```

Astral extracts these blocks into Volt embedded modules, so Volt handles TypeScript, imports, bundling, and dev-server behavior. Use standard DOM APIs and custom elements for static-site interactivity.

Server-side assigns are not browser variables. Pass data through HTML attributes when JavaScript needs per-element values:

```astral
<button data-message={@message}>Say hi</button>
```

For external scripts or files you want to serve exactly as written, place them under `public/` and reference them with normal HTML:

```html
<script src="/analytics.js" defer></script>
```

## Frontend frameworks and islands

Astral supports client-only islands for Vue, Svelte, React, and Solid using Volt-managed framework compilation. Different framework islands can be mixed on the same `.astral` page:

```astral
<.vue component="islands/Gallery.vue" client={:visible} props={%{title: "Gallery"}} />
<.svelte component="islands/Newsletter.svelte" client={:idle} props={%{title: "Updates"}} />
<.react component="islands/ReactCounter.jsx" client={:load} props={%{count: 1}} />
<.solid component="islands/SolidBadge.solid.tsx" client={:media} media="(min-width: 640px)" props={%{label: "New"}} />
```

Supported client directives are `:load`, `:idle`, `:visible`, and `:media`. Island props must be JSON-shaped values or structs with explicit JSON encoding. Static HEEx children can be passed through the framework slot/children channel.

A page can also repeat the same framework and use different loading strategies for each island. Production island entries are ES modules, allowing Volt to extract shared runtime/framework chunks for repeated islands when multi-entry shared chunks are available:

```astral
<section class="dashboard-widgets">
  <.vue component="islands/Chart.vue" client={:visible} props={%{id: "traffic"}}>
    <p>Static caption rendered by Astral.</p>
  </.vue>

  <.vue component="islands/Chart.vue" client={:load} props={%{id: "sales"}} />

  <.react component="islands/SearchBox.jsx" client={:load} props={%{placeholder: "Search"}} />
  <.react component="islands/FeedbackButton.jsx" client={:idle} props={%{label: "Feedback"}} />

  <.svelte component="islands/Newsletter.svelte" client={:idle} props={%{source: "footer"}} />
  <.solid component="islands/BreakpointBadge.solid.tsx" client={:media} media="(min-width: 768px)" props={%{label: "Desktop"}} />
</section>
```

Configure browser dependencies and framework plugins in Volt, not in Astral site plugins. Vue (`.vue`), Svelte (`.svelte`), and React JSX use Volt's built-in/default framework support. Solid JSX/TSX components should use the `.solid.jsx` or `.solid.tsx` filename convention so Astral can route those files through Volt's Solid compiler without changing how React `.jsx` and `.tsx` files are handled.

Current island support:

| Capability | Status |
| --- | --- |
| Mix Vue, Svelte, React, and Solid islands on one page | Supported |
| Repeat multiple islands from the same framework | Supported |
| Use `:load`, `:idle`, `:visible`, and `:media` on different islands | Supported |
| Pass static HEEx children into framework slot/children APIs | Supported |
| Nest a hydrated island inside another island's slot | Not supported yet; use sibling islands instead |
| Server-render framework components before hydration | Not supported yet |
| Hydrate `.astral` components | Not supported |

Astral does not currently SSR arbitrary framework components, hydrate `.astral` components, or provide `client:only` as a separate directive. The current island model is intentionally client-only while the native `.astral` and HEEx APIs stabilize.
