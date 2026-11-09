<script setup lang="ts">
import { computed, ref } from 'vue'
import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query'
import { toast } from 'vue-sonner'
import { BookMarked, BookOpen, Clapperboard, ExternalLink, FileText, GraduationCap, Headphones, Library, Pencil, Plus, Star, Timer, Trash2 } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { studyApi, type LearningResource, type ResourceStatus } from '@/api/study'
import { errorMessage } from '@/composables/useTasks'
import { useToday } from '@/composables/useToday'
import { colorClasses } from '@/lib/colors'
import { formatMinutes, relativeDay } from '@/lib/dates'
import EmptyState from '@/features/tasks/components/EmptyState.vue'
import PageHeader from '@/features/tasks/components/PageHeader.vue'
import ResourceDialog from './ResourceDialog.vue'

/** Topics, resources (LRN-8/9) and logged study time (LRN-10). */
const client = useQueryClient()
const { today } = useToday()
const { data: topics } = useQuery({ queryKey: ['topics'], queryFn: studyApi.topics })
const { data: resources, isPending } = useQuery({ queryKey: ['resources'], queryFn: studyApi.resources })
const { data: sessions } = useQuery({ queryKey: ['study_sessions'], queryFn: () => studyApi.sessions(30) })

const topicFilter = ref<number | null>(null)
const editing = ref<LearningResource | null>(null)
const dialogOpen = ref(false)
const newTopic = ref('')
const log = ref({ open: false, topic_id: null as number | null, resource_id: null as number | null, minutes: 30, notes: '' })

const refresh = () => Promise.all(['resources', 'study_sessions', 'topics', 'analytics'].map((k) => client.invalidateQueries({ queryKey: [k] })))
const onError = (e: unknown) => toast.error(errorMessage(e))
const save = useMutation({ mutationFn: studyApi.saveResource, onSuccess: refresh, onError })
const remove = useMutation({ mutationFn: studyApi.destroyResource, onSuccess: refresh, onError })
const createTopic = useMutation({ mutationFn: studyApi.createTopic, onSuccess: () => { newTopic.value = ''; refresh() }, onError })
const logSession = useMutation({ mutationFn: studyApi.logSession, onSuccess: () => { toast('Study time logged'); log.value.open = false; refresh() }, onError })
const removeSession = useMutation({ mutationFn: studyApi.destroySession, onSuccess: refresh, onError })

const kindIcon = { book: BookOpen, course: GraduationCap, video: Clapperboard, article: FileText, podcast: Headphones, other: BookMarked }
const groups: { status: ResourceStatus; label: string }[] = [{ status: 'in_progress', label: 'In progress' }, { status: 'to_learn', label: 'To learn' }, { status: 'done', label: 'Done' }]
const filtered = computed(() => (resources.value ?? []).filter((r) => topicFilter.value === null || r.topic_id === topicFilter.value))
const topicById = computed(() => new Map((topics.value ?? []).map((t) => [t.id, t])))
const minutesByTopic = computed(() => new Map((sessions.value?.by_topic ?? []).map((t) => [t.topic_id, t.minutes])))

function edit(r: LearningResource | null) {
  editing.value = r
  dialogOpen.value = true
}

function openLog(r?: LearningResource) {
  log.value = { open: true, topic_id: r?.topic_id ?? topicFilter.value, resource_id: r?.id ?? null, minutes: 30, notes: '' }
}
</script>

