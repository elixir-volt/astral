ExUnit.start()

Volt.Test.ExUnit.install(
  root: "test/astral/islands",
  include: ["browser/*.test.ts"],
  browser: true,
  bundle: [
    node_modules: "node_modules",
    plugins: [
      Astral.Islands.RuntimePlugin,
      Astral.Islands.SolidPlugin,
      Volt.Plugin.Vue,
      Volt.Plugin.Svelte,
      Volt.Plugin.React
    ]
  ]
)
