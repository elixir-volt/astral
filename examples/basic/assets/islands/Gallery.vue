<template>
  <section class="island-card">
    <p class="eyebrow">Vue island</p>
    <h2>{{ title }}</h2>
    <button type="button" @click="selected = (selected + 1) % images.length">
      Show {{ images[selected] }}
    </button>
  </section>
</template>

<script setup lang="ts">
import { ref } from "vue";

const props = defineProps<{
  title: string;
  images: string[];
}>();

const selected = ref(0);
const images = props.images.length > 0 ? props.images : ["Astral"];
</script>
