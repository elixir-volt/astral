import Component from "astral:island-component";
import { mountIslandComponent } from "astral:island-runtime";

mountIslandComponent({
  id: $id,
  component: Component,
  props: $props,
  client: $client,
});
