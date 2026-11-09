import { api, ApiError } from './client'
import type { RichDoc, Tag } from './tasks'

export interface NoteSummary {
  id: number
  title: string
  icon: string | null
  folder_id: number | null
  pinned: boolean
  position: number
  created_at: string
  updated_at: string
}

export interface Note extends NoteSummary {
  content: RichDoc
  lock_version: number
  tags: Tag[]
  backlinks: { id: number; title: string; icon: string | null }[]
}

export interface NoteInput {
  title?: string
  icon?: string | null
  folder_id?: number | null
  pinned?: boolean
  position?: number
  content?: RichDoc
  lock_version?: number
}

export interface Folder {
  id: number
  name: string
  parent_id: number | null
  position: number
}

export interface SearchResults {
  notes: { id: number; title: string; icon: string | null; folder_id: number | null; snippet: string; updated_at: string }[]
  tasks: { id: number; title: string; status: string; project_id: number | null; due_date: string | null }[]
}

export interface Upload {
  signed_id: string
  filename: string
  content_type: string
  byte_size: number
  width: number | null
  height: number | null
  url: string
  large_url: string
  thumb_url: string
}

export const notesApi = {
  list: () => api<{ notes: NoteSummary[] }>('/notes').then((r) => r.notes),
  get: (id: number) => api<Note>(`/notes/${id}`),
  create: (note: NoteInput) => api<Note>('/notes', { method: 'POST', body: { note } }),
  update: (id: number, note: NoteInput) => api<Note>(`/notes/${id}`, { method: 'PATCH', body: { note } }),
  destroy: (id: number) => api<void>(`/notes/${id}`, { method: 'DELETE' }),
}

export const foldersApi = {
  list: () => api<{ folders: Folder[] }>('/folders').then((r) => r.folders),
  create: (folder: Partial<Folder>) => api<Folder>('/folders', { method: 'POST', body: { folder } }),
  update: (id: number, folder: Partial<Folder>) => api<Folder>(`/folders/${id}`, { method: 'PATCH', body: { folder } }),
  destroy: (id: number) => api<void>(`/folders/${id}`, { method: 'DELETE' }),
}

export const searchApi = {
  search: (q: string) => api<SearchResults>(`/search?${new URLSearchParams({ q })}`),
}

/** Multipart upload with progress (fetch can't report upload progress; XHR can). */
export function uploadImage(file: File, onProgress?: (fraction: number) => void): Promise<Upload> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    const form = new FormData()
    form.append('file', file)
    xhr.open('POST', '/api/v1/uploads')
    xhr.setRequestHeader('Accept', 'application/json')
    xhr.setRequestHeader('X-CSRF-Token', document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? '')
    xhr.upload.onprogress = (e) => e.lengthComputable && onProgress?.(e.loaded / e.total)
    xhr.onload = () => {
      const data = (() => { try { return JSON.parse(xhr.responseText) } catch { return {} } })()
      if (xhr.status >= 200 && xhr.status < 300) resolve(data as Upload)
      else reject(new ApiError(xhr.status, data?.error?.code ?? 'upload_failed', data?.error?.message ?? 'Upload failed', data?.error?.details))
    }
    xhr.onerror = () => reject(new ApiError(0, 'network', 'Upload failed: network error'))
    xhr.send(form)
  })
}
