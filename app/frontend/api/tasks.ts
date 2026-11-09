import { api } from './client'

export type TaskStatus = 'todo' | 'in_progress' | 'done' | 'cancelled'
export type Priority = 'none' | 'low' | 'medium' | 'high' | 'urgent'
export type TaskView = 'today' | 'upcoming' | 'inbox' | 'project' | 'completed' | 'search'

export interface Tag {
  id: number
  name: string
  color: string | null
}

/** A TipTap/ProseMirror document. */
export interface RichDoc {
  type: 'doc'
  content?: unknown[]
}

export interface Task {
  id: number
  title: string
  description: RichDoc | null
  status: TaskStatus
  priority: Priority
  due_date: string | null
  due_at: string | null
  overdue: boolean
  estimate_minutes: number | null
  completed_at: string | null
  position: number
  project_id: number | null
  section_id: number | null
  parent_id: number | null
  recurrence_rule: string | null
  subtask_count: number
  subtask_done_count: number
  tags: Tag[]
  subtasks?: Task[]
  created_at: string
  updated_at: string
}

export interface TaskInput {
  title?: string
  description?: RichDoc | null
  status?: TaskStatus
  priority?: Priority
  due_date?: string | null
  due_at?: string | null
  estimate_minutes?: number | null
  project_id?: number | null
  section_id?: number | null
  parent_id?: number | null
  recurrence_rule?: string | null
  tag_names?: string[]
}

export interface Section {
  id: number
  name: string
  position: number
  project_id: number
}

export interface Project {
  id: number
  name: string
  color: string
  icon: string | null
  position: number
  archived: boolean
  archived_at: string | null
  open_task_count: number
  sections: Section[]
}

export interface ProjectInput {
  name?: string
  color?: string
  icon?: string | null
  position?: number
  archived?: boolean
}

export interface TaskCounts {
  inbox: number
  today: number
  overdue: number
  upcoming: number
  projects: Record<string, number>
}

export interface TaskListParams {
  view: TaskView
  project_id?: number
  tag?: string
  include_done?: boolean
  q?: string
  cursor?: string | null
  limit?: number
}

export interface Meta {
  colors: string[]
  priorities: { value: Priority; label: string }[]
  statuses: TaskStatus[]
}

function query(params: object) {
  const search = new URLSearchParams()
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== false && value !== '') search.set(key, String(value))
  }
  return search.toString()
}

export const tasksApi = {
  list: (params: TaskListParams) => api<{ tasks: Task[]; next_cursor: string | null }>(`/tasks?${query(params)}`),
  get: (id: number) => api<Task>(`/tasks/${id}`),
  create: (task: TaskInput) => api<Task>('/tasks', { method: 'POST', body: { task } }),
  update: (id: number, task: TaskInput) => api<Task>(`/tasks/${id}`, { method: 'PATCH', body: { task } }),
  destroy: (id: number) => api<void>(`/tasks/${id}`, { method: 'DELETE' }),
  complete: (id: number) => api<Task>(`/tasks/${id}/complete`, { method: 'POST' }),
  reopen: (id: number) => api<Task>(`/tasks/${id}/reopen`, { method: 'POST' }),
  reorder: (moves: { id: number; position: number; section_id?: number | null }[]) =>
    api<{ tasks: Pick<Task, 'id' | 'position' | 'section_id'>[] }>('/tasks/reorder', { method: 'PATCH', body: { moves } }),
  counts: () => api<TaskCounts>('/tasks/counts'),
}

export const projectsApi = {
  list: (includeArchived = false) => api<{ projects: Project[] }>(`/projects?${query({ include_archived: includeArchived })}`),
  get: (id: number) => api<Project>(`/projects/${id}`),
  create: (project: ProjectInput) => api<Project>('/projects', { method: 'POST', body: { project } }),
  update: (id: number, project: ProjectInput) => api<Project>(`/projects/${id}`, { method: 'PATCH', body: { project } }),
  destroy: (id: number) => api<void>(`/projects/${id}`, { method: 'DELETE' }),
  createSection: (projectId: number, name: string) =>
    api<Section>(`/projects/${projectId}/sections`, { method: 'POST', body: { section: { name } } }),
  updateSection: (projectId: number, id: number, section: { name?: string; position?: number }) =>
    api<Section>(`/projects/${projectId}/sections/${id}`, { method: 'PATCH', body: { section } }),
  destroySection: (projectId: number, id: number) => api<void>(`/projects/${projectId}/sections/${id}`, { method: 'DELETE' }),
}

export const tagsApi = {
  list: () => api<{ tags: (Tag & { task_count: number })[] }>('/tags'),
}

export const metaApi = {
  get: () => api<Meta>('/meta'),
}
