<script setup lang="ts">
import { Monitor, Moon, Sun } from '@lucide/vue'
import { useAuthStore } from '@/stores/auth'
import { useTheme, type ThemeMode } from '@/composables/useTheme'
import JournalSettings from '@/features/journal/components/JournalSettings.vue'
import DataSettings from './DataSettings.vue'
import { toast } from 'vue-sonner'
import { errorMessage } from '@/composables/useTasks'
import { useQueryClient } from '@tanstack/vue-query'

const auth = useAuthStore()
const { store: theme } = useTheme()
const client = useQueryClient()
const zones = Intl.supportedValuesOf('timeZone')

// "Today", "overdue" and analytics buckets all follow this zone, so refresh everything after a change.
async function setZone(event: Event) {
  try {
    await auth.updateMe({ time_zone: (event.target as HTMLSelectElement).value })
    client.invalidateQueries()
    toast('Time zone updated')
  } catch (e) {
    toast.error(errorMessage(e))
  }
}

const options: { mode: ThemeMode; label: string; icon: typeof Sun }[] = [
  { mode: 'light', label: 'Light', icon: Sun },
  { mode: 'dark', label: 'Dark', icon: Moon },
  { mode: 'auto', label: 'System', icon: Monitor },
]
</script>

<template>
  <div class="mx-auto max-w-2xl px-6 pb-16 pt-10 md:px-10">
    <h1 class="text-2xl font-semibold tracking-tight">Settings</h1>

    <section class="mt-8">
      <h2 class="font-medium">Appearance</h2>
      <div class="mt-3 inline-flex rounded-lg border bg-muted/50 p-1" role="radiogroup" aria-label="Theme">
        <button
          v-for="o in options"
          :key="o.mode"
          type="button"
          role="radio"
          :aria-checked="theme === o.mode"
          class="flex items-center gap-1.5 rounded-md px-3 py-1.5 text-muted-foreground transition-colors"
          :class="theme === o.mode && 'bg-background text-foreground shadow-xs'"
          @click="theme = o.mode"
        >
          <component :is="o.icon" class="size-4" />
          {{ o.label }}
        </button>
      </div>
    </section>

    <JournalSettings />
    <DataSettings />

    <section class="mt-10">
      <h2 class="font-medium">Account</h2>
      <dl class="mt-3 divide-y rounded-lg border bg-card">
        <div class="flex justify-between gap-4 px-4 py-3">
          <dt class="text-muted-foreground">Email</dt>
          <dd>{{ auth.user?.email_address }}</dd>
        </div>
        <div class="flex justify-between gap-4 px-4 py-3">
          <dt class="text-muted-foreground"><label for="tz">Time zone</label></dt>
          <dd>
            <select id="tz" class="h-8 max-w-56 rounded-md border bg-transparent px-2 text-sm" :value="auth.user?.time_zone" @change="setZone">
              <option v-if="auth.user && !zones.includes(auth.user.time_zone)" :value="auth.user.time_zone">{{ auth.user.time_zone }}</option>
              <option v-for="z in zones" :key="z" :value="z">{{ z.replace(/_/g, ' ') }}</option>
            </select>
          </dd>
        </div>
      </dl>
    </section>
  </div>
</template>
