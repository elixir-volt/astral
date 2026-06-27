import React from "react";
import { createRoot } from "react-dom/client";
import { mountIsland } from "astral:islands/runtime";

export function mountReactIsland({ id, component, props, client }) {
  mountIsland({
    id,
    client,
    mount(island) {
      createRoot(island).render(React.createElement(component, props));
    },
  });
}

export const mountIslandComponent = mountReactIsland;
