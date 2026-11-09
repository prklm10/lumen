import { computed, toValue, type MaybeRefOrGetter } from 'vue'
import { keepPreviousData, useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/vue-query'
import { toast } from 'vue-sonner'
import { ApiError } from '@/api/client'
import {
  metaApi, projectsApi, tagsApi, tasksApi,
  type ProjectInput, type Task, type TaskInput, type TaskListParams,
} from '@/api/tasks'

/** Query keys. Everything task-related lives under ['tasks'] so one invalidation refreshes it. */
export const taskKeys = {
  all: ['tasks'] as const,
  list: (params: TaskListParams) => ['tasks', 'list', params] as const,
  detail: (id: number) => ['tasks', 'detail', id] as const,
  counts: ['tasks', 'counts'] as const,
  projects: ['projects'] as const,
  tags: ['tags'] as const,
}

export function useTaskList(params: MaybeRefOrGetter<TaskListParams>, enabled: MaybeRefOrGetter<boolean> = true) {
  return useQuery({
    queryKey: computed(() => taskKeys.list(toValue(params))),
    queryFn: () => tasksApi.list(toValue(params)).then((r) => r.tasks),
    enabled: () => toValue(enabled),
    placeholderData: keepPreviousData,
  })
}

export function useCompletedTasks() {
  return useInfiniteQuery({
    queryKey: taskKeys.list({ view: 'completed' }),
    queryFn: ({ pageParam }) => tasksApi.list({ view: 'completed', cursor: pageParam }),
    initialPageParam: null as string | null,
    getNextPageParam: (last) => last.next_cursor,
  })
}

export function useTask(id: MaybeRefOrGetter<number | null>) {
  return useQuery({
    queryKey: computed(() => taskKeys.detail(toValue(id) ?? 0)),
    queryFn: () => tasksApi.get(toValue(id)!),
    enabled: () => toValue(id) !== null,
  })
}

export function useTaskCounts() {
  return useQuery({ queryKey: taskKeys.counts, queryFn: tasksApi.counts })
}

export function useProjects() {
  return useQuery({ queryKey: taskKeys.projects, queryFn: () => projectsApi.list().then((r) => r.projects) })
}

export function useTags() {
  return useQuery({ queryKey: taskKeys.tags, queryFn: () => tagsApi.list().then((r) => r.tags) })
}

export function useMeta() {
  return useQuery({ queryKey: ['meta'], queryFn: metaApi.get, staleTime: Infinity })
}

export function errorMessage(error: unknown) {
  return error instanceof ApiError ? error.message : 'Something went wrong. Try again.'
}

/** Patches a task in every cached list/detail so the UI responds before the server does. */
function patchCachedTask(client: ReturnType<typeof useQueryClient>, id: number, patch: Partial<Task>) {
  const apply = (task: Task): Task => {
    if (task.id === id) return { ...task, ...patch }
    if (task.subtasks?.some((s) => s.id === id)) return { ...task, subtasks: task.subtasks.map(apply) }
    return task
  }
  client.setQueriesData<Task[]>({ queryKey: ['tasks', 'list'] }, (old) => (Array.isArray(old) ? old.map(apply) : old))
  client.setQueriesData<Task>({ queryKey: ['tasks', 'detail'] }, (old) => (old && 'id' in old ? apply(old) : old))
}

export function useTaskMutations() {
  const client = useQueryClient()
  const refresh = () => Promise.all([
    client.invalidateQueries({ queryKey: taskKeys.all }),
    client.invalidateQueries({ queryKey: taskKeys.projects }),
    client.invalidateQueries({ queryKey: taskKeys.tags }),
  ])
  const onError = (error: unknown) => {
    toast.error(errorMessage(error))
    refresh()
  }

  const create = useMutation({ mutationFn: (input: TaskInput) => tasksApi.create(input), onSuccess: refresh, onError })

  const update = useMutation({
    mutationFn: ({ id, input }: { id: number; input: TaskInput }) => tasksApi.update(id, input),
    onMutate: ({ id, input }) => {
      const { tag_names: _tags, ...rest } = input
      patchCachedTask(client, id, rest as Partial<Task>)
    },
    onSuccess: refresh,
    onError,
  })

  const setDone = useMutation({
    mutationFn: ({ task, done }: { task: Task; done: boolean }) => (done ? tasksApi.complete(task.id) : tasksApi.reopen(task.id)),
    onMutate: ({ task, done }) => patchCachedTask(client, task.id, { status: done ? 'done' : 'todo' }),
    onSuccess: (_task, { task, done }) => {
      if (done && !task.parent_id) {
        toast.success('Task completed', {
          description: task.title,
          action: { label: 'Undo', onClick: () => setDone.mutate({ task, done: false }) },
        })
      }
      // Let the check animation play before the row leaves open-only lists.
      setTimeout(refresh, done ? 450 : 0)
    },
    onError,
  })

  const destroy = useMutation({
    mutationFn: (task: Task) => tasksApi.destroy(task.id),
    onSuccess: (_r, task) => {
      toast('Task deleted', { description: task.title })
      refresh()
    },
    onError,
  })

  const reorder = useMutation({
    mutationFn: tasksApi.reorder,
    onSuccess: refresh,
    onError,
  })

  return { create, update, setDone, destroy, reorder, refresh }
}

export function useProjectMutations() {
  const client = useQueryClient()
  const refresh = () => Promise.all([
    client.invalidateQueries({ queryKey: taskKeys.projects }),
    client.invalidateQueries({ queryKey: taskKeys.all }),
  ])
  const onError = (error: unknown) => toast.error(errorMessage(error))

  return {
    create: useMutation({ mutationFn: (input: ProjectInput) => projectsApi.create(input), onSuccess: refresh, onError }),
    update: useMutation({
      mutationFn: ({ id, input }: { id: number; input: ProjectInput }) => projectsApi.update(id, input),
      onSuccess: refresh,
      onError,
    }),
    destroy: useMutation({ mutationFn: (id: number) => projectsApi.destroy(id), onSuccess: refresh }),
    createSection: useMutation({
      mutationFn: ({ projectId, name }: { projectId: number; name: string }) => projectsApi.createSection(projectId, name),
      onSuccess: refresh,
      onError,
    }),
    updateSection: useMutation({
      mutationFn: ({ projectId, id, name }: { projectId: number; id: number; name: string }) =>
        projectsApi.updateSection(projectId, id, { name }),
      onSuccess: refresh,
      onError,
    }),
    destroySection: useMutation({
      mutationFn: ({ projectId, id }: { projectId: number; id: number }) => projectsApi.destroySection(projectId, id),
      onSuccess: refresh,
      onError,
    }),
  }
}
