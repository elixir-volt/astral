import { describe, test, expect, beforeEach, afterEach } from 'volt:test'
import React from 'react'
import { defineComponent, h, nextTick } from 'vue'
import { mountReactIsland } from 'astral:islands/react'
import { mountSolidIsland } from 'astral:islands/solid'
import { mountSvelteIsland } from 'astral:islands/svelte'
import { mountVueIsland } from 'astral:islands/vue'
import SvelteComponent from '../fixtures/components/SvelteIsland.svelte'

describe('framework island adapters', () => {
  beforeEach(() => {
    document.body.innerHTML = ''
  })

  afterEach(() => {
    document.body.innerHTML = ''
  })

  test('mounts React islands with props and default slot HTML', async () => {
    renderIsland('react-island', [['default', '<strong>React slot</strong>']])

    function Component(props: { label: string; children?: React.ReactNode }) {
      return React.createElement('button', { id: 'react-result' }, props.label, props.children)
    }

    mountReactIsland({
      id: 'react-island',
      component: Component,
      props: { label: 'React label ' },
      client: 'load',
      media: null
    })

    const button = await waitForElement('#react-result')
    expect(button.textContent).toContain('React label')
    expect(button.innerHTML).toContain('React slot')
  })

  test('mounts Vue islands with props and named slot HTML', async () => {
    renderIsland('vue-island', [['heading', '<em>Vue slot</em>']])

    const Component = defineComponent({
      props: {
        label: {
          type: String,
          required: true
        }
      },
      setup(props, { slots }) {
        return () => h('section', { id: 'vue-result' }, [props.label, slots.heading?.()])
      }
    })

    mountVueIsland({
      id: 'vue-island',
      component: Component,
      props: { label: 'Vue label ' },
      client: 'load',
      media: null
    })

    await nextTick()

    const section = document.querySelector('#vue-result')
    expect(section?.textContent).toContain('Vue label')
    expect(section?.innerHTML).toContain('Vue slot')
  })

  test('mounts Solid islands with props and default slot HTML', async () => {
    renderIsland('solid-island', [['default', '<span>Solid slot</span>']])

    function Component(props: { label: string; children?: Element }) {
      const button = document.createElement('button')
      button.id = 'solid-result'
      button.append(props.label)

      if (props.children) {
        button.append(props.children)
      }

      return button
    }

    mountSolidIsland({
      id: 'solid-island',
      component: Component,
      props: { label: 'Solid label ' },
      client: 'load',
      media: null
    })

    const button = await waitForElement('#solid-result')
    expect(button.textContent).toContain('Solid label')
    expect(button.innerHTML).toContain('Solid slot')
  })

  test('mounts Svelte islands with props and slot HTML', async () => {
    renderIsland('svelte-island', [
      ['default', '<strong>Svelte slot</strong>'],
      ['aside', '<em>Svelte aside</em>']
    ])

    mountSvelteIsland({
      id: 'svelte-island',
      component: SvelteComponent,
      props: { label: 'Svelte label ' },
      client: 'load',
      media: null
    })

    const section = await waitForElement('#svelte-result')
    expect(section.textContent).toContain('Svelte label')
    expect(section.innerHTML).toContain('Svelte slot')
    expect(section.innerHTML).toContain('Svelte aside')
  })

  test('mounts mixed framework islands on the same page', async () => {
    renderIsland('mixed-react', [['default', '<strong>React child</strong>']])
    renderIsland('mixed-vue', [['heading', '<em>Vue heading</em>']])
    renderIsland('mixed-solid', [['default', '<span>Solid child</span>']])
    renderIsland('mixed-svelte', [['default', '<strong>Svelte child</strong>']])

    function ReactComponent(props: { label: string; children?: React.ReactNode }) {
      return React.createElement('button', { id: 'mixed-react-result' }, props.label, props.children)
    }

    const VueComponent = defineComponent({
      props: {
        label: {
          type: String,
          required: true
        }
      },
      setup(props, { slots }) {
        return () => h('section', { id: 'mixed-vue-result' }, [props.label, slots.heading?.()])
      }
    })

    function SolidComponent(props: { label: string; children?: Element }) {
      const button = document.createElement('button')
      button.id = 'mixed-solid-result'
      button.append(props.label)

      if (props.children) {
        button.append(props.children)
      }

      return button
    }

    mountReactIsland({
      id: 'mixed-react',
      component: ReactComponent,
      props: { label: 'React mixed ' },
      client: 'load',
      media: null
    })

    mountVueIsland({
      id: 'mixed-vue',
      component: VueComponent,
      props: { label: 'Vue mixed ' },
      client: 'load',
      media: null
    })

    mountSolidIsland({
      id: 'mixed-solid',
      component: SolidComponent,
      props: { label: 'Solid mixed ' },
      client: 'load',
      media: null
    })

    mountSvelteIsland({
      id: 'mixed-svelte',
      component: SvelteComponent,
      props: { label: 'Svelte mixed ' },
      client: 'load',
      media: null
    })

    await nextTick()

    const react = await waitForElement('#mixed-react-result')
    const vue = await waitForElement('#mixed-vue-result')
    const solid = await waitForElement('#mixed-solid-result')
    const svelte = await waitForElement('#svelte-result')

    expect(react.textContent).toContain('React mixed')
    expect(react.innerHTML).toContain('React child')
    expect(vue.textContent).toContain('Vue mixed')
    expect(vue.innerHTML).toContain('Vue heading')
    expect(solid.textContent).toContain('Solid mixed')
    expect(solid.innerHTML).toContain('Solid child')
    expect(svelte.textContent).toContain('Svelte mixed')
    expect(svelte.innerHTML).toContain('Svelte child')
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

async function waitForElement(selector: string): Promise<Element> {
  for (let attempt = 0; attempt < 20; attempt++) {
    const element = document.querySelector(selector)

    if (element) {
      return element
    }

    await new Promise((resolve) => setTimeout(resolve, 10))
  }

  throw new Error(`Timed out waiting for ${selector}`)
}