<template>
  <div class="mx-auto max-w-4xl px-6 pb-24 pt-8 md:px-10">
    <PageHeader title="Resources" subtitle="What you’re learning from, and the time you put in.">
      <template #actions>
        <Button variant="outline" size="sm" @click="openLog()"><Timer /> Log study</Button>
        <Button size="sm" @click="edit(null)"><Plus /> Add resource</Button>
      </template>
    </PageHeader>

    <div class="mb-6 flex flex-wrap items-center gap-1.5">
      <button type="button" class="rounded-full border px-3 py-1 text-xs" :class="topicFilter === null ? 'border-primary bg-primary/10 text-primary' : 'hover:bg-accent'" @click="topicFilter = null">All topics</button>
      <button
        v-for="t in topics"
        :key="t.id"
        type="button"
        class="inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs"
        :class="topicFilter === t.id ? 'border-primary bg-primary/10 text-primary' : 'hover:bg-accent'"
        @click="topicFilter = topicFilter === t.id ? null : t.id"
      >
        <span class="size-2 rounded-full" :class="colorClasses(t.color).dot" /> {{ t.name }}
        <span v-if="minutesByTopic.get(t.id)" class="text-muted-foreground">{{ formatMinutes(minutesByTopic.get(t.id)!) }}</span>
      </button>
      <form class="inline-flex" @submit.prevent="newTopic.trim() && createTopic.mutate({ name: newTopic.trim() })">
        <input v-model="newTopic" class="w-28 rounded-full border border-dashed bg-transparent px-3 py-1 text-xs outline-none focus:border-primary" placeholder="+ New topic" maxlength="60" aria-label="New topic">
      </form>
    </div>

    <div v-if="isPending" class="space-y-3"><div v-for="i in 3" :key="i" class="h-16 animate-pulse rounded-xl bg-muted/60" /></div>
    <EmptyState v-else-if="!filtered.length" :icon="Library" title="No resources yet" body="Track books, courses, videos and articles: progress, rating and time spent.">
      <Button class="mt-5" size="sm" @click="edit(null)"><Plus /> Add your first resource</Button>
    </EmptyState>
    <template v-else>
      <section v-for="g in groups" :key="g.status" class="mb-8">
        <template v-if="filtered.some((r) => r.status === g.status)">
          <h2 class="mb-2 text-sm font-medium text-muted-foreground">{{ g.label }}</h2>
          <ul class="divide-y rounded-xl border bg-card">
            <li v-for="r in filtered.filter((x) => x.status === g.status)" :key="r.id" class="group flex items-center gap-3 px-4 py-3">
              <component :is="kindIcon[r.kind]" class="size-4 shrink-0 text-muted-foreground" />
              <div class="min-w-0 flex-1">
                <div class="flex items-center gap-1.5">
                  <span class="truncate font-medium">{{ r.title }}</span>
                  <a v-if="r.url" :href="r.url" target="_blank" rel="noopener noreferrer" class="text-muted-foreground hover:text-foreground" :aria-label="`Open ${r.title}`"><ExternalLink class="size-3.5" /></a>
                </div>
                <div class="mt-0.5 flex flex-wrap items-center gap-x-3 text-xs text-muted-foreground">
                  <span v-if="r.topic_id && topicById.get(r.topic_id)" class="inline-flex items-center gap-1"><span class="size-1.5 rounded-full" :class="colorClasses(topicById.get(r.topic_id)!.color).dot" />{{ topicById.get(r.topic_id)!.name }}</span>
                  <span v-if="r.minutes_studied">{{ formatMinutes(r.minutes_studied) }} studied</span>
                  <span v-if="r.finished_on">Finished {{ relativeDay(r.finished_on, today).toLowerCase() }}</span>
                  <span v-if="r.rating" class="inline-flex"><Star v-for="n in r.rating" :key="n" class="size-3 fill-amber-400 text-amber-400" /></span>
                </div>
              </div>
              <div v-if="r.status === 'in_progress'" class="hidden w-28 items-center gap-2 sm:flex" :title="`${r.progress}%`">
                <span class="h-1.5 flex-1 rounded-full bg-muted"><span class="block h-full rounded-full bg-primary" :style="{ width: `${r.progress}%` }" /></span>
                <span class="w-8 text-right text-xs tabular-nums text-muted-foreground">{{ r.progress }}%</span>
              </div>
              <div class="flex opacity-0 group-hover:opacity-100 focus-within:opacity-100">
                <Button v-if="r.status !== 'done'" variant="ghost" size="icon-sm" :aria-label="`Log study for ${r.title}`" title="Log study" @click="openLog(r)"><Timer /></Button>
                <Button variant="ghost" size="icon-sm" :aria-label="`Edit ${r.title}`" @click="edit(r)"><Pencil /></Button>
                <Button variant="ghost" size="icon-sm" :aria-label="`Delete ${r.title}`" @click="remove.mutate(r.id)"><Trash2 /></Button>
              </div>
            </li>
          </ul>
        </template>
      </section>
    </template>

    <section v-if="sessions?.sessions.length" class="mt-4">
      <h2 class="mb-2 text-sm font-medium text-muted-foreground">Last 30 days · {{ formatMinutes(sessions.total_minutes) }} studied</h2>
      <ul class="divide-y rounded-xl border bg-card text-sm">
        <li v-for="s in sessions.sessions.slice(0, 10)" :key="s.id" class="group flex items-center gap-3 px-4 py-2">
          <span class="w-20 shrink-0 text-muted-foreground">{{ relativeDay(s.studied_on, today) }}</span>
          <span class="w-14 shrink-0 font-medium tabular-nums">{{ formatMinutes(s.duration_minutes) }}</span>
          <span class="min-w-0 flex-1 truncate text-muted-foreground">
            {{ [s.topic_id && topicById.get(s.topic_id)?.name, s.resource_id && resources?.find((r) => r.id === s.resource_id)?.title, s.notes].filter(Boolean).join(' · ') }}
          </span>
          <button type="button" class="text-muted-foreground opacity-0 hover:text-destructive group-hover:opacity-100" aria-label="Delete session" @click="removeSession.mutate(s.id)"><Trash2 class="size-3.5" /></button>
        </li>
      </ul>
    </section>

    <ResourceDialog v-model:open="dialogOpen" :resource="editing" :topics="topics ?? []" :default-topic-id="topicFilter" @save="save.mutate" />

    <div v-if="log.open" class="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-4 sm:items-center" @click.self="log.open = false">
      <form class="w-full max-w-sm space-y-4 rounded-xl border bg-background p-5 shadow-xl" @submit.prevent="logSession.mutate({ topic_id: log.topic_id, resource_id: log.resource_id, duration_minutes: log.minutes, notes: log.notes || null })" @keydown.esc="log.open = false">
        <h2 class="font-semibold">Log study time</h2>
        <label class="block space-y-1.5 text-sm"><span class="font-medium">Resource</span>
          <select v-model="log.resource_id" class="h-9 w-full rounded-md border bg-transparent px-2"><option :value="null">None</option><option v-for="r in (resources ?? []).filter((x) => x.status !== 'done')" :key="r.id" :value="r.id">{{ r.title }}</option></select>
        </label>
        <label v-if="!log.resource_id" class="block space-y-1.5 text-sm"><span class="font-medium">Topic</span>
          <select v-model="log.topic_id" class="h-9 w-full rounded-md border bg-transparent px-2"><option :value="null">None</option><option v-for="t in topics" :key="t.id" :value="t.id">{{ t.name }}</option></select>
        </label>
        <div class="space-y-1.5 text-sm">
          <span class="font-medium">Minutes</span>
          <div class="flex gap-1.5">
            <button v-for="m in [15, 30, 45, 60, 90]" :key="m" type="button" class="flex-1 rounded-md border py-1.5 text-xs" :class="log.minutes === m ? 'border-primary bg-primary text-primary-foreground' : 'hover:bg-accent'" @click="log.minutes = m">{{ m }}</button>
            <input v-model.number="log.minutes" type="number" min="1" max="1440" class="w-16 rounded-md border bg-transparent px-2 text-xs" aria-label="Minutes">
          </div>
        </div>
        <input v-model="log.notes" class="h-9 w-full rounded-md border bg-transparent px-2 text-sm" placeholder="What did you cover? (optional)" aria-label="Notes">
        <div class="flex justify-end gap-2"><Button type="button" variant="ghost" @click="log.open = false">Cancel</Button><Button type="submit" :disabled="!log.minutes">Log</Button></div>
      </form>
    </div>
  </div>
</template>
