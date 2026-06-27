import { render } from "solid-js/web";
import { mountIsland } from "astral:islands/runtime";

export function mountSolidIsland({ id, component, props, client }) {
  mountIsland({
    id,
    client,
    mount(island) {
      render(() => component(props), island);
    },
  });
}

export const mountIslandComponent = mountSolidIsland;
