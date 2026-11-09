<script setup lang="ts">
import { reactive, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Ban } from '@lucide/vue'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import type { Project } from '@/api/tasks'
import { useProjectMutations } from '@/composables/useTasks'
import { colorClasses, colorNames } from '@/lib/colors'
import { projectIcons } from '@/lib/projectIcons'

/** Create a project, or edit one when `project` is given. */
const props = defineProps<{ project?: Project | null }>()
const open = defineModel<boolean>('open', { required: true })

const router = useRouter()
const { create, update } = useProjectMutations()
const form = reactive({ name: '', color: 'violet', icon: null as string | null })

watch(open, (isOpen) => {
  if (!isOpen) return
  form.name = props.project?.name ?? ''
  form.color = props.project?.color ?? 'violet'
  form.icon = props.project?.icon ?? null
})

async function submit() {
  const input = { name: form.name.trim(), color: form.color, icon: form.icon }
  if (!input.name) return
  if (props.project) {
    await update.mutateAsync({ id: props.project.id, input })
  } else {
    const project = await create.mutateAsync(input)
    router.push({ name: 'project', params: { id: project.id } })
  }
  open.value = false
}
</script>

<template>
  <Dialog v-model:open="open">
    <DialogContent class="sm:max-w-md">
      <DialogHeader>
        <DialogTitle>{{ project ? 'Edit project' : 'New project' }}</DialogTitle>
        <DialogDescription>Projects group related tasks. Use sections inside a project for stages or weeks.</DialogDescription>
      </DialogHeader>
      <form id="project-form" class="space-y-5" @submit.prevent="submit">
        <div class="space-y-2">
          <Label for="project-name">Name</Label>
          <Input id="project-name" v-model="form.name" maxlength="100" placeholder="e.g. Learn Rails" autofocus />
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
              class="size-6 rounded-full ring-offset-2 ring-offset-background transition"
              :class="[colorClasses(name).dot, form.color === name ? 'ring-2 ring-ring' : 'hover:scale-110']"
              @click="form.color = name"
            />
          </div>
        </div>
        <div class="space-y-2">
          <Label>Icon</Label>
          <div class="flex flex-wrap gap-1" role="radiogroup" aria-label="Icon">
            <button
              type="button"
              role="radio"
              :aria-checked="form.icon === null"
              aria-label="No icon"
              class="flex size-8 items-center justify-center rounded-md border text-muted-foreground"
              :class="form.icon === null ? 'border-ring bg-accent' : 'border-transparent hover:bg-accent'"
              @click="form.icon = null"
            >
              <Ban class="size-4" />
            </button>
            <button
              v-for="(icon, name) in projectIcons"
              :key="name"
              type="button"
              role="radio"
              :aria-checked="form.icon === name"
              :aria-label="String(name)"
              class="flex size-8 items-center justify-center rounded-md border"
              :class="[form.icon === name ? 'border-ring bg-accent' : 'border-transparent hover:bg-accent', colorClasses(form.color).text]"
              @click="form.icon = String(name)"
            >
              <component :is="icon" class="size-4" />
            </button>
          </div>
        </div>
      </form>
      <DialogFooter>
        <Button variant="ghost" @click="open = false">Cancel</Button>
        <Button type="submit" form="project-form" :disabled="!form.name.trim() || create.isPending.value || update.isPending.value">
          {{ project ? 'Save' : 'Create project' }}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
