import type { Component } from 'solid-js'
import { render } from 'solid-js/web'
import { mountIsland, type ClientDirective } from 'astral:islands/runtime'

export type FrameworkIsland<Props extends Record<string, unknown> = Record<string, unknown>> = {
  id: string
  component: Component<Props>
  props: Props
  client: ClientDirective
  media: string | null
}

export function mountSolidIsland({ id, component, props, client, media }: FrameworkIsland): void {
  mountIsland({
    id,
    client,
    media,
    mount(island) {
      render(() => component(props), island)
    }
  })
}

export const mountIslandComponent = mountSolidIsland
