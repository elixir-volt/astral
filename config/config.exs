import Config

config :volt,
  root: ".",
  sources: ["priv/**/*.{js,ts,jsx,tsx}"],
  ignore: ["_build/**", "deps/**", "doc/**", "node_modules/**", "tmp/**"],
  plugins: [Volt.Plugin.Vue, Volt.Plugin.Svelte, Volt.Plugin.React, Volt.Plugin.Solid]

config :volt, :format,
  trailing_comma: :none,
  tab_width: 2,
  semi: false,
  single_quote: true,
  print_width: 100,
  arrow_parens: :always

config :volt, :lint,
  plugins: [:typescript, :react, :jsx_a11y],
  rules: %{
    "no-unused-expressions" => :allow,
    "typescript/no-floating-promises" => :deny
  },
  tsgolint: "node_modules/.bin/tsgolint"
