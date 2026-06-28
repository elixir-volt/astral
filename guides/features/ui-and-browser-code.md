# Styling, Fonts, Scripts, and Frameworks

Astral keeps document rendering in Elixir and delegates browser assets to Volt. This guide maps Astro's styling, font, script, syntax-highlighting, and frontend-framework features to Astral's current APIs.

## CSS and styles

Use Volt-managed CSS for site-wide styles:

```elixir
site do
  assets "assets" do
    entry "app.ts"
    url_prefix "/assets"
  end
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

Astral supports client-only islands for Vue, Svelte, React, and Solid using Volt-managed framework compilation:

```astral
<.vue component="islands/Gallery.vue" client={:visible} props={%{title: "Gallery"}} />
<.react component="islands/ReactCounter.jsx" client={:load} props={%{count: 1}} />
```

Supported client directives are `:load`, `:idle`, `:visible`, and `:media`. Island props must be JSON-shaped values or structs with explicit JSON encoding. Static HEEx children can be passed through the framework slot/children channel.

Astral does not currently SSR arbitrary framework components, hydrate `.astral` components, or provide `client:only` as a separate directive. The current island model is intentionally client-only while the native `.astral` and HEEx APIs stabilize.
