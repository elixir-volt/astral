export function mountIsland({ id, client, mount }) {
  const island = document.getElementById(id);
  if (!island || island.dataset.astralMounted === "true") return;

  const run = async () => {
    if (!island || island.dataset.astralMounted === "true") return;
    island.dataset.astralMounted = "true";
    await mount(island);
  };

  if (client === "idle") {
    if ("requestIdleCallback" in window) {
      window.requestIdleCallback(run);
    } else {
      setTimeout(run, 200);
    }
  } else if (client === "visible") {
    const observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        observer.disconnect();
        run();
      }
    });
    observer.observe(island);
  } else {
    run();
  }
}
