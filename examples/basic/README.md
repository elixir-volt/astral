# Astral Basic Example

This is a minimal Astral site that exercises the current core features:

- Markdown pages with MDEx frontmatter
- plain HTML pages
- default and per-page EEx layouts
- public static files
- Volt-managed TypeScript and CSS
- Astral's development server
- Volt JS/TS formatting and linting

## Run the dev server

```sh
mix deps.get
mix astral.dev
```

Open <http://localhost:4000>.

Try editing files in `pages/`, `layouts/`, `public/`, or `assets/` while the server is running.

The layout loads `/assets/app.js`; Volt resolves that request to the TypeScript entrypoint at `assets/app.ts` in dev. The example sets `hash false` in `astral.config.exs` so static builds also emit `dist/assets/app.js`.

## Check formatting and linting

This example follows Volt's formatting and linting setup:

- `.formatter.exs` installs `Volt.Formatter` so `mix format` formats TypeScript too.
- `config/config.exs` configures `config :volt, :format` and `config :volt, :lint`.
- `mix check` runs `mix format --check-formatted` and `mix volt.js.check`.

```sh
mix check
```

## Build the static site

```sh
mix deps.get
mix astral.build
```

The output is written to `dist/`.

## Routes

- `/`
- `/about/`
- `/blog/hello-astral/`
- `/landing/`
- `/raw/`
- `/robots.txt`
