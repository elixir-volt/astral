# Astral for Visual Studio Code

Language support for Astral `.astral` templates.

## Features

- Registers `.astral` files with VS Code.
- Highlights Astral setup blocks (`--- ... ---`) as Elixir.
- Delegates template highlighting to Phoenix HEEx grammar.
- Includes small snippets for setup blocks and local component calls.

This package is intentionally thin. Astral templates are HEEx-first, so the extension reuses existing Elixir and Phoenix editor support instead of maintaining a second HEEx grammar.

## Dependencies

The extension depends on the official Phoenix extension for HEEx highlighting:

- `phoenixframework.phoenix`

It also recommends ElixirLS for Elixir support:

- `elixir-lsp.elixir-ls`

## Roadmap

Future language intelligence should come from an Elixir-native language server launched from the user's Mix project, for example:

```sh
mix astral.lsp --stdio
```

That server can reuse the project's installed Astral, Phoenix/HEEx, Elixir, and Volt semantics.

## Development

Run headless TextMate grammar tests:

```sh
npm --prefix packages/vscode run test:grammar
```

Update snapshots:

```sh
npm --prefix packages/vscode run update-grammar-snapshots
```

Package a local VSIX:

```sh
npm --prefix packages/vscode run package
```
