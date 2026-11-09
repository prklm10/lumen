<script setup lang="ts">
import { reactive, watch } from 'vue'
import { Star } from '@lucide/vue'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import type { LearningResource, ResourceKind, ResourceStatus, Topic } from '@/api/study'

const props = defineProps<{ resource?: LearningResource | null; topics: Topic[]; defaultTopicId?: number | null }>()
const open = defineModel<boolean>('open', { required: true })
const emit = defineEmits<{ save: [resource: Partial<LearningResource>] }>()

const kinds: ResourceKind[] = ['book', 'course', 'video', 'article', 'podcast', 'other']
const statuses: { v: ResourceStatus; l: string }[] = [{ v: 'to_learn', l: 'To learn' }, { v: 'in_progress', l: 'In progress' }, { v: 'done', l: 'Done' }]
const form = reactive<Partial<LearningResource>>({})

watch(open, (o) => {
  if (!o) return
  const r = props.resource
  Object.assign(form, { id: r?.id, title: r?.title ?? '', url: r?.url ?? '', kind: r?.kind ?? 'book', status: r?.status ?? 'to_learn', progress: r?.progress ?? 0, rating: r?.rating ?? null, topic_id: r?.topic_id ?? props.defaultTopicId ?? null })
})

function submit() {
  if (!form.title?.trim()) return
  emit('save', { ...form, title: form.title.trim(), url: form.url?.trim() || null })
  open.value = false
}
</script>

<template>
  <Dialog v-model:open="open">
    <DialogContent class="sm:max-w-lg">
      <DialogHeader>
        <DialogTitle>{{ resource ? 'Edit resource' : 'Add a resource' }}</DialogTitle>
        <DialogDescription>A book, course, video or article you’re learning from.</DialogDescription>
      </DialogHeader>
      <form id="resource-form" class="space-y-4" @submit.prevent="submit">
        <div class="space-y-2"><Label for="res-title">Title</Label><Input id="res-title" v-model="form.title" maxlength="300" autofocus /></div>
        <div class="space-y-2"><Label for="res-url">Link</Label><input id="res-url" v-model="form.url" type="url" placeholder="https://" class="h-9 w-full rounded-md border bg-transparent px-3 text-sm"></div>
        <div class="grid grid-cols-2 gap-3">
          <label class="space-y-2 text-sm"><span class="font-medium">Type</span>
            <select v-model="form.kind" class="h-9 w-full rounded-md border bg-transparent px-2 capitalize"><option v-for="k in kinds" :key="k" :value="k">{{ k }}</option></select>
          </label>
          <label class="space-y-2 text-sm"><span class="font-medium">Topic</span>
            <select v-model="form.topic_id" class="h-9 w-full rounded-md border bg-transparent px-2"><option :value="null">None</option><option v-for="t in topics" :key="t.id" :value="t.id">{{ t.name }}</option></select>
          </label>
        </div>
        <div class="space-y-2">
          <Label>Status</Label>
          <div class="flex gap-1 rounded-lg bg-muted p-1 text-sm">
            <button v-for="s in statuses" :key="s.v" type="button" class="flex-1 rounded-md py-1" :class="form.status === s.v ? 'bg-background font-medium shadow-xs' : 'text-muted-foreground'" @click="form.status = s.v">{{ s.l }}</button>
          </div>
        </div>
        <label v-if="form.status === 'in_progress'" class="flex items-center gap-3 text-sm">
          <span class="font-medium">Progress</span>
          <input v-model.number="form.progress" type="range" min="0" max="100" step="5" class="flex-1 accent-primary">
          <span class="w-10 text-right tabular-nums">{{ form.progress }}%</span>
        </label>
        <div v-if="form.status === 'done'" class="flex items-center gap-2 text-sm">
          <span class="font-medium">Rating</span>
          <button v-for="n in 5" :key="n" type="button" :aria-label="`${n} stars`" @click="form.rating = form.rating === n ? null : n">
            <Star class="size-5" :class="(form.rating ?? 0) >= n ? 'fill-amber-400 text-amber-400' : 'text-muted-foreground'" />
          </button>
        </div>
      </form>
      <DialogFooter>
        <Button variant="ghost" @click="open = false">Cancel</Button>
        <Button type="submit" form="resource-form" :disabled="!form.title?.trim()">Save</Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
