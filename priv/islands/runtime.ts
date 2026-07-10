export type ClientDirective = 'load' | 'idle' | 'visible' | 'media'

export type IslandSlots = Record<string, string>

export type IslandMount = {
  id: string
  client: ClientDirective
  media: string | null
  mount: (island: HTMLElement, slots: IslandSlots) => unknown | Promise<unknown>
}

export function mountIsland({ id, client, media, mount }: IslandMount): void {
  const start = (island: HTMLElement) => {
    if (island.dataset.astralMounted === 'true') return

    const run = async () => {
      if (island.dataset.astralMounted === 'true') return

      const parent = parentIsland(island)

      if (parent && parent.dataset.astralHydrated !== 'true') {
        listenOnce(parent, 'astral:hydrate', () => void run())
        return
      }

      const slots = collectSlots(island)
      island.dataset.astralMounted = 'true'

      try {
        await mount(island, slots)
        await afterFrameworkRender()
        activateNestedIslandScripts(island)
      } finally {
        island.dataset.astralHydrated = 'true'
        island.dispatchEvent(new CustomEvent('astral:hydrate', { bubbles: true }))
      }
    }

    if (client === 'idle') {
      onIdle(() => void run())
    } else if (client === 'visible') {
      const observer = new IntersectionObserver((entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          observer.disconnect()
          void run()
        }
      })
      observer.observe(island)
    } else if (client === 'media') {
      if (media) {
        const query = window.matchMedia(media)

        if (query.matches) {
          void run()
        } else {
          listenOnce(query, 'change', () => void run())
        }
      }
    } else {
      void run()
    }
  }

  const island = document.getElementById(id)

  if (island) {
    start(island)
  } else {
    waitForIsland(id, start)
  }
}

function collectSlots(island: HTMLElement): IslandSlots {
  const slots: IslandSlots = {}

  for (const template of island.querySelectorAll<HTMLTemplateElement>(
    ':scope > template[data-astral-template]'
  )) {
    slots[template.dataset.astralTemplate || 'default'] = template.innerHTML
    template.remove()
  }

  return slots
}

function onIdle(callback: () => void): void {
  if ('requestIdleCallback' in window) {
    window.requestIdleCallback(callback)
  } else if (document.readyState === 'complete') {
    queueMicrotask(callback)
  } else {
    listenOnce(window, 'load', callback)
  }
}

function listenOnce(target: EventTarget, type: string, callback: EventListener): void {
  target.addEventListener(type, callback, { once: true })
}

function afterFrameworkRender(): Promise<void> {
  return new Promise((resolve) => {
    if ('requestAnimationFrame' in window) {
      requestAnimationFrame(() => resolve())
    } else {
      queueMicrotask(resolve)
    }
  })
}

function waitForIsland(id: string, callback: (island: HTMLElement) => void): void {
  const observer = new MutationObserver(() => {
    const island = document.getElementById(id)

    if (island) {
      observer.disconnect()
      callback(island)
    }
  })

  observer.observe(document.documentElement, { childList: true, subtree: true })
}

function parentIsland(island: HTMLElement): HTMLElement | null {
  return island.parentElement?.closest<HTMLElement>('[data-astral-island]') ?? null
}

function activateNestedIslandScripts(island: HTMLElement): void {
  for (const script of island.querySelectorAll<HTMLScriptElement>(
    'script[type="module"][data-astral-entry]'
  )) {
    const src = script.src
    script.remove()
    void import(src)
  }
}
