import Component from 'astral:island-component'
import { mountIslandComponent } from 'astral:island-runtime'

const scheduled = new WeakSet<HTMLElement>()

export function mountIslands(root: ParentNode = document): void {
  for (const element of root.querySelectorAll<HTMLElement>('[data-astral-component]')) {
    if (element.dataset.astralComponent !== $astral_component || scheduled.has(element)) continue
    const client = element.dataset.astralClient
    if (client !== 'load' && client !== 'idle' && client !== 'visible' && client !== 'media')
      continue
    scheduled.add(element)
    mountIslandComponent({
      id: element.id,
      component: Component,
      props: JSON.parse(element.dataset.astralProps ?? '{}'),
      client,
      media: element.dataset.astralMedia ?? null
    })
  }
}

mountIslands()
