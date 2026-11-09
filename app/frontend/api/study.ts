import { api } from './client'

export interface Topic { id: number; name: string; color: string; description: string | null }
export type ResourceKind = 'book' | 'course' | 'video' | 'article' | 'podcast' | 'other'
export type ResourceStatus = 'to_learn' | 'in_progress' | 'done'
export interface LearningResource {
  id: number; topic_id: number | null; title: string; url: string | null; kind: ResourceKind; status: ResourceStatus
  progress: number; rating: number | null; started_on: string | null; finished_on: string | null; minutes_studied: number
}
export interface StudySession { id: number; topic_id: number | null; resource_id: number | null; studied_on: string; duration_minutes: number; notes: string | null }
export interface Flashcard {
  id: number; note_id: number | null; topic_id: number | null; front: string; back: string; from_note_syntax: boolean
  interval_days: number; repetitions: number; due_on: string; ease: number; preview?: Record<string, number>
}

const body = <T>(key: string, value: T) => ({ [key]: value })

export const studyApi = {
  topics: () => api<{ topics: Topic[] }>('/topics').then((r) => r.topics),
  createTopic: (topic: Partial<Topic>) => api<Topic>('/topics', { method: 'POST', body: body('topic', topic) }),
  resources: () => api<{ resources: LearningResource[] }>('/resources').then((r) => r.resources),
  saveResource: (resource: Partial<LearningResource>) =>
    resource.id
      ? api<LearningResource>(`/resources/${resource.id}`, { method: 'PATCH', body: body('resource', resource) })
      : api<LearningResource>('/resources', { method: 'POST', body: body('resource', resource) }),
  destroyResource: (id: number) => api<void>(`/resources/${id}`, { method: 'DELETE' }),
  sessions: (days = 30) =>
    api<{ sessions: StudySession[]; by_topic: { topic_id: number | null; minutes: number }[]; total_minutes: number }>(`/study_sessions?days=${days}`),
  logSession: (session: Partial<StudySession>) => api<StudySession>('/study_sessions', { method: 'POST', body: body('study_session', session) }),
  destroySession: (id: number) => api<void>(`/study_sessions/${id}`, { method: 'DELETE' }),
  cards: (params: { note_id?: number }) => api<{ flashcards: Flashcard[] }>(`/flashcards?${new URLSearchParams(params as Record<string, string>)}`).then((r) => r.flashcards),
  due: () => api<{ flashcards: Flashcard[]; due_count: number; total: number; upcoming: { date: string; count: number }[] }>('/flashcards/due'),
  createCard: (card: Partial<Flashcard>) => api<Flashcard>('/flashcards', { method: 'POST', body: body('flashcard', card) }),
  destroyCard: (id: number) => api<void>(`/flashcards/${id}`, { method: 'DELETE' }),
  review: (id: number, grade: number) => api<Flashcard>(`/flashcards/${id}/review`, { method: 'POST', body: { grade } }),
}
