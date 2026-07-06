ExUnit.start()

defmodule Astral.Test.SvelteRuntimePlugin do
  @moduledoc "Provides a tiny Svelte runtime shim for browser adapter tests."

  @behaviour Volt.Plugin

  @impl true
  def name, do: "astral-test-svelte-runtime"

  @impl true
  def resolve("svelte", _importer), do: {:ok, "astral:test/svelte"}
  def resolve(_specifier, _importer), do: nil

  @impl true
  def load("astral:test/svelte") do
    {:ok,
     """
     export function createRawSnippet(factory) {
       return (...args) => {
         const { render } = factory(...args)
         const template = document.createElement('template')
         template.innerHTML = render()
         return template.content.cloneNode(true)
       }
     }

     export function mount(component, { target, props }) {
       const result = component(props)
       if (result instanceof Node) target.append(result)
       return result
     }
     """}
  end

  def load(_path), do: nil
end

Volt.Test.ExUnit.install(
  root: "test/astral/islands/fixtures",
  include: ["*.browser.test.ts"],
  browser: true,
  bundle: [
    node_modules: "node_modules",
    plugins: [
      Astral.Islands.RuntimePlugin,
      Astral.Test.SvelteRuntimePlugin,
      Volt.Plugin.Vue,
      Volt.Plugin.Svelte,
      Volt.Plugin.React,
      Volt.Plugin.Solid
    ]
  ]
)
