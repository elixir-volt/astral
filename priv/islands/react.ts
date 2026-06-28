import React from 'react'
import { createRoot } from 'react-dom/client'
import { mountIsland, type ClientDirective, type IslandSlots } from 'astral:islands/runtime'

export type FrameworkIsland<
  Component = React.ComponentType<Record<string, unknown>>,
  Props = Record<string, unknown>
> = {
  id: string
  component: Component
  props: Props
  client: ClientDirective
  media: string | null
}

export function mountReactIsland({ id, component, props, client, media }: FrameworkIsland): void {
  mountIsland({
    id,
    client,
    media,
    mount(island, slots) {
      createRoot(island).render(React.createElement(component, props, children(slots)))
    }
  })
}

function children(slots: IslandSlots): React.ReactNode {
  const html = slots.default

  if (!html) return undefined

  return React.createElement('astral-slot', {
    dangerouslySetInnerHTML: { __html: html },
    style: { display: 'contents' }
  })
}

export const mountIslandComponent = mountReactIsland
