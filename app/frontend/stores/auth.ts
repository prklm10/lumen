import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { authApi, type User } from '@/api/auth'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const needsSetup = ref(false)
  const loaded = ref(false)

  const isAuthenticated = computed(() => user.value !== null)

  // Resolves who we are once per page load; the router guard awaits this.
  async function bootstrap() {
    if (loaded.value) return
    const session = await authApi.current()
    user.value = session.user
    needsSetup.value = session.needs_setup
    loaded.value = true
  }

  async function login(email: string, password: string) {
    user.value = (await authApi.login(email, password)).user
  }

  async function setup(email: string, password: string) {
    const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone
    user.value = (await authApi.setup(email, password, timeZone)).user
    needsSetup.value = false
  }

  async function logout() {
    await authApi.logout()
    user.value = null
  }

  return { user, needsSetup, isAuthenticated, bootstrap, login, setup, logout }
})
