# Assets

Astral delegates browser assets to Volt.

## Configure assets

```elixir
site do
  assets "assets" do
    entry "app.ts"
    url_prefix "/assets"
  end
end
```

The source root is `assets/`; the browser URL prefix is `/assets`.

## Reference assets from layouts

Use `Astral.asset_path/2` with the source entry name:

```eex
<script type="module" src="<%= Astral.asset_path(@site, "app.ts") %>"></script>
```

In development this returns a source URL served by Volt, such as `/assets/app.ts`. In static builds it reads Volt's manifest and returns the emitted output path, such as `/assets/app-5e6f7a8b.js`.

## Content hashes

Content hashes are enabled by default for production caching:

```text
app.ts -> app-5e6f7a8b.js
styles.css -> styles-1a2b3c4d.css
```

Disable hashes for examples or prototypes that need stable filenames:

```elixir
assets "assets" do
  entry "app.ts"
  hash false
end
```

## `.astral` template assets

`<style>` and `<script>` blocks in `.astral` templates are extracted as Volt embedded modules:

```astral
<style>
  .card { border: 1px solid currentColor; }
</style>

<script lang="ts">
  console.log("loaded");
</script>
```

Volt builds those blocks alongside the configured asset entry.

## Volt features

For TypeScript, CSS, imported assets, asset query modes, workers, code splitting, HMR, and formatting/linting, see the Volt documentation.
