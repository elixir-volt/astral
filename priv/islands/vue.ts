import { createApp, type Component } from 'vue'
import { mountIsland, type ClientDirective } from 'astral:islands/runtime'

export type FrameworkIsland<Props = Record<string, unknown>> = {
  id: string
  component: Component<Props>
  props: Props
  client: ClientDirective
}

export function mountVueIsland({ id, component, props, client }: FrameworkIsland): void {
  mountIsland({
    id,
    client,
    mount(island) {
      createApp(component, props).mount(island)
    }
  })
}

export const mountIslandComponent = mountVueIsland
