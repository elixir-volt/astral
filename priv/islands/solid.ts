import type { Component, JSX } from 'solid-js'
import { render } from 'solid-js/web'
import { mountIsland, type ClientDirective, type IslandSlots } from 'astral:islands/runtime'

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
    mount(island, slots) {
      render(() => component({ ...props, children: children(slots) }), island)
    }
  })
}

function children(slots: IslandSlots): JSX.Element | undefined {
  const html = slots.default

  if (!html) return undefined

  const slot = document.createElement('astral-slot')
  slot.style.display = 'contents'
  slot.innerHTML = html
  return slot
}

export const mountIslandComponent = mountSolidIsland
