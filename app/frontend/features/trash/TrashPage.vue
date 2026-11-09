<script setup lang="ts">
import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query'
import { toast } from 'vue-sonner'
import { CheckSquare, FileText, RotateCcw, Trash2 } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { api } from '@/api/client'
import { useToday } from '@/composables/useToday'
import { errorMessage } from '@/composables/useTasks'
import { relativeDay, todayIn } from '@/lib/dates'
import EmptyState from '@/features/tasks/components/EmptyState.vue'
import PageHeader from '@/features/tasks/components/PageHeader.vue'

/** GLB-5: deleted tasks and notes, restorable until they're purged. */
interface TrashItem { type: 'task' | 'note'; id: number; title: string; icon?: string | null; discarded_at: string }

const client = useQueryClient()
const { today, timeZone } = useToday()
const { data, isPending } = useQuery({ queryKey: ['trash'], queryFn: () => api<{ items: TrashItem[]; retention_days: number }>('/trash') })

const refresh = () => Promise.all(['trash', 'tasks', 'notes', 'projects'].map((k) => client.invalidateQueries({ queryKey: [k] })))
const onError = (e: unknown) => toast.error(errorMessage(e))
const restore = useMutation({ mutationFn: (i: TrashItem) => api(`/trash/${i.type}/${i.id}/restore`, { method: 'POST' }), onSuccess: (_r, i) => { toast(`Restored “${i.title}”`); refresh() }, onError })
const purge = useMutation({ mutationFn: (i: TrashItem) => api(`/trash/${i.type}/${i.id}`, { method: 'DELETE' }), onSuccess: refresh, onError })
const empty = useMutation({ mutationFn: () => api('/trash', { method: 'DELETE' }), onSuccess: () => { toast('Trash emptied'); refresh() }, onError })

const deletedOn = (iso: string) => relativeDay(todayIn(timeZone.value, new Date(iso)), today.value)
</script>

<template>
  <div class="mx-auto max-w-3xl px-6 pb-24 pt-8 md:px-10">
    <PageHeader title="Trash" :subtitle="data ? `Deleted tasks and notes are removed for good after ${data.retention_days} days.` : undefined">
      <template v-if="data?.items.length" #actions>
        <Button variant="outline" size="sm" :disabled="empty.isPending.value" @click="empty.mutate()"><Trash2 /> Empty trash</Button>
      </template>
    </PageHeader>
    <div v-if="isPending" class="space-y-2"><div v-for="i in 3" :key="i" class="h-10 animate-pulse rounded-md bg-muted/60" /></div>
    <EmptyState v-else-if="!data?.items.length" :icon="Trash2" title="Trash is empty" body="Deleted tasks and notes land here first, so you can change your mind." />
    <ul v-else class="divide-y rounded-xl border bg-card">
      <li v-for="item in data.items" :key="`${item.type}-${item.id}`" class="flex items-center gap-3 px-4 py-2.5">
        <component :is="item.type === 'task' ? CheckSquare : FileText" class="size-4 shrink-0 text-muted-foreground" />
        <span class="min-w-0 flex-1 truncate">{{ item.title }}</span>
        <span class="hidden text-xs text-muted-foreground sm:inline">Deleted {{ deletedOn(item.discarded_at).toLowerCase() }}</span>
        <Button variant="ghost" size="sm" @click="restore.mutate(item)"><RotateCcw /> Restore</Button>
        <Button variant="ghost" size="icon-sm" :aria-label="`Delete ${item.title} forever`" title="Delete forever" @click="purge.mutate(item)"><Trash2 /></Button>
      </li>
    </ul>
  </div>
</template>
