import { computed, ref } from 'vue'
import { useIntervalFn } from '@vueuse/core'
import { useAuthStore } from '@/stores/auth'
import { todayIn } from '@/lib/dates'

/** The user's time zone and today's date in it; rolls over at midnight while the app is open. */
export function useToday() {
  const auth = useAuthStore()
  const timeZone = computed(() => auth.user?.time_zone ?? 'UTC')
  const now = ref(new Date())
  useIntervalFn(() => (now.value = new Date()), 60_000)
  const today = computed(() => todayIn(timeZone.value, now.value))
  return { timeZone, today, now }
}
