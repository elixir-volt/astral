# Navigation, i18n, Prefetch, and View Transitions

Astral pages are static HTML documents by default. Navigation uses ordinary links, forms, browser behavior, and any client code you add through Volt-managed assets.

This guide documents the current boundary after auditing Astro's i18n, prefetch, and view-transition features.

## Links and page navigation

Use normal `<a>` elements in `.astral`, Markdown, and layouts:

```astral
<a href="/about/">About</a>
<a href="/blog/hello-astral/">Read the post</a>
```

Astral does not currently inject a client-side router. A link click performs a normal browser navigation unless your own JavaScript intercepts it.

## Internationalized routes today

Astral does not yet have first-class i18n routing config, locale-aware link helpers, locale fallbacks, domain-based locales, or browser-language middleware.

For static sites today, use userland file and data patterns:

```text
pages/index.md          -> /
pages/about.md         -> /about/
pages/es/index.md      -> /es/
pages/es/about.md      -> /es/about/
pages/fr/index.md      -> /fr/
pages/fr/about.md      -> /fr/about/
```

For collection-backed or generated locale pages, keep locale metadata in your content schema and declare routes explicitly:

```elixir
collections do
  collection :posts, "content/posts" do
    permalink "/:locale/blog/:slug/"

    schema do
      field :locale, :string, required: true
      field :title, :string, required: true
      field :date, :date, required: true
    end
  end
end
```

You can also generate locale index pages with setup-declared dynamic `.astral` routes:

```astral
---
locales = ["en", "es", "fr"]
paths = for locale <- locales, do: path locale: locale
---

<h1>{@params.locale}</h1>
```

Keep locale link generation in small site-owned helpers or components for now. This avoids adding an Astro-shaped global config before Astral has a runtime request layer and a clear Elixir-native i18n API.

## Prefetch today

Astral does not currently add a prefetch script or provide an `astro:prefetch`-style browser module.

Use browser-native or userland approaches where needed:

```html
<link rel="prefetch" href="/about/">
```

Or add a small Volt-managed browser script for your own link-prefetch policy. Keep cache headers in mind when deploying static pages: some browsers only reuse prefetched responses reliably when your host sends cache validators such as `ETag` or `Cache-Control`.

A future prefetch feature would likely be a small client runtime delivered through Volt, with Astral deciding which site routes and links are eligible.

## View transitions today

Astral does not currently provide a `<ClientRouter />`, transition directives, island persistence across routes, or client-side navigation lifecycle events.

You can use browser-native CSS and JavaScript yourself for progressive enhancement. For example, cross-document view transitions can be enabled in supporting browsers with ordinary CSS:

```css
@view-transition {
  navigation: auto;
}
```

For richer SPA-like navigation, keep the routing code in your own Volt-managed assets until Astral has a dedicated client-navigation runtime.

## Planned boundary

These features cross the static/runtime boundary:

- **Static i18n patterns** can be documented and improved with examples before core APIs exist.
- **First-class i18n routing** needs a strict route/locale model and probably belongs with hybrid/runtime route semantics, redirects, rewrites, and request middleware.
- **Prefetch** is mostly a small browser runtime concern, but it should understand Astral routes and deployment cache expectations.
- **View transitions and client routing** require an Astral-owned client-navigation runtime, delivered by Volt, and should stay separate from core static rendering until the native API is clear.
