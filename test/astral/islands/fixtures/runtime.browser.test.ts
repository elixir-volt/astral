import { describe, test, expect, beforeEach, afterEach } from 'volt:test'
import { mountIsland } from '../../../../priv/islands/runtime'

type MountCall = {
  island: HTMLElement
  slots: Record<string, string>
}

const originalRequestIdleCallback = (window as any).requestIdleCallback
const originalIntersectionObserver = (window as any).IntersectionObserver
const originalMatchMedia = window.matchMedia
const originalSetTimeout = globalThis.setTimeout

describe('mountIsland', () => {
  beforeEach(() => {
    document.body.innerHTML = ''
    ;(window as any).requestIdleCallback = originalRequestIdleCallback
    ;(window as any).IntersectionObserver = originalIntersectionObserver
    window.matchMedia = originalMatchMedia
    globalThis.setTimeout = originalSetTimeout
  })

  afterEach(() => {
    document.body.innerHTML = ''
    ;(window as any).requestIdleCallback = originalRequestIdleCallback
    ;(window as any).IntersectionObserver = originalIntersectionObserver
    window.matchMedia = originalMatchMedia
    globalThis.setTimeout = originalSetTimeout
  })

  test('mounts load islands immediately and collects template slots', () => {
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
  })

  test('does not mount missing or already-mounted islands', () => {
    const island = renderIsland('mounted')
    island.dataset.astralMounted = 'true'
    const calls: MountCall[] = []

    mountIsland({ id: 'missing', client: 'load', media: null, mount: record(calls) })
    mountIsland({ id: 'mounted', client: 'load', media: null, mount: record(calls) })

    expect(calls).toHaveLength(0)
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

  test('falls back to a timeout for idle islands without requestIdleCallback', () => {
    renderIsland('idle-fallback')
    const calls: MountCall[] = []
    let timeoutCallback: (() => void) | undefined
    let timeoutDelay: number | undefined

    delete (window as any).requestIdleCallback
    globalThis.setTimeout = ((callback: () => void, delay?: number) => {
      timeoutCallback = callback
      timeoutDelay = delay
      return 1
    }) as typeof setTimeout

    mountIsland({ id: 'idle-fallback', client: 'idle', media: null, mount: record(calls) })

    expect(calls).toHaveLength(0)
    expect(timeoutDelay).toBe(200)

    timeoutCallback?.()

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

    window.matchMedia = ((query: string) => ({ matches: query === '(min-width: 768px)' })) as any

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
})

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

function record(calls: MountCall[]) {
  return (island: HTMLElement, slots: Record<string, string>) => {
    calls.push({ island, slots })
  }
}
