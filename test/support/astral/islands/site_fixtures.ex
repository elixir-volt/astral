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

  def write_hardened_island_site!(root) do
    write(root, "assets/islands/Echo.jsx", ~S'''
    import React from "react"

    export default function Echo(props) {
      window.__astralMounts = window.__astralMounts || {}
      window.__astralMounts[props.id] = (window.__astralMounts[props.id] || 0) + 1

      return React.createElement(
        "section",
        { id: props.id, "data-mounts": window.__astralMounts[props.id] },
        props.label,
        " ",
        JSON.stringify(props.data),
        " ",
        props.children
      )
    }
    ''')

    write(root, "assets/islands/Failure.jsx", ~S'''
    export default function Failure() {
      throw new Error("intentional island failure")
    }
    ''')

    write(root, "assets/islands/Ok.vue", ~S'''
    <template><p :id="id">Vue {{ label }}</p></template>
    <script setup>
    defineProps({ id: String, label: String })
    </script>
    ''')

    write(root, "assets/islands/Styled.svelte", ~S'''
    <script>
    let { id, label } = $props()
    </script>
    <div id={id} class="styled-island">Styled {label}</div>
    <style>
    .styled-island { color: rgb(1, 2, 3); }
    </style>
    ''')

    write(root, "pages/index.astral", ~S'''
    <.react component="islands/Echo.jsx" client={:load} props={%{id: "echo-load", label: "Load", data: %{"nil" => nil, atom_key: :atom_value, list: [1, "two", false], date: ~D[2026-07-07]}}}>
      <strong>Load slot</strong>
    </.react>
    <.react component="islands/Echo.jsx" client={:idle} props={%{id: "echo-idle", label: "Idle", data: %{mode: :idle}}} />
    <.react component="islands/Echo.jsx" client={:visible} props={%{id: "echo-visible", label: "Visible", data: %{mode: :visible}}} />
    <.react component="islands/Failure.jsx" client={:load} id="failing-island" />
    <.vue component="islands/Ok.vue" client={:load} props={%{id: "after-failure", label: "After failure"}} />
    <.svelte component="islands/Styled.svelte" client={:load} props={%{id: "styled-result", label: "CSS"}} />
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

  def write_delayed_shared_island_site!(root) do
    write(root, "assets/islands/Shell.vue", ~S'''
    <template><section id="delayed-shell"><slot /></section></template>
    ''')

    write(root, "assets/islands/Styled.vue", ~S'''
    <script>
    const Object = {};
    export default {
      props: ["label"],
      mounted() { globalThis.astralMounts = (globalThis.astralMounts || 0) + 1; }
    };
    </script>
    <template><p class="styled">{{ label }}</p></template>
    <style scoped>.styled { color: rgb(12, 34, 56); }</style>
    ''')

    write(root, "pages/index.astral", ~S'''
    <.vue component="islands/Shell.vue" client={:media} media="(min-width: 1500px)" id="delayed-parent">
      <.vue component="islands/Styled.vue" props={%{label: "Nested one"}} id="nested-one" />
      <.vue component="islands/Styled.vue" props={%{label: "Nested two"}} id="nested-two" />
    </.vue>
    ''')

    write(root, "layouts/site.astral", ~S'''
    <!doctype html><html><head></head><body>
    {@content}
    <.vue component="islands/Styled.vue" props={%{label: "Outside"}} id="outside" />
    </body></html>
    ''')
  end

  defp write(root, path, content) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
