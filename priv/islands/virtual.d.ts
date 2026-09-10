declare const $astral_component: string

type IslandSlots = Record<string, string>

declare module 'astral:island-component' {
  const component: unknown
  export default component
}

declare module 'astral:island-runtime' {
  export function mountIslandComponent(args: {
    id: string
    component: unknown
    props: Record<string, unknown>
    client: 'load' | 'idle' | 'visible' | 'media'
    media: string | null
    slots?: IslandSlots
  }): void
}
