import Component from 'astral:island-component'
import { mountIslandComponent } from 'astral:island-runtime'

mountIslandComponent({
  id: $astral_id,
  component: Component,
  props: $astral_props,
  client: $astral_client,
  media: $astral_media
})
