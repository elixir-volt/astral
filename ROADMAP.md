# Astral Roadmap

Astral is an Elixir-native, static-first site framework. This document describes
open directions, not promised versions or delivery dates. Shipped functionality
belongs in [the changelog](CHANGELOG.md); supported APIs belong in the guides.

## Principles

- Astral owns pages, routes, content, metadata, images, and deployment semantics.
- Volt owns browser assets, compilation, development serving, and HMR.
- Keep configuration Elixir-native and templates HEEx-first.
- Prefer existing Plug/Phoenix contracts and parser-backed processing.
- Prove new abstractions in real sites before promoting them into core.

## Current priorities

- **Authoring and starters:** practical blog/docs examples, syntax-highlighting
  defaults, search integration, and clearer diagnostics for invalid routes and
  content. Keep existing projects safe when updating installer configuration.
- **Metadata and social previews:** dogfood generated social cards in a site-local
  Skia plugin. Establish requirements for image overrides, bundled fonts, caching,
  and metadata before deciding what belongs in Astral. Consider shared site URL
  and head helpers only where they remove demonstrated duplication.
- **Static deployment:** document redirects and host-specific output conventions;
  decide which warrant plugins rather than core configuration.
- **Islands:** improve diagnostics and framework-specific examples, and continue
  checking nested hydration, serialization, and development/build parity.
- **Documentation:** keep feature boundaries accurate and build an Astral-powered
  documentation site using the public APIs.

## Later possibilities

- Plug/Phoenix deployment adapters and hybrid prerendering, with explicit request,
  middleware, response, session, and caching contracts.
- Runtime content sources and reusable CMS loaders where build-time collections
  are insufficient.
- First-class internationalized routing if localized folders and site-owned
  helpers prove insufficient.
- Optional prefetch/navigation enhancements delivered through Volt, preserving
  useful static HTML without JavaScript.
- Framework SSR if concrete applications justify expanding client-only islands.

## Non-goals for now

- Mirroring every Astro API or assigning future features to speculative versions.
- Replacing Phoenix authentication, sessions, actions, or application backends.
- A mandatory browser/Node process for static site generation.
- `.astro` or MDX compatibility in the core template language.
- Framework-owned social-card branding or visual designs.
