<script lang="ts">
  let { label, children, aside } = $props()
</script>

<section id="svelte-result">
  {label}
  {@render children?.()}
  {@render aside?.()}
</section>
