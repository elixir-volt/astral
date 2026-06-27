import { mount } from "svelte";
import { mountIsland } from "astral:islands/runtime";

export function mountSvelteIsland({ id, component, props, client }) {
  mountIsland({
    id,
    client,
    mount(island) {
      mount(component, { target: island, props });
    },
  });
}

export const mountIslandComponent = mountSvelteIsland;
