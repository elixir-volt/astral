defmodule Astral.Islands.SiteFixtures do
  @moduledoc false

  def link_node_modules!(root) do
    source = Path.expand("node_modules")
    target = Path.join(root, "node_modules")

    if File.dir?(source) and not File.exists?(target) do
      File.ln_s!(source, target)
    end
  end

  def write_mixed_framework_site!(root) do
    write(root, "assets/islands/Gallery.vue", ~S'''
    <template>
      <button :id="id">Vue {{ label }} <slot /></button>
    </template>
    <script setup>
    defineProps({ id: String, label: String })
    </script>
    ''')

    write(root, "assets/islands/Counter.svelte", ~S'''
    <script>
    let { id, label, children } = $props()
    </script>
    <button id={id}>Svelte {label} {@render children?.()}</button>
    ''')

    write(root, "assets/islands/ReactCounter.jsx", ~S'''
    import React from "react"

    export default function ReactCounter({ id, label, children }) {
      return React.createElement("button", { id }, `React ${label} `, children)
    }
    ''')

    write(root, "assets/islands/SolidCounter.solid.tsx", ~S'''
    export default function SolidCounter(props) {
      return <button id={props.id}>Solid {props.label} {props.children}</button>
    }
    ''')

    write(root, "pages/index.astral", ~S'''
    <.vue component="islands/Gallery.vue" client={:visible} props={%{id: "vue-result", label: "Gallery"}}>
      <span>Vue slot</span>
    </.vue>
    <.vue component="islands/Gallery.vue" client={:load} props={%{id: "vue-secondary", label: "Second"}} />
    <.svelte component="islands/Counter.svelte" client={:idle} props={%{id: "svelte-result", label: "Counter"}}>
      <span>Svelte slot</span>
    </.svelte>
    <.react component="islands/ReactCounter.jsx" client={:load} props={%{id: "react-result", label: "Counter"}}>
      <span>React slot</span>
    </.react>
    <.react component="islands/ReactCounter.jsx" client={:visible} props={%{id: "react-secondary", label: "Second"}} />
    <.solid component="islands/SolidCounter.solid.tsx" client={:media} media="(min-width: 640px)" props={%{id: "solid-result", label: "Counter"}}>
      <span>Solid slot</span>
    </.solid>
    ''')
  end

  def write_nested_island_site!(root) do
    write(root, "assets/islands/Shell.jsx", ~S'''
    import React from "react"

    export default function Shell({ children }) {
      return React.createElement("section", { id: "outer-shell" }, "Outer shell ", children)
    }
    ''')

    write(root, "assets/islands/NestedButton.svelte", ~S'''
    <script>
    let { label } = $props()
    </script>
    <button id="nested-result">Nested {label}</button>
    ''')

    write(root, "pages/index.astral", ~S'''
    <.react component="islands/Shell.jsx" client={:load} id="outer-shell-island">
      <.svelte component="islands/NestedButton.svelte" client={:load} id="nested-svelte-island" props={%{label: "Button"}} />
    </.react>
    ''')
  end

  defp write(root, path, content) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
