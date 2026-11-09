<script setup lang="ts">
import { computed, reactive, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import type { Frequency, Tracker, TrackerKind } from '@/api/trackers'
import { useTrackerMutations } from '@/composables/useTrackers'
import { colorClasses, colorNames } from '@/lib/colors'
import { WEEKDAYS, kindLabels } from '@/lib/trackers'

/** Create a tracker, or edit one (TRK-1, TRK-2). The kind can't change once there's history. */
const props = defineProps<{ tracker?: Tracker | null }>()
const open = defineModel<boolean>('open', { required: true })

const router = useRouter()
const { create, update } = useTrackerMutations()
const icons = ['✅', '💧', '🏃', '🧘', '📚', '💪', '😴', '🥗', '🚭', '💊', '✍️', '🎸', '🧹', '🌱', '☀️', '⚡️', '😊', '🦷']

const form = reactive({
  name: '', icon: '✅' as string | null, color: 'green', kind: 'boolean' as TrackerKind, unit: '', target: '' as string | number,
  frequencyType: 'daily' as Frequency['type'], days: [1, 2, 3, 4, 5] as number[], times: 3,
})

watch(open, (isOpen) => {
  if (!isOpen) return
  const t = props.tracker
  Object.assign(form, {
    name: t?.name ?? '', icon: t?.icon ?? '✅', color: t?.color ?? 'green', kind: t?.kind ?? 'boolean', unit: t?.unit ?? '',
    target: t?.target ?? '', frequencyType: t?.frequency.type ?? 'daily',
    days: t?.frequency.type === 'weekdays' ? [...t.frequency.days] : [1, 2, 3, 4, 5],
    times: t?.frequency.type === 'weekly' ? t.frequency.times : 3,
  })
})

const hasTarget = computed(() => form.kind !== 'boolean')
const hasUnit = computed(() => form.kind === 'count' || form.kind === 'numeric')
const frequency = computed<Frequency>(() =>
  form.frequencyType === 'weekdays' ? { type: 'weekdays', days: [...form.days].sort() }
    : form.frequencyType === 'weekly' ? { type: 'weekly', times: form.times }
    : { type: 'daily' })
const valid = computed(() => form.name.trim() && (form.frequencyType !== 'weekdays' || form.days.length))

function toggleDay(day: number) {
  form.days = form.days.includes(day) ? form.days.filter((d) => d !== day) : [...form.days, day]
}

async function submit() {
  if (!valid.value) return
  const input = {
    name: form.name.trim(), icon: form.icon, color: form.color, kind: form.kind,
    unit: hasUnit.value ? form.unit.trim() || null : null,
    target: hasTarget.value && form.target !== '' ? Number(form.target) : null,
    frequency: frequency.value,
  }
  if (props.tracker) await update.mutateAsync({ id: props.tracker.id, input })
  else await create.mutateAsync(input)
  open.value = false
  if (!props.tracker) router.push({ name: 'tracker' })
}
</script>

<template>
  <Dialog v-model:open="open">
    <DialogContent class="max-h-[90dvh] overflow-y-auto sm:max-w-lg">
      <DialogHeader>
        <DialogTitle>{{ tracker ? 'Edit tracker' : 'New tracker' }}</DialogTitle>
        <DialogDescription>Habits and daily numbers. Tracker data isn’t encrypted, so it can power your analytics.</DialogDescription>
      </DialogHeader>

      <form id="tracker-form" class="space-y-5" @submit.prevent="submit">
        <div class="flex gap-3">
          <div class="space-y-2">
            <Label>Icon</Label>
            <div class="flex size-9 items-center justify-center rounded-md border text-lg">{{ form.icon }}</div>
          </div>
          <div class="flex-1 space-y-2">
            <Label for="tracker-name">Name</Label>
            <Input id="tracker-name" v-model="form.name" maxlength="60" placeholder="e.g. Drink water" autofocus />
          </div>
        </div>
        <div class="flex flex-wrap gap-1" role="radiogroup" aria-label="Icon">
          <button
            v-for="icon in icons"
            :key="icon"
            type="button"
            role="radio"
            :aria-checked="form.icon === icon"
            class="flex size-8 items-center justify-center rounded-md text-base"
            :class="form.icon === icon ? 'bg-accent ring-1 ring-ring' : 'hover:bg-accent'"
            @click="form.icon = icon"
          >
            {{ icon }}
          </button>
        </div>

        <div class="space-y-2">
          <Label>Type</Label>
          <div class="grid grid-cols-2 gap-2 sm:grid-cols-3" role="radiogroup" aria-label="Type">
            <button
              v-for="(meta, kind) in kindLabels"
              :key="kind"
              type="button"
              role="radio"
              :aria-checked="form.kind === kind"
              :disabled="!!tracker && tracker.kind !== kind"
              class="rounded-lg border p-2.5 text-left disabled:opacity-40"
              :class="form.kind === kind ? 'border-primary bg-primary/5 ring-1 ring-primary' : 'hover:bg-accent'"
              @click="form.kind = kind"
            >
              <span class="block text-sm font-medium">{{ meta.label }}</span>
              <span class="block text-xs text-muted-foreground">{{ meta.hint }}</span>
            </button>
          </div>
        </div>

        <div v-if="hasTarget || hasUnit" class="grid grid-cols-2 gap-3">
          <div v-if="hasTarget" class="space-y-2">
            <Label for="tracker-target">Daily goal <span class="font-normal text-muted-foreground">(at least)</span></Label>
            <div class="flex items-center gap-2">
              <Input id="tracker-target" v-model="form.target" type="number" min="0" step="any" :placeholder="form.kind === 'duration' ? '30' : 'optional'" />
              <span v-if="form.kind === 'duration'" class="text-sm text-muted-foreground">min</span>
            </div>
          </div>
          <div v-if="hasUnit" class="space-y-2">
            <Label for="tracker-unit">Unit</Label>
            <Input id="tracker-unit" v-model="form.unit" maxlength="20" placeholder="glasses, km, hours" />
          </div>
        </div>

        <div class="space-y-2">
          <Label>How often</Label>
          <div class="flex gap-1 rounded-lg bg-muted p-1 text-sm" role="radiogroup" aria-label="Frequency">
            <button
              v-for="option in [{ v: 'daily', l: 'Every day' }, { v: 'weekdays', l: 'Some days' }, { v: 'weekly', l: 'Times a week' }] as const"
              :key="option.v"
              type="button"
              role="radio"
              :aria-checked="form.frequencyType === option.v"
              class="flex-1 rounded-md px-2 py-1.5"
              :class="form.frequencyType === option.v ? 'bg-background font-medium shadow-xs' : 'text-muted-foreground'"
              @click="form.frequencyType = option.v"
            >
              {{ option.l }}
            </button>
          </div>
          <div v-if="form.frequencyType === 'weekdays'" class="flex gap-1 pt-1">
            <button
              v-for="(day, i) in WEEKDAYS"
              :key="day"
              type="button"
              :aria-pressed="form.days.includes(i + 1)"
              class="h-8 flex-1 rounded-md border text-xs"
              :class="form.days.includes(i + 1) ? 'border-primary bg-primary text-primary-foreground' : 'hover:bg-accent'"
              @click="toggleDay(i + 1)"
            >
              {{ day }}
            </button>
          </div>
          <label v-if="form.frequencyType === 'weekly'" class="flex items-center gap-2 pt-1 text-sm">
            <Input v-model.number="form.times" type="number" min="1" max="7" class="w-20" aria-label="Times per week" /> times a week
          </label>
        </div>

        <div class="space-y-2">
          <Label>Color</Label>
          <div class="flex flex-wrap gap-2" role="radiogroup" aria-label="Color">
            <button
              v-for="name in colorNames"
              :key="name"
              type="button"
              role="radio"
              :aria-checked="form.color === name"
              :aria-label="name"
              class="size-6 rounded-full ring-offset-2 ring-offset-background"
              :class="[colorClasses(name).dot, form.color === name ? 'ring-2 ring-ring' : 'hover:scale-110']"
              @click="form.color = name"
            />
          </div>
        </div>
      </form>

      <DialogFooter>
        <Button variant="ghost" @click="open = false">Cancel</Button>
        <Button type="submit" form="tracker-form" :disabled="!valid || create.isPending.value || update.isPending.value">
          {{ tracker ? 'Save' : 'Create tracker' }}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
