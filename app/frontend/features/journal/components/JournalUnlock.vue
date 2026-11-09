<script setup lang="ts">
import { computed, ref } from 'vue'
import { useQueryClient } from '@tanstack/vue-query'
import { Loader2, Lock } from '@lucide/vue'
import { toast } from 'vue-sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { journalApi } from '@/api/journal'
import { UnlockError, changePassphrase, unlockWithPassphrase, unlockWithRecoveryKey, type VaultRecord } from '@/lib/crypto/journal'
import { errorMessage } from '@/composables/useTasks'
import { journalKeys } from '../useJournal'
import { journalSession } from '../session'

/** Unlock with the passphrase, or with the recovery key and then choose a new passphrase. */
const props = defineProps<{ vault: VaultRecord }>()
const client = useQueryClient()

const mode = ref<'passphrase' | 'recovery' | 'reset'>('passphrase')
const secret = ref('')
const busy = ref(false)
const error = ref<string | null>(null)
const recoveryKey = ref('')
const newPassphrase = ref('')
const newConfirmation = ref('')
const loginPassword = ref('')
let recoveredKey: CryptoKey | null = null

const resetValid = computed(() => newPassphrase.value.length >= 12 && newPassphrase.value === newConfirmation.value && loginPassword.value)

async function unlock() {
  if (!secret.value || busy.value) return
  busy.value = true
  error.value = null
  try {
    if (mode.value === 'passphrase') {
      journalSession.unlock(await unlockWithPassphrase(props.vault, secret.value))
    } else {
      recoveredKey = await unlockWithRecoveryKey(props.vault, secret.value)
      recoveryKey.value = secret.value
      mode.value = 'reset'
    }
    secret.value = ''
  } catch (e) {
    error.value = e instanceof UnlockError ? (mode.value === 'passphrase' ? 'Wrong passphrase.' : e.message) : errorMessage(e)
  } finally {
    busy.value = false
  }
}

async function reset() {
  if (!resetValid.value || busy.value) return
  busy.value = true
  error.value = null
  try {
    const patch = await changePassphrase(props.vault, { recoveryKey: recoveryKey.value }, newPassphrase.value)
    const vault = await journalApi.updateVault(loginPassword.value, patch)
    client.setQueryData(journalKeys.vault, vault)
    journalSession.unlock(recoveredKey!)
    toast.success('New passphrase set', { description: 'Your recovery key still works.' })
  } catch (e) {
    error.value = errorMessage(e)
  } finally {
    busy.value = false
    newPassphrase.value = newConfirmation.value = loginPassword.value = ''
  }
}

function switchTo(next: 'passphrase' | 'recovery') {
  mode.value = next
  secret.value = ''
  error.value = null
}
</script>

<template>
  <div class="mx-auto max-w-sm px-6 pb-24 pt-20 text-center">
    <div class="mx-auto mb-6 flex size-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
      <Lock class="size-6" />
    </div>

    <template v-if="mode !== 'reset'">
      <h1 class="text-xl font-semibold tracking-tight">Journal locked</h1>
      <p class="mt-1.5 text-sm text-muted-foreground">
        {{ mode === 'passphrase' ? 'Enter your journal passphrase to decrypt your entries on this device.' : 'Enter the recovery key you saved when you set up your journal.' }}
      </p>
      <form class="mt-6 space-y-3 text-left" @submit.prevent="unlock">
        <Label :for="`unlock-${mode}`" class="sr-only">{{ mode === 'passphrase' ? 'Passphrase' : 'Recovery key' }}</Label>
        <Input
          :id="`unlock-${mode}`"
          v-model="secret"
          :type="mode === 'passphrase' ? 'password' : 'text'"
          :autocomplete="mode === 'passphrase' ? 'current-password' : 'off'"
          :placeholder="mode === 'passphrase' ? 'Passphrase' : 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-X'"
          :class="mode === 'recovery' && 'font-mono'"
          autofocus
        />
        <p v-if="error" class="text-sm text-destructive" role="alert">{{ error }}</p>
        <Button type="submit" class="w-full" :disabled="!secret || busy">
          <Loader2 v-if="busy" class="animate-spin" /> {{ busy ? 'Unlocking…' : 'Unlock' }}
        </Button>
      </form>
      <button type="button" class="mt-4 text-xs text-muted-foreground hover:text-foreground" @click="switchTo(mode === 'passphrase' ? 'recovery' : 'passphrase')">
        {{ mode === 'passphrase' ? 'Forgot your passphrase? Use your recovery key' : 'Use my passphrase instead' }}
      </button>
    </template>

    <template v-else>
      <h1 class="text-xl font-semibold tracking-tight">Choose a new passphrase</h1>
      <p class="mt-1.5 text-sm text-muted-foreground">Your recovery key worked. Set a new journal passphrase; your entries stay as they are.</p>
      <form class="mt-6 space-y-3 text-left" @submit.prevent="reset">
        <Input v-model="newPassphrase" type="password" autocomplete="new-password" placeholder="New passphrase (12+ characters)" aria-label="New passphrase" autofocus />
        <Input v-model="newConfirmation" type="password" autocomplete="new-password" placeholder="Confirm new passphrase" aria-label="Confirm new passphrase" />
        <Input v-model="loginPassword" type="password" autocomplete="current-password" placeholder="Your Lumen login password" aria-label="Login password" />
        <p v-if="error" class="text-sm text-destructive" role="alert">{{ error }}</p>
        <Button type="submit" class="w-full" :disabled="!resetValid || busy">
          <Loader2 v-if="busy" class="animate-spin" /> Save new passphrase
        </Button>
      </form>
    </template>
  </div>
</template>
