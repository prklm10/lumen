<script setup lang="ts">
import { computed, ref } from 'vue'
import { useQueryClient } from '@tanstack/vue-query'
import { toast } from 'vue-sonner'
import { KeyRound, Loader2, RectangleEllipsis } from '@lucide/vue'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { journalApi } from '@/api/journal'
import { UnlockError, changePassphrase, rotateRecoveryKey } from '@/lib/crypto/journal'
import { errorMessage } from '@/composables/useTasks'
import { journalKeys, useVault } from '../useJournal'
import { useJournalLockSettings } from '../useJournalAutoLock'
import RecoveryKeyCard from './RecoveryKeyCard.vue'
import { useAuthStore } from '@/stores/auth'

/** Journal section of Settings: auto-lock, change passphrase (JRN-10), new recovery key. */
const client = useQueryClient()
const { data: vault } = useVault()
const { idleMinutes, lockOnHide } = useJournalLockSettings()
const auth = useAuthStore()

async function toggleMirror(event: Event) {
  const on = (event.target as HTMLInputElement).checked
  try {
    await auth.updateMe({ settings: { journal_mood_mirror: on } })
    toast(on ? 'Mood will be copied to the Mood tracker' : 'Mood stays only in the encrypted journal')
  } catch (e) {
    toast.error(errorMessage(e))
  }
}

const dialog = ref<'passphrase' | 'recovery' | null>(null)
const current = ref('')
const next = ref('')
const confirmation = ref('')
const loginPassword = ref('')
const busy = ref(false)
const error = ref<string | null>(null)
const newRecoveryKey = ref<string | null>(null)

const valid = computed(() =>
  current.value && loginPassword.value && (dialog.value === 'recovery' || (next.value.length >= 12 && next.value === confirmation.value)))

function open(kind: 'passphrase' | 'recovery') {
  current.value = next.value = confirmation.value = loginPassword.value = ''
  error.value = null
  newRecoveryKey.value = null
  dialog.value = kind
}

async function submit() {
  if (!vault.value || !valid.value || busy.value) return
  busy.value = true
  error.value = null
  try {
    if (dialog.value === 'passphrase') {
      const patch = await changePassphrase(vault.value, { passphrase: current.value }, next.value)
      client.setQueryData(journalKeys.vault, await journalApi.updateVault(loginPassword.value, patch))
      toast.success('Journal passphrase changed')
      dialog.value = null
    } else {
      const { recoveryKey, patch } = await rotateRecoveryKey(vault.value, current.value)
      client.setQueryData(journalKeys.vault, await journalApi.updateVault(loginPassword.value, patch))
      newRecoveryKey.value = recoveryKey
    }
  } catch (e) {
    error.value = e instanceof UnlockError ? 'Your current journal passphrase isn’t right.' : errorMessage(e)
  } finally {
    busy.value = false
    current.value = next.value = confirmation.value = loginPassword.value = ''
  }
}
</script>

<template>
  <section class="mt-10">
    <h2 class="font-medium">Journal</h2>
    <div class="mt-3 divide-y rounded-lg border bg-card">
      <label class="flex items-center justify-between gap-4 px-4 py-3">
        <span>
          <span class="block">Lock after inactivity</span>
          <span class="text-xs text-muted-foreground">On this device</span>
        </span>
        <select v-model.number="idleMinutes" class="h-8 rounded-md border bg-transparent px-2 text-sm">
          <option v-for="m in [1, 5, 10, 15, 30, 60]" :key="m" :value="m">{{ m }} {{ m === 1 ? 'minute' : 'minutes' }}</option>
        </select>
      </label>
      <label class="flex cursor-pointer items-center justify-between gap-4 px-4 py-3">
        <span>
          <span class="block">Lock when I switch tabs</span>
          <span class="text-xs text-muted-foreground">Locks as soon as Lumen is hidden</span>
        </span>
        <input v-model="lockOnHide" type="checkbox" class="size-4 accent-primary">
      </label>
      <label class="flex cursor-pointer items-start justify-between gap-4 px-4 py-3">
        <span>
          <span class="block">Also log mood to the Tracker</span>
          <span class="text-xs text-muted-foreground">
            Copies just the 1–5 mood of each entry to a Mood tracker so it shows up in analytics.
            <strong class="font-medium text-amber-600 dark:text-amber-500">That copy is not encrypted.</strong> The entry itself stays encrypted.
          </span>
        </span>
        <input type="checkbox" class="mt-1 size-4 accent-primary" :checked="!!auth.user?.settings.journal_mood_mirror" @change="toggleMirror">
      </label>
      <div v-if="vault" class="flex flex-wrap gap-2 px-4 py-3">
        <Button variant="outline" size="sm" @click="open('passphrase')"><RectangleEllipsis /> Change passphrase</Button>
        <Button variant="outline" size="sm" @click="open('recovery')"><KeyRound /> New recovery key</Button>
      </div>
    </div>

    <Dialog :open="dialog !== null" @update:open="(o) => !o && (dialog = null)">
      <DialogContent class="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{{ newRecoveryKey ? 'Your new recovery key' : dialog === 'passphrase' ? 'Change journal passphrase' : 'Create a new recovery key' }}</DialogTitle>
          <DialogDescription v-if="!newRecoveryKey">
            {{ dialog === 'passphrase' ? 'Your entries aren’t re-encrypted: only the key that unlocks them is re-wrapped.' : 'Your current recovery key will stop working.' }}
          </DialogDescription>
        </DialogHeader>

        <RecoveryKeyCard v-if="newRecoveryKey" :recovery-key="newRecoveryKey" @done="dialog = null" />
        <form v-else class="space-y-3" @submit.prevent="submit">
          <Input v-model="current" type="password" autocomplete="current-password" placeholder="Current journal passphrase" aria-label="Current journal passphrase" autofocus />
          <template v-if="dialog === 'passphrase'">
            <Input v-model="next" type="password" autocomplete="new-password" placeholder="New passphrase (12+ characters)" aria-label="New passphrase" />
            <Input v-model="confirmation" type="password" autocomplete="new-password" placeholder="Confirm new passphrase" aria-label="Confirm new passphrase" />
          </template>
          <Input v-model="loginPassword" type="password" autocomplete="current-password" placeholder="Lumen login password" aria-label="Login password" />
          <p v-if="error" class="text-sm text-destructive" role="alert">{{ error }}</p>
          <Button type="submit" class="w-full" :disabled="!valid || busy">
            <Loader2 v-if="busy" class="animate-spin" /> {{ dialog === 'passphrase' ? 'Change passphrase' : 'Create new recovery key' }}
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  </section>
</template>
