import { mount, type Component } from 'svelte'
import { mountIsland, type ClientDirective } from 'astral:islands/runtime'

export type FrameworkIsland<Props extends Record<string, unknown> = Record<string, unknown>> = {
  id: string
  component: Component<Props>
  props: Props
  client: ClientDirective
}

export function mountSvelteIsland({ id, component, props, client }: FrameworkIsland): void {
  mountIsland({
    id,
    client,
    mount(island) {
      mount(component, { target: island, props })
    }
  })
}

export const mountIslandComponent = mountSvelteIsland
