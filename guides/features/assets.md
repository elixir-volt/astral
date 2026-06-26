# Assets

Astral has two asset paths:

- Astral owns site images rendered with `<.image>` and `<.picture>`.
- Volt owns browser assets such as TypeScript, JavaScript, CSS, and files imported by them.

## Optimized images

Use built-in HEEx components from `.astral` pages, layouts, components, and component-aware Markdown:

```astral
<.image src="images/hero.jpg" alt="Hero" width={1200} format={:webp} quality={82} />
```

Ordinary local Markdown images are optimized too:

```md
![Hero](./hero.jpg "Optional title")
```

`src` resolves from the configured image source directories. By default, Astral looks under `assets/`, the site root, and `public/`.

Static builds write compressed, content-hashed files into the configured asset output directory:

```text
assets/images/hero.jpg
  -> dist/assets/hero-1200x800-k4L9v8B2qa.webp
```

Responsive pictures generate multiple variants and a fallback image:

```astral
<.picture
  src="images/hero.jpg"
  alt="Hero"
  widths={[480, 768, 1200]}
  formats={[:webp, :avif]}
  fallback_format={:jpeg}
  sizes="(max-width: 768px) 100vw, 1200px"
/>
```

The image pipeline is backed by the Elixir `Image` package and libvips. Output filenames include source content and transform options, so changing the source, dimensions, format, quality, or fit creates a new browser URL. Markdown image syntax uses the default image format and original dimensions unless you use `<.image>`/`<.picture>` for explicit transforms.

Configure defaults with the `image` option:

```elixir
site do
  image quality: 82,
        widths: [480, 768, 1200, 1600],
        formats: [:webp],
        fallback_format: :jpeg
end
```

Files in `public/` are still copied as-is. Use `<.image>` or `<.picture>` when you want Astral to optimize and hash an image.

During development, Astral emits `/_astral/image/...` URLs and generates optimized images on demand into the image cache. Responses use no-cache headers like Volt's dev asset server, so browser refreshes reflect source changes.

## Remote images

Astral does not optimize arbitrary remote URLs by default. Allow trusted remote image sources explicitly:

```elixir
site do
  image do
    allow_remote "https://images.example.com/**"
    allow_remote "https://**.amazonaws.com/bucket/**"
  end
end
```

Allowed remote images flow through the same `<.image>` and `<.picture>` components:

```astral
<.image src="https://images.example.com/hero.jpg" alt="Hero" width={800} />
```

Remote pattern wildcards follow Astro's model:

- `*.example.com` matches one subdomain level.
- `**.example.com` matches any subdomain depth.
- `/assets/*` matches one nested path segment.
- `/assets/**` matches any nested path below `/assets/`.

Remote redirects are followed only when every destination also matches an `allow_remote` pattern. Astral caches the downloaded original in the image cache and reuses response validators such as `ETag` and `Last-Modified` when available.

Static builds fetch allowed remote originals during generation. Because the original is available at build time, Astral can infer a missing dimension from the remote image metadata:

```astral
<.image src="https://images.example.com/hero.jpg" alt="Hero" width={800} />
```

Development mirrors Astro's endpoint model: page rendering emits `/_astral/image/...` without downloading the remote original, and the remote request happens when the browser asks for that optimized image. In dev, specify both `width` and `height` for remote images so Astral can avoid fetching during page render.

## Volt browser assets

Astral delegates browser assets to Volt.

## Configure Volt assets

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
