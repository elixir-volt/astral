# Development Server

Run Astral's development server with:

```bash
mix astral.dev
```

Open the printed URL, or ask Astral to open it:

```bash
mix astral.dev --open
```

## Options

```bash
mix astral.dev --config astral.config.exs --port 4000
```

## What the server does

The development server:

- serves Astral routes,
- serves files from `public/`,
- delegates browser assets and HMR endpoints to `Volt.DevServer`,
- injects Volt's HMR client into rendered HTML,
- watches pages, layouts, components, and public files,
- invalidates rendered pages after file changes,
- renders HTML error pages for Markdown, layout, template, and config failures.

## HMR and reloads

Volt handles browser asset HMR. Astral triggers full reloads for site-layer files such as pages, layouts, components, and public files.

Use plain browser JavaScript for static-site interactivity. `.astral` templates render static HTML; they do not imply LiveView server events.
