# Editor Setup and TypeScript

Astral projects use ordinary Elixir tooling for site code and Volt tooling for browser assets.

## Editors

Use your normal Elixir editor setup for `.ex`, `.exs`, Markdown, and HEEx-style `.astral` templates.

For VS Code-compatible editors, Astral provides a thin `.astral` extension package. It registers `.astral` files, highlights setup blocks as Elixir, delegates template highlighting to Phoenix HEEx, and includes small snippets. Astral starter projects include `.vscode/extensions.json` recommendations for:

- `elixir-volt.astral-vscode` — `.astral` language registration, wrapper grammar, and snippets.
- `phoenixframework.phoenix` — HEEx syntax highlighting reused by `.astral` templates.
- `elixir-lsp.elixir-ls` — Elixir project support.

Astral does not yet ship a dedicated language server. The planned direction is an Elixir-native server launched from the user's Mix project, such as `mix astral.lsp --stdio`, so editor intelligence can reuse the project's Astral, Phoenix/HEEx, Elixir, and Volt versions.

For browser code, use the editor support for your chosen frontend files:

- `.ts` and `.tsx` through TypeScript tooling
- `.vue` through Vue tooling
- `.svelte` through Svelte tooling
- `.jsx` and `.tsx` through React/Solid-compatible tooling

## Formatting

Astral starter projects install Volt's formatter plugin so `mix format` can format Elixir plus configured JavaScript/TypeScript files:

```elixir
# .formatter.exs
[
  plugins: [Volt.Formatter],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}",
    "assets/app.ts",
    "assets/env.d.ts",
    "assets/islands/**/*.{js,ts,jsx,tsx}"
  ]
]
```

You can also format browser assets directly:

```bash
mix volt.js.format
```

Configure JavaScript/TypeScript formatting in `config/config.exs`:

```elixir
config :volt, :format,
  print_width: 100,
  semi: true,
  single_quote: false,
  trailing_comma: :all,
  arrow_parens: :always
```

## TypeScript configuration

Keep a `tsconfig.json` for browser assets and islands:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "noEmit": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"]
  },
  "include": ["assets/**/*.ts", "assets/**/*.tsx"]
}
```

Add declaration files such as `assets/env.d.ts` for asset imports or globals:

```ts
declare module "*.css"
```

## Checking browser code

Use Volt's JS checker for syntax linting, TypeScript-aware lint rules, and optional type checking:

```bash
mix volt.js.check
mix volt.js.check --type-aware
mix volt.js.check --type-aware --type-check
```

A typical project alias is:

```elixir
defp aliases do
  [
    check: ["format --check-formatted", "volt.js.check --type-aware --type-check"]
  ]
end
```

Configure linting in `config/config.exs`:

```elixir
config :volt, :lint,
  plugins: [:typescript, :react],
  tsgolint: "node_modules/.bin/tsgolint",
  rules: %{
    "correctness" => :deny,
    "no-debugger" => :deny,
    "eqeqeq" => :deny,
    "typescript/no-floating-promises" => :warn
  }
```

The dev server builds quickly and does not replace a project check step. Run `mix check` or your CI alias before deployment.
