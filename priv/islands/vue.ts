import { createApp } from "vue";
import { mountIsland } from "astral:islands/runtime";

export function mountVueIsland({ id, component, props, client }) {
  mountIsland({
    id,
    client,
    mount(island) {
      createApp(component, props).mount(island);
    },
  });
}

export const mountIslandComponent = mountVueIsland;
