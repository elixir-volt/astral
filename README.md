# Astral

Astral is a Volt-powered static site generator for Elixir applications.

It is inspired by Astro's separation of responsibilities: Volt remains the generic frontend asset/dev/build layer, while Astral owns site semantics such as pages, routes, layouts, content, and static HTML output.

## Status

Astral is in early development. The first milestone is a minimal static-page build pipeline on top of Volt `~> 0.14.8`.

## Installation

Once published, add Astral to your dependencies:

```elixir
def deps do
  [
    {:astral, "~> 0.1.0"}
  ]
end
```

## Development

```sh
mix deps.get
mix ci
```
