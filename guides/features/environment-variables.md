# Environment Variables

Astral uses Elixir environment access for server-side build and template code, and Volt environment variables for browser assets.

## Server-side build and template code

Use ordinary Elixir APIs in `astral.config.exs`, `.astral` setup blocks, plugins, and generated routes:

```elixir
api_base = System.fetch_env!("API_BASE_URL")
```

Values read this way are available only while Astral is discovering or rendering the site. If you write them into HTML, JavaScript, JSON, feeds, or generated files, they become part of the static output.

## Browser assets

Volt exposes selected `.env` values to JavaScript through `import.meta.env`.

Create `.env` files in your project root:

```text
VOLT_API_URL=https://api.example.com
VOLT_DEBUG=true
SECRET_TOKEN=do-not-expose
```

Only variables matching Volt's configured `env_prefix` are exposed to browser code. The default prefix is `VOLT_`:

```ts
console.log(import.meta.env.VOLT_API_URL)
console.log(import.meta.env.MODE) // "development" or "production"
console.log(import.meta.env.DEV)  // true or false
console.log(import.meta.env.PROD) // true or false
```

Never put secrets in variables matching `env_prefix`; those values are embedded into client bundles.

## Env files and modes

Volt loads env files in this order, with later files overriding earlier ones:

1. `.env`
2. `.env.local`
3. `.env.{mode}`
4. `.env.{mode}.local`

Astral's dev server uses Volt's development mode for browser assets. Static builds use Volt's production mode for browser assets.

## Public prefix compatibility

If you are migrating from Vite or Astro-style `PUBLIC_` variables, configure Volt to expose that prefix:

```elixir
# config/config.exs
config :volt, env_prefix: ["VOLT_", "PUBLIC_"]
```

Then browser code can read:

```ts
console.log(import.meta.env.PUBLIC_API_URL)
```

## TypeScript declarations

Add public env variables to your asset declaration file for editor completion:

```ts
// assets/env.d.ts
interface ImportMetaEnv {
  readonly VOLT_API_URL: string
  readonly PUBLIC_API_URL: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
```

## Current scope

Astral does not currently provide a separate typed environment schema. Use Elixir validation for server-side configuration and Volt's `env_prefix` boundary for browser-exposed values.
