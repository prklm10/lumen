<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { ChevronsUpDown, LogOut, Monitor, Moon, Settings, Sun } from '@lucide/vue'
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuRadioGroup,
  DropdownMenuRadioItem, DropdownMenuSeparator, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import LumenLogo from '@/components/layout/LumenLogo.vue'
import { useAuthStore } from '@/stores/auth'
import { useTheme } from '@/composables/useTheme'

const auth = useAuthStore()
const router = useRouter()
const { store: theme } = useTheme()
const email = computed(() => auth.user?.email_address ?? '')

async function signOut() {
  await auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <DropdownMenu>
    <DropdownMenuTrigger
      class="flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left hover:bg-sidebar-accent focus-visible:ring-2 focus-visible:ring-ring/50 outline-none"
    >
      <LumenLogo :size="22" />
      <span class="flex-1 truncate font-semibold text-sidebar-accent-foreground">Lumen</span>
      <ChevronsUpDown class="size-3.5 text-muted-foreground" />
    </DropdownMenuTrigger>
    <DropdownMenuContent align="start" class="w-60">
      <DropdownMenuLabel class="truncate font-normal text-muted-foreground">{{ email }}</DropdownMenuLabel>
      <DropdownMenuSeparator />
      <DropdownMenuLabel class="text-xs text-muted-foreground">Theme</DropdownMenuLabel>
      <DropdownMenuRadioGroup v-model="theme">
        <DropdownMenuRadioItem value="light"><Sun /> Light</DropdownMenuRadioItem>
        <DropdownMenuRadioItem value="dark"><Moon /> Dark</DropdownMenuRadioItem>
        <DropdownMenuRadioItem value="auto"><Monitor /> System</DropdownMenuRadioItem>
      </DropdownMenuRadioGroup>
      <DropdownMenuSeparator />
      <DropdownMenuItem @select="router.push({ name: 'settings' })"><Settings /> Settings</DropdownMenuItem>
      <DropdownMenuItem @select="signOut"><LogOut /> Sign out</DropdownMenuItem>
    </DropdownMenuContent>
  </DropdownMenu>
</template>
