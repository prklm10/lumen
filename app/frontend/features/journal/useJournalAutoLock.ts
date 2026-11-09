import { onBeforeUnmount, onMounted } from 'vue'
import { useStorage } from '@vueuse/core'
import { journalSession } from './session'

/** Per-browser auto-lock preferences (JRN-2). */
export function useJournalLockSettings() {
  return {
    idleMinutes: useStorage('lumen-journal-idle-minutes', 10),
    lockOnHide: useStorage('lumen-journal-lock-on-hide', false),
  }
}

/** Locks the journal after N idle minutes, and optionally when the tab is hidden. */
export function useJournalAutoLock() {
  const { idleMinutes, lockOnHide } = useJournalLockSettings()
  let lastActivity = Date.now()
  let timer: ReturnType<typeof setInterval> | undefined

  const touch = () => (lastActivity = Date.now())
  const onVisibility = () => {
    if (document.visibilityState === 'hidden' && lockOnHide.value) journalSession.lock()
  }
  const events = ['pointerdown', 'keydown', 'wheel', 'touchstart', 'mousemove'] as const

  onMounted(() => {
    for (const e of events) window.addEventListener(e, touch, { passive: true })
    document.addEventListener('visibilitychange', onVisibility)
    timer = setInterval(() => {
      if (journalSession.state.unlocked && Date.now() - lastActivity > idleMinutes.value * 60_000) journalSession.lock()
    }, 15_000)
  })

  onBeforeUnmount(() => {
    for (const e of events) window.removeEventListener(e, touch)
    document.removeEventListener('visibilitychange', onVisibility)
    clearInterval(timer)
  })
}
