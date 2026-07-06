ExUnit.start()

Volt.Test.ExUnit.install(
  root: "test/astral/islands/fixtures",
  include: ["*.browser.test.ts"],
  browser: true,
  bundle: [
    node_modules: "node_modules",
    plugins: [
      Astral.Islands.RuntimePlugin,
      Volt.Plugin.Vue,
      Volt.Plugin.Svelte,
      Volt.Plugin.React,
      Volt.Plugin.Solid
    ]
  ]
)
