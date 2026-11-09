<script setup lang="ts">
import { ref } from 'vue'
import { useClipboard } from '@vueuse/core'
import { Check, Copy, Download, KeyRound } from '@lucide/vue'
import { Button } from '@/components/ui/button'

/** Shows a recovery key once (JRN-11). It can't be displayed again: the server never has it. */
const props = defineProps<{ recoveryKey: string }>()
const emit = defineEmits<{ done: [] }>()
const { copy, copied } = useClipboard({ legacy: false })
const confirmed = ref(false)

function download() {
  const text = `Lumen journal recovery key\n\n${props.recoveryKey}\n\nCreated ${new Date().toISOString().slice(0, 10)}.\nAnyone with this key can read your journal. Keep it somewhere safe and offline.\n`
  const url = URL.createObjectURL(new Blob([text], { type: 'text/plain' }))
  const a = Object.assign(document.createElement('a'), { href: url, download: 'lumen-journal-recovery-key.txt' })
  a.click()
  URL.revokeObjectURL(url)
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-start gap-3 rounded-lg border border-amber-500/30 bg-amber-500/5 p-4 text-sm">
      <KeyRound class="mt-0.5 size-4 shrink-0 text-amber-500" />
      <p>
        This is the <strong>only</strong> way back in if you forget your passphrase. Lumen can’t show it again or reset it for you.
        Print it or keep it in a password manager.
      </p>
    </div>
    <p class="select-all rounded-lg border bg-muted/40 px-4 py-4 text-center font-mono text-lg tracking-wider" data-testid="recovery-key">{{ recoveryKey }}</p>
    <div class="flex gap-2">
      <Button variant="outline" size="sm" @click="copy(recoveryKey)">
        <component :is="copied ? Check : Copy" /> {{ copied ? 'Copied' : 'Copy' }}
      </Button>
      <Button variant="outline" size="sm" @click="download"><Download /> Download .txt</Button>
    </div>
    <label class="flex cursor-pointer items-start gap-2 text-sm">
      <input v-model="confirmed" type="checkbox" class="mt-0.5 accent-primary">
      I’ve stored my recovery key somewhere safe.
    </label>
    <Button class="w-full" :disabled="!confirmed" @click="emit('done')">Continue to my journal</Button>
  </div>
</template>
