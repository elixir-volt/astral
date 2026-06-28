# Server Runtime and Hybrid Rendering

Astral is currently static-first. This guide maps Astro's server-rendering guides—on-demand rendering, server islands, actions, sessions, and route caching—to Astral's current runtime boundary and the planned hybrid work.

## Current runtime shape

`mix astral.build` discovers the site, renders pages, renders generated routes, builds images, and writes files under `dist/`. Public files are copied first, then pages are written, then generated routes are written.

`mix astral.dev` runs a Plug/Bandit development server, but it still serves the static-site model:

- Volt handles browser assets and HMR endpoints.
- Astral serves optimized image requests, public files, page routes, and config/plugin generated routes.
- Only `GET` and `HEAD` requests are accepted for Astral routes; other HTTP methods return `405 method not allowed`.
- Page rendering receives build-shaped assigns such as `@site`, `@page`, `@route`, `@params`, `@collections`, `@entry`, and `@routes`, not a request context.
- Config-generated routes are rendered through a synthetic `Plug.Test.conn("GET", route.path)` so route plugs can set response headers for static outputs, but they do not receive the real browser request body, cookies, method, or per-request connection state.

Use this model for static HTML, Markdown, collection pages, feeds, sitemaps, robots files, search indexes, generated images, and other files that can be produced at build time.

## On-demand rendering

Astro can install a server adapter, opt individual routes out of prerendering with `prerender = false`, or use `output: "server"` to render all routes on demand. Those routes can read the request, set response status and headers, use cookies, stream HTML, and implement server endpoints.

Astral does not yet have an equivalent server output mode or per-route prerender switch. A page or generated route may run Elixir during development and build, but production output is still files unless you host Astral behind your own application code.

For now:

- Use static pages and generated routes for deterministic build-time output.
- Use an existing Phoenix/Plug application for live forms, authentication, dashboards, APIs, and request-time personalization.
- Treat request-time route manifests, live endpoints, per-request locals, response control, cookies, and streaming as future hybrid/runtime work.

## Server islands

Astro server islands use `server:defer` to split a dynamic server-rendered component into its own runtime endpoint. The initial page can be static or cached, while the island fetches personalized HTML later. Props must be serializable, fallback content is rendered in the initial page, and Astro uses adapter-backed routes plus encrypted props.

Astral's current islands are client-only browser islands powered by Volt. They hydrate Vue, Svelte, React, and Solid components in the browser and can receive JSON-shaped props plus static HEEx children. They are not server islands: Astral does not split server-rendered `.astral` components into deferred runtime endpoints, encrypt server props, or fetch per-component HTML after page load.

If you need this pattern today, model it explicitly with your host application: render a static placeholder in Astral and have client code fetch HTML or JSON from a Phoenix/Plug endpoint.

## Actions and forms

Astro Actions define type-safe backend functions, validate JSON or form input, expose callable client functions, support zero-JS HTML form posts, return standardized action errors, and integrate with middleware, sessions, and on-demand pages.

Astral has no action registry, generated client RPC module, form-action endpoint convention, or action result API. Current config `get` routes are static endpoints only; they cannot handle `POST` submissions or request bodies.

Use ordinary HTML forms that submit to your Phoenix/Plug app, or use browser JavaScript to call your app's API routes. An Astral-native action layer should wait for a real runtime adapter and should use Elixir validation and Plug/Phoenix idioms rather than copying Astro's TypeScript/Zod API shape.

## Sessions and cookies

Astro sessions are server-side state for on-demand pages, endpoints, actions, and middleware. They require a session storage driver, expose `Astro.session` or `context.session`, and complement cookie access from runtime requests.

Astral does not currently expose request cookies or server-side sessions to pages, components, generated routes, or plugins. Static builds cannot depend on visitor-specific state. For authenticated or personalized flows today, keep session management in Phoenix/Plug and link to or embed Astral-generated pages as appropriate.

## Route caching

Astro route caching is a runtime API for on-demand responses. Routes can call `cache.set()`, invalidate by tag or path, merge cache directives from middleware/layout/page code, and use adapter cache providers for platforms such as Netlify, Vercel, and Cloudflare.

Astral does not have a runtime response cache provider, cache invalidation API, route rules, or per-request cache object. Static output should be cached by your deployment host or CDN with normal file and header configuration. Generated route plugs can set static response headers for generated files, but this is not the same as runtime cache storage or invalidation.

## Planned hybrid boundary

Hybrid/runtime support belongs in Astral, not Volt. Volt should continue to own browser assets, HMR, and build graph primitives. Astral should own any future site runtime semantics, likely including:

- a Plug runtime adapter and Phoenix integration adapter,
- a runtime route manifest,
- hybrid prerender plus dynamic routes,
- live endpoint handling beyond static generated routes,
- full page/request middleware with per-request locals,
- cookies, sessions, redirects, and response status/header control,
- runtime content loaders or CMS-backed collection shapes,
- optional runtime caching semantics where they fit Elixir deployment targets.

Until that work lands, document and design server features as boundaries, not as implemented APIs.
