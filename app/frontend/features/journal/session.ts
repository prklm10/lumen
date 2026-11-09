import { reactive, readonly } from 'vue'

/**
 * The unlocked journal key lives only in this module variable: not in Pinia (visible in
 * devtools), not in localStorage/sessionStorage/IndexedDB, and it's a non-extractable
 * CryptoKey, so even script running here can use it but never read its bytes (PRD §7.3).
 */
let key: CryptoKey | null = null
const state = reactive({ unlocked: false })
const beforeLock = new Set<(key: CryptoKey) => void>()

export const journalSession = {
  state: readonly(state),

  unlock(sessionKey: CryptoKey) {
    key = sessionKey
    state.unlocked = true
  },

  key(): CryptoKey {
    if (!key) throw new Error('The journal is locked')
    return key
  },

  /** Drops the key. Open editors get one last chance to save (with the key they're handed). */
  lock() {
    if (!key) return
    const last = key
    for (const hook of beforeLock) hook(last)
    key = null
    state.unlocked = false
  },

  onBeforeLock(hook: (key: CryptoKey) => void) {
    beforeLock.add(hook)
    return () => beforeLock.delete(hook)
  },
}
