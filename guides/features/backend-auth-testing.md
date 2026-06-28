# Backend Services, Authentication, and Testing

Astral is a static-first site framework today. This guide maps Astro's CMS, backend-service, authentication, and testing guides to Astral's current Elixir-native boundaries.

## CMS and backend services

Astro documents many CMS and backend-service integrations, usually through JavaScript SDKs, official Astro integrations, API routes, middleware, and on-demand-rendered pages. Many of those service guides are resource collections rather than core framework APIs.

Astral does not ship service-specific integrations for CMSes, databases, auth providers, storage services, monitoring vendors, or realtime backends. Use ordinary Elixir libraries and your own application modules:

- fetch CMS or backend data during static builds with `Req`, database clients, service SDKs, or plain files,
- materialize remote content into Markdown or data files before `mix astral.build`,
- load small page-local data in `.astral` setup blocks,
- create static JSON/search/feed-like outputs with config `get` routes,
- add reusable discovery/render behavior with Astral plugins.

In static output mode, these reads happen during discovery or rendering. Production pages are files, so they do not receive fresh per-request data unless your deployment separately calls a live backend from browser code or serves Astral through another application.

## Authentication and authorization

Astro's authentication guide relies on server-side capabilities: on-demand pages, API routes, middleware, request headers, cookies, sessions, redirects, and provider-specific integrations such as Better Auth or Clerk.

Astral does not currently provide an authentication layer, protected-route middleware, request cookies, sessions, or runtime API endpoints. Static Astral pages are public files unless your host or surrounding application protects them.

For authenticated or personalized experiences today:

- use Phoenix, Plug, or another Elixir web app for login, sessions, authorization, forms, and dashboards,
- put static marketing/docs pages in Astral and link to the authenticated app,
- protect generated static output with host-level access controls when the host supports them,
- call authenticated backend APIs from client islands or browser scripts when that security model is appropriate.

Do not put secrets or private user data into static page output or Volt browser assets. An Astral-native auth story should wait for the future runtime adapter layer and should build on Plug/Phoenix session and authentication idioms rather than copying TypeScript-specific provider APIs.

## Testing Astral sites

Astro documents Vitest for JavaScript unit tests, a container API for `.astro` component tests, and browser end-to-end tools such as Playwright, Cypress, and Nightwatch.

Astral does not currently expose a public component test container for `.astral` templates. Use the normal Elixir and browser testing layers that match what you are testing:

- run `mix test` for Elixir modules, config helpers, plugins, route generation, and content transforms,
- run `mix astral.build` in examples or CI to verify the full static build,
- inspect generated files under `dist/` for route, feed, sitemap, and markup assertions,
- run Volt JavaScript checks for browser assets when your project uses TypeScript or islands,
- use Playwright, Cypress, or another browser tool against `mix astral.dev` or a static preview server for end-to-end tests.

Prefer testing production-like static output for deployment behavior. `mix astral.dev` is useful for development feedback and HMR, while a static server pointed at `dist/` verifies what your host will actually serve.

## Future boundary

Potential future work belongs in the same hybrid/runtime track as server rendering:

- a public template/component rendering test helper,
- Phoenix/Plug integration test helpers for runtime routes,
- authenticated runtime examples using standard Elixir libraries,
- clearer CMS loader/plugin conventions for build-time and request-time content,
- deployment examples that combine Astral static output with a Phoenix app.

Until those APIs exist, treat backend, auth, and testing guidance as composition guidance around Astral's static build pipeline, not as first-class framework features.
