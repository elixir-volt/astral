# VibeKit quality gate

## Development

```sh
mix deps.get
mix ci
```

## Conventions

- Use `mix ci` for the full validation suite before finishing changes.
- For Phoenix/web apps, keep Phoenix's generated guidance, but treat this VibeKit section as the final quality gate.
- For non-web Elixir projects, VibeKit is the default project baseline.
- Keep changes small, tested, and formatted.

## Astral architecture ideology

- Keep Astral Elixir-native and HEEx-first. Do not clone Astro patterns mechanically when an idiomatic Elixir/Phoenix construct already solves the problem.
- Prefer deleting abstractions over adding compatibility layers. Examples: render `{@entry.content}` via `Phoenix.HTML.Safe` instead of introducing an Astro-style `<Content />` component.
- Local `.astral` components should avoid module-definition boilerplate. Use setup blocks, `assigns`, `assign/3`, `assigns_to_attributes/2`, `render_slot/1`, and Phoenix's built-in `<.dynamic_tag>` before inventing Astral-specific component APIs.
- Preserve the separation of responsibilities: Volt owns browser assets, framework compilation, dev/build/HMR substrate; Astral owns site/content semantics, pages, layouts, routes, Markdown, collections, images, and islands.
- Treat HEEx/Phoenix.Component as the semantic foundation for templates, slots, attributes, class lists, and HTML safety.
- Use Elixir structs/protocols for server-side ergonomics and trust boundaries. Prefer protocol implementations such as `Phoenix.HTML.Safe` over helper components when the value itself has a clear rendering meaning.
- Keep substantial browser runtime code in real TypeScript assets under `priv/`, compiled and checked by Volt. Avoid inline JavaScript heredocs for runtime behavior.
- Normalize once at boundaries and keep internal contracts narrow: adapters/client directives are atoms internally; route params remain string-keyed; props crossing to JavaScript must be JSON-safe.
- Prefer parser/AST-backed processing for source, markup, Markdown, XML/HTML, and JavaScript/TypeScript. Avoid regex/string post-processing for structured formats.
