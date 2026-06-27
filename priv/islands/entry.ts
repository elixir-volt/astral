import Component from "astral:island-component";
import { mountVueIsland } from "astral:islands/vue";

mountVueIsland({
  id: $id,
  component: Component,
  props: $props,
  client: $client,
});
