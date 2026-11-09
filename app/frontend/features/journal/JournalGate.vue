<script setup lang="ts">
import { Loader2 } from '@lucide/vue'
import JournalSetup from './components/JournalSetup.vue'
import JournalUnlock from './components/JournalUnlock.vue'
import { useVault } from './useJournal'
import { journalSession } from './session'

/** Renders its slot only once the journal exists and is unlocked. */
const { data: vault, isPending } = useVault()
</script>

<template>
  <div v-if="isPending" class="flex justify-center pt-24 text-muted-foreground"><Loader2 class="size-5 animate-spin" /></div>
  <JournalSetup v-else-if="!vault" />
  <JournalUnlock v-else-if="!journalSession.state.unlocked" :vault="vault" />
  <slot v-else />
</template>
