declare const $astral_id: string
declare const $astral_props: Record<string, unknown>
declare const $astral_client: 'load' | 'idle' | 'visible'

declare module 'astral:island-component' {
  const component: unknown
  export default component
}

declare module 'astral:island-runtime' {
  export function mountIslandComponent(args: {
    id: string
    component: unknown
    props: Record<string, unknown>
    client: 'load' | 'idle' | 'visible'
  }): void
}
