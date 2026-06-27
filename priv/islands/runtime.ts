export type ClientDirective = 'load' | 'idle' | 'visible' | 'media'

export type IslandMount = {
  id: string
  client: ClientDirective
  media: string | null
  mount: (island: HTMLElement) => unknown | Promise<unknown>
}

export function mountIsland({ id, client, media, mount }: IslandMount): void {
  const island = document.getElementById(id)
  if (!island || island.dataset.astralMounted === 'true') return

  const run = async () => {
    if (!island || island.dataset.astralMounted === 'true') return
    island.dataset.astralMounted = 'true'
    await mount(island)
  }

  if (client === 'idle') {
    if ('requestIdleCallback' in window) {
      window.requestIdleCallback(() => void run())
    } else {
      setTimeout(() => void run(), 200)
    }
  } else if (client === 'visible') {
    const observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        observer.disconnect()
        void run()
      }
    })
    observer.observe(island)
  } else if (client === 'media') {
    if (media && window.matchMedia(media).matches) {
      void run()
    }
  } else {
    void run()
  }
}
