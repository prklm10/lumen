import { onBeforeUnmount, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { primaryNav, settingsNav } from '@/lib/navigation'

function isTyping(target: EventTarget | null) {
  const el = target as HTMLElement | null
  return !!el && (el.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(el.tagName))
}

/**
 * ⌘K / Ctrl+K → palette, ⌘\ → toggle sidebar, `g` then a letter → navigate (PRD GLB-2).
 */
export function useGlobalShortcuts(handlers: { palette: () => void; toggleSidebar: () => void }) {
  const router = useRouter()
  const destinations = [...primaryNav, settingsNav]
  let awaitingGoKey = false
  let goTimer: ReturnType<typeof setTimeout> | undefined

  function onKeydown(event: KeyboardEvent) {
    const mod = event.metaKey || event.ctrlKey
    if (mod && event.key.toLowerCase() === 'k') {
      event.preventDefault()
      handlers.palette()
      return
    }
    if (mod && event.key === '\\') {
      event.preventDefault()
      handlers.toggleSidebar()
      return
    }
    if (mod || event.altKey || isTyping(event.target)) return

    if (awaitingGoKey) {
      awaitingGoKey = false
      clearTimeout(goTimer)
      const target = destinations.find((d) => d.shortcut === event.key.toLowerCase())
      if (target) {
        event.preventDefault()
        router.push(target.path)
      }
    } else if (event.key === 'g') {
      awaitingGoKey = true
      goTimer = setTimeout(() => (awaitingGoKey = false), 1000)
    }
  }

  onMounted(() => window.addEventListener('keydown', onKeydown))
  onBeforeUnmount(() => {
    window.removeEventListener('keydown', onKeydown)
    clearTimeout(goTimer)
  })
}
