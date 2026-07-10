import { describe, test, expect, beforeEach, afterEach } from 'volt:test'
import { mountIsland } from '../../../../priv/islands/runtime'

type MountCall = {
  island: HTMLElement
  slots: Record<string, string>
}

const originalRequestIdleCallback = (window as any).requestIdleCallback
const originalIntersectionObserver = (window as any).IntersectionObserver
const originalMatchMedia = window.matchMedia

describe('mountIsland', () => {
  beforeEach(() => {
    document.body.innerHTML = ''
    ;(window as any).requestIdleCallback = originalRequestIdleCallback
    ;(window as any).IntersectionObserver = originalIntersectionObserver
    window.matchMedia = originalMatchMedia
  })

  afterEach(() => {
    document.body.innerHTML = ''
    ;(window as any).requestIdleCallback = originalRequestIdleCallback
    ;(window as any).IntersectionObserver = originalIntersectionObserver
    window.matchMedia = originalMatchMedia
  })

  test('mounts load islands immediately and collects template slots', async () => {
    const island = renderIsland('demo', [
      ['default', '<p>Default slot</p>'],
      ['header', '<h1>Header slot</h1>']
    ])
    const calls: MountCall[] = []

    mountIsland({
      id: 'demo',
      client: 'load',
      media: null,
      mount(target, slots) {
        calls.push({ island: target, slots })
      }
    })

    expect(calls).toHaveLength(1)
    expect(calls[0].island).toBe(island)
    expect(calls[0].slots).toEqual({
      default: '<p>Default slot</p>',
      header: '<h1>Header slot</h1>'
    })
    expect(island.dataset.astralMounted).toBe('true')
    expect(island.querySelector('template')).toBeNull()

    await eventually(() => {
      expect(island.dataset.astralHydrated).toBe('true')
    })
  })

  test('does not mount missing or already-mounted islands', () => {
    const island = renderIsland('mounted')
    island.dataset.astralMounted = 'true'
    const calls: MountCall[] = []

    mountIsland({ id: 'missing', client: 'load', media: null, mount: record(calls) })
    mountIsland({ id: 'mounted', client: 'load', media: null, mount: record(calls) })

    expect(calls).toHaveLength(0)
  })

  test('marks islands mounted before async mount completes', () => {
    const island = renderIsland('async')
    const calls: MountCall[] = []
    let resolveMount: (() => void) | undefined

    mountIsland({
      id: 'async',
      client: 'load',
      media: null,
      mount(target, slots) {
        calls.push({ island: target, slots })
        return new Promise<void>((resolve) => {
          resolveMount = resolve
        })
      }
    })

    mountIsland({ id: 'async', client: 'load', media: null, mount: record(calls) })

    expect(island.dataset.astralMounted).toBe('true')
    expect(calls).toHaveLength(1)

    resolveMount?.()
  })

  test('defers idle islands to requestIdleCallback when available', () => {
    renderIsland('idle')
    const calls: MountCall[] = []
    let idleCallback: (() => void) | undefined

    ;(window as any).requestIdleCallback = (callback: () => void) => {
      idleCallback = callback
      return 1
    }

    mountIsland({ id: 'idle', client: 'idle', media: null, mount: record(calls) })

    expect(calls).toHaveLength(0)
    expect(idleCallback).toBeDefined()

    idleCallback?.()

    expect(calls).toHaveLength(1)
  })

  test('falls back to a microtask for idle islands after load without requestIdleCallback', async () => {
    renderIsland('idle-fallback')
    const calls: MountCall[] = []

    delete (window as any).requestIdleCallback

    mountIsland({ id: 'idle-fallback', client: 'idle', media: null, mount: record(calls) })

    expect(calls).toHaveLength(0)

    await Promise.resolve()

    expect(calls).toHaveLength(1)
  })

  test('mounts visible islands once they intersect', () => {
    const island = renderIsland('visible')
    const calls: MountCall[] = []
    let callback: ((entries: Array<{ isIntersecting: boolean }>) => void) | undefined
    let observed: Element | undefined
    let disconnected = false

    ;(window as any).IntersectionObserver = class {
      constructor(observerCallback: (entries: Array<{ isIntersecting: boolean }>) => void) {
        callback = observerCallback
      }

      observe(element: Element) {
        observed = element
      }

      disconnect() {
        disconnected = true
      }
    }

    mountIsland({ id: 'visible', client: 'visible', media: null, mount: record(calls) })

    expect(observed).toBe(island)
    expect(calls).toHaveLength(0)

    callback?.([{ isIntersecting: false }])
    expect(calls).toHaveLength(0)

    callback?.([{ isIntersecting: true }])
    expect(disconnected).toBe(true)
    expect(calls).toHaveLength(1)
  })

  test('mounts media islands only when the query matches', () => {
    renderIsland('wide')
    renderIsland('narrow')
    const calls: MountCall[] = []

    window.matchMedia = ((query: string) =>
      mediaQuery(query === '(min-width: 768px)')) as any

    mountIsland({
      id: 'wide',
      client: 'media',
      media: '(min-width: 768px)',
      mount: record(calls)
    })

    mountIsland({
      id: 'narrow',
      client: 'media',
      media: '(max-width: 320px)',
      mount: record(calls)
    })

    expect(calls).toHaveLength(1)
    expect(calls[0].island.id).toBe('wide')
  })

  test('mounts a media island when its query starts matching later', () => {
    renderIsland('responsive')
    const calls: MountCall[] = []
    const query = mediaQuery(false)

    window.matchMedia = (() => query) as any

    mountIsland({
      id: 'responsive',
      client: 'media',
      media: '(min-width: 768px)',
      mount: record(calls)
    })

    expect(calls).toHaveLength(0)

    query.matches = true
    query.dispatchEvent(new Event('change'))

    expect(calls).toHaveLength(1)
    expect(calls[0].island.id).toBe('responsive')
  })

  test('waits for island elements inserted after their entry executes', async () => {
    const calls: MountCall[] = []

    mountIsland({ id: 'late-child', client: 'load', media: null, mount: record(calls) })

    expect(calls).toHaveLength(0)

    const island = renderIsland('late-child')

    await eventually(() => {
      expect(calls).toHaveLength(1)
      expect(calls[0].island).toBe(island)
    })
  })

  test('hydrates nested islands after parent islands finish hydrating', async () => {
    const parent = renderIsland('parent')
    parent.dataset.astralIsland = 'react'
    parent.dataset.astralMounted = 'true'
    const child = document.createElement('div')
    child.id = 'child'
    child.dataset.astralIsland = 'svelte'
    parent.appendChild(child)
    const calls: MountCall[] = []

    mountIsland({ id: 'child', client: 'load', media: null, mount: record(calls) })

    expect(calls).toHaveLength(0)

    parent.dataset.astralHydrated = 'true'
    parent.dispatchEvent(new CustomEvent('astral:hydrate', { bubbles: true }))

    await eventually(() => {
      expect(calls).toHaveLength(1)
      expect(calls[0].island).toBe(child)
    })
  })

  test('activates nested island entry scripts inserted from slot HTML', async () => {
    const code = '(globalThis.__astralNestedScript = (globalThis.__astralNestedScript || 0) + 1)'
    const src = `data:text/javascript,${encodeURIComponent(code)}`
    renderIsland('parent-with-script', [
      [
        'default',
        `<div id="nested-from-slot" data-astral-island="svelte"></div><script type="module" src="${src}" data-astral-entry="nested-from-slot"></script>`
      ]
    ])

    mountIsland({
      id: 'parent-with-script',
      client: 'load',
      media: null,
      mount(island, slots) {
        island.innerHTML = slots.default
      }
    })

    await eventually(() => {
      expect((globalThis as any).__astralNestedScript).toBe(1)
    })
  })
})

function mediaQuery(matches: boolean): MediaQueryList & { matches: boolean } {
  const query = new EventTarget() as MediaQueryList & { matches: boolean }
  query.matches = matches
  return query
}

function renderIsland(id: string, slots: Array<[string, string]> = []): HTMLElement {
  const island = document.createElement('div')
  island.id = id

  for (const [name, html] of slots) {
    const template = document.createElement('template')
    template.dataset.astralTemplate = name
    template.innerHTML = html
    island.appendChild(template)
  }

  document.body.appendChild(island)
  return island
}

async function eventually(assertion: () => void): Promise<void> {
  let lastError: unknown

  for (let attempt = 0; attempt < 20; attempt++) {
    try {
      assertion()
      return
    } catch (error) {
      lastError = error
      await new Promise((resolve) => requestAnimationFrame(() => resolve(undefined)))
    }
  }

  throw lastError
}

function record(calls: MountCall[]) {
  return (island: HTMLElement, slots: Record<string, string>) => {
    calls.push({ island, slots })
  }
}
