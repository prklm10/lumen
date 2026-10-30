<script setup lang="ts">
import { useRouter } from 'vue-router'
import { LogOut, Monitor, Moon, Sun } from '@lucide/vue'
import {
  CommandDialog, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList, CommandSeparator, CommandShortcut,
} from '@/components/ui/command'
import { primaryNav, settingsNav, type NavItem } from '@/lib/navigation'
import { useTheme, type ThemeMode } from '@/composables/useTheme'
import { useAuthStore } from '@/stores/auth'

const open = defineModel<boolean>('open', { required: true })
const router = useRouter()
const auth = useAuthStore()
const { store: theme } = useTheme()

const themes: { mode: ThemeMode; label: string; icon: typeof Sun }[] = [
  { mode: 'light', label: 'Light theme', icon: Sun },
  { mode: 'dark', label: 'Dark theme', icon: Moon },
  { mode: 'auto', label: 'System theme', icon: Monitor },
]

function run(action: () => unknown) {
  open.value = false
  action()
}

function go(item: NavItem) {
  run(() => router.push(item.path))
}

async function signOut() {
  await auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <CommandDialog v-model:open="open" title="Command palette" description="Jump anywhere or run an action">
    <CommandInput placeholder="Type a command or search…" />
    <CommandList>
      <CommandEmpty>No results.</CommandEmpty>
      <CommandGroup heading="Go to">
        <CommandItem v-for="item in [...primaryNav, settingsNav]" :key="item.name" :value="`Go to ${item.label}`" @select="go(item)">
          <component :is="item.icon" />
          {{ item.label }}
          <CommandShortcut v-if="item.shortcut">G {{ item.shortcut.toUpperCase() }}</CommandShortcut>
        </CommandItem>
      </CommandGroup>
      <CommandSeparator />
      <CommandGroup heading="Preferences">
        <CommandItem v-for="t in themes" :key="t.mode" :value="t.label" @select="run(() => (theme = t.mode))">
          <component :is="t.icon" />
          {{ t.label }}
        </CommandItem>
      </CommandGroup>
      <CommandSeparator />
      <CommandGroup heading="Account">
        <CommandItem value="Sign out" @select="run(signOut)"><LogOut /> Sign out</CommandItem>
      </CommandGroup>
    </CommandList>
  </CommandDialog>
</template>
