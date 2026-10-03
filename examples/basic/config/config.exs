import Config

config :volt,
  plugins: [Volt.Plugin.Vue, Volt.Plugin.React],
  import_source: "react",
  ignore: [".astral/**", "vendor/**", "node_modules/**"]

config :volt, :lint,
  plugins: ["typescript", "react"],
  tsgolint: "node_modules/.bin/tsgolint",
  rules: %{
    "correctness" => :deny,
    "no-debugger" => :deny,
    "eqeqeq" => :deny,
    "typescript/no-floating-promises" => :warn
  }
