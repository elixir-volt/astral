import { createRawSnippet, mount, unmount, type Component } from 'svelte'
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

export function mountSvelteIsland({ id, component, props, client, media }: FrameworkIsland): void {
  mountIsland({
    id,
    client,
    media,
    mount(island, slots) {
      const slotted = slotProps(slots)
      let mounted = mount(component, { target: island, props: { ...props, ...slotted } })

      // Props passed to `mount` are not reactive outside a Svelte module, so the
      // island is mounted again, which resets its state.
      onPropsUpdate(island, (next) => {
        void unmount(mounted)
        mounted = mount(component, { target: island, props: { ...next, ...slotted } })
      })
    }
  })
}

function slotProps(slots: IslandSlots): Record<string, unknown> {
  const props: Record<string, unknown> = {}
  const legacySlots: Record<string, unknown> = {}

  for (const [name, value] of Object.entries(slots)) {
    const snippet = createRawSnippet(() => ({
      render: () =>
        `<astral-slot style="display: contents"${name === 'default' ? '' : ` name="${name}"`}>${value}</astral-slot>`
    }))

    legacySlots[name] = name === 'default' ? true : snippet
    props[name === 'default' ? 'children' : name] = snippet
  }

  if (Object.keys(legacySlots).length > 0) {
    props.$$slots = legacySlots
  }

  return props
}

export const mountIslandComponent = mountSvelteIsland
