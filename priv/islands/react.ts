import React from 'react'
import { createRoot } from 'react-dom/client'
import { mountIsland, type ClientDirective } from 'astral:islands/runtime'

export type FrameworkIsland<
  Component = React.ComponentType<Record<string, unknown>>,
  Props = Record<string, unknown>
> = {
  id: string
  component: Component
  props: Props
  client: ClientDirective
}

export function mountReactIsland({ id, component, props, client }: FrameworkIsland): void {
  mountIsland({
    id,
    client,
    mount(island) {
      createRoot(island).render(React.createElement(component, props))
    }
  })
}

export const mountIslandComponent = mountReactIsland
