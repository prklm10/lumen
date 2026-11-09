<script setup lang="ts">
import { computed, ref } from 'vue'
import { useQueryClient } from '@tanstack/vue-query'
import { Loader2, LockKeyhole, ServerOff, ShieldCheck } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { journalApi } from '@/api/journal'
import { createVault } from '@/lib/crypto/journal'
import { errorMessage } from '@/composables/useTasks'
import { journalKeys } from '../useJournal'
import { journalSession } from '../session'
import RecoveryKeyCard from './RecoveryKeyCard.vue'

/** First run (JRN-1): choose a journal passphrase, then save the recovery key (JRN-11). */
const client = useQueryClient()
const passphrase = ref('')
const confirmation = ref('')
const busy = ref(false)
const error = ref<string | null>(null)
const recoveryKey = ref<string | null>(null)
let pendingKey: CryptoKey | null = null

const MIN = 12
const strength = computed(() => {
  const p = passphrase.value
  const classes = [/[a-z]/, /[A-Z]/, /\d/, /[^A-Za-z0-9]/].filter((r) => r.test(p)).length
  const score = (p.length >= MIN ? 1 : 0) + (p.length >= 16 ? 1 : 0) + (p.length >= 24 ? 1 : 0) + (classes >= 3 ? 1 : 0)
  return { score, label: ['Too short', 'Okay', 'Good', 'Strong', 'Excellent'][score]! }
})
const valid = computed(() => passphrase.value.length >= MIN && passphrase.value === confirmation.value)

async function submit() {
  if (!valid.value || busy.value) return
  busy.value = true
  error.value = null
  try {
    const { record, recoveryKey: key, key: sessionKey } = await createVault(passphrase.value)
    await journalApi.createVault(record)
    passphrase.value = confirmation.value = ''
    pendingKey = sessionKey
    recoveryKey.value = key
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    busy.value = false
  }
}

function finish() {
  if (pendingKey) journalSession.unlock(pendingKey)
  pendingKey = null
  recoveryKey.value = null
  client.invalidateQueries({ queryKey: journalKeys.vault })
}
</script>

<template>
  <div class="mx-auto max-w-md px-6 pb-24 pt-14">
    <div class="mb-8 flex size-12 items-center justify-center rounded-2xl bg-primary/10 text-primary">
      <LockKeyhole class="size-6" />
    </div>

    <template v-if="!recoveryKey">
      <h1 class="text-2xl font-semibold tracking-tight">Your private journal</h1>
      <p class="mt-2 text-muted-foreground">Entries are encrypted in this browser before they’re saved. Choose a passphrase that’s different from your login password.</p>

      <ul class="mt-6 space-y-2.5 text-sm">
        <li class="flex gap-2.5"><ShieldCheck class="mt-0.5 size-4 shrink-0 text-green-600" /> AES-256 encryption; the key is derived from your passphrase with Argon2id.</li>
        <li class="flex gap-2.5"><ServerOff class="mt-0.5 size-4 shrink-0 text-green-600" /> The server and database only ever see ciphertext.</li>
      </ul>

      <form class="mt-8 space-y-4" @submit.prevent="submit">
        <div class="space-y-2">
          <Label for="journal-passphrase">Journal passphrase</Label>
          <Input id="journal-passphrase" v-model="passphrase" type="password" autocomplete="new-password" :minlength="MIN" autofocus />
          <div class="flex items-center gap-2">
            <div class="flex flex-1 gap-1">
              <span v-for="i in 4" :key="i" class="h-1 flex-1 rounded-full" :class="i <= strength.score ? (strength.score >= 3 ? 'bg-green-500' : 'bg-amber-500') : 'bg-muted'" />
            </div>
            <span class="w-16 text-right text-xs text-muted-foreground">{{ passphrase ? strength.label : `${MIN}+ chars` }}</span>
          </div>
        </div>
        <div class="space-y-2">
          <Label for="journal-passphrase-confirm">Confirm passphrase</Label>
          <Input id="journal-passphrase-confirm" v-model="confirmation" type="password" autocomplete="new-password" />
          <p v-if="confirmation && confirmation !== passphrase" class="text-xs text-destructive">Passphrases don’t match.</p>
        </div>
        <p class="text-xs text-muted-foreground">Tip: a few unrelated words (“lamp orbit pickle sunday”) are easy to remember and hard to guess.</p>
        <p v-if="error" class="text-sm text-destructive" role="alert">{{ error }}</p>
        <Button type="submit" class="w-full" :disabled="!valid || busy">
          <Loader2 v-if="busy" class="animate-spin" /> {{ busy ? 'Deriving key…' : 'Create my journal' }}
        </Button>
      </form>
    </template>

    <template v-else>
      <h1 class="text-2xl font-semibold tracking-tight">Save your recovery key</h1>
      <p class="mt-2 mb-6 text-muted-foreground">Your journal is ready.</p>
      <RecoveryKeyCard :recovery-key="recoveryKey" @done="finish" />
    </template>
  </div>
</template>
