import Component from 'astral:island-component'
import { mountIslandComponent } from 'astral:island-runtime'

for (const element of document.querySelectorAll<HTMLElement>('[data-astral-component]')) {
  if (element.dataset.astralComponent !== $astral_component) continue
  const client = element.dataset.astralClient
  if (client !== 'load' && client !== 'idle' && client !== 'visible' && client !== 'media') continue
  mountIslandComponent({
    id: element.id,
    component: Component,
    props: JSON.parse(element.dataset.astralProps ?? '{}'),
    client,
    media: element.dataset.astralMedia ?? null
  })
}
