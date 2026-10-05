import { createSignal, type Component, type JSX } from 'solid-js'
import { render } from 'solid-js/web'
import {
  mountIsland,
  onPropsUpdate,
  type ClientDirective,
  type IslandSlots
} from 'astral:islands/runtime'

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
      const [current, setCurrent] = createSignal(props)

      // A Solid component runs once, so its props read through the signal.
      // Props the island was not mounted with are not tracked.
      const reactive = { children: children(slots) } as Record<string, unknown>

      for (const name of Object.keys(props)) {
        Object.defineProperty(reactive, name, { enumerable: true, get: () => current()[name] })
      }

      render(() => component(reactive as typeof props & { children?: JSX.Element }), island)
      onPropsUpdate(island, (next) => setCurrent(() => next as typeof props))
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
