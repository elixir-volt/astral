import { createApp, defineComponent, h, type Component } from 'vue'
import { mountIsland, type ClientDirective, type IslandSlots } from 'astral:islands/runtime'

export type FrameworkIsland<Props = Record<string, unknown>> = {
  id: string
  component: Component<Props>
  props: Props
  client: ClientDirective
  media: string | null
}

export function mountVueIsland({ id, component, props, client, media }: FrameworkIsland): void {
  mountIsland({
    id,
    client,
    media,
    mount(island, islandSlots) {
      createApp({
        render() {
          return h(component, props, slots(islandSlots))
        }
      }).mount(island)
    }
  })
}

function slots(islandSlots: IslandSlots): Record<string, () => ReturnType<typeof h>> {
  return Object.fromEntries(
    Object.entries(islandSlots).map(([name, value]) => [name, () => h(StaticHtml, { value })])
  )
}

const StaticHtml = defineComponent({
  props: {
    value: {
      type: String,
      required: true
    }
  },
  setup(props) {
    return () => h('astral-slot', { innerHTML: props.value, style: 'display: contents' })
  }
})

export const mountIslandComponent = mountVueIsland
