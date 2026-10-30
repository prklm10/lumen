import type { Component } from 'vue'
import { BarChart3, BookOpen, CheckSquare, LineChart, NotebookPen, Settings, Sun } from '@lucide/vue'

export interface NavItem {
  name: string
  label: string
  path: string
  icon: Component
  /** Single-key shortcut used after pressing `g` (e.g. `g t` → Tasks). */
  shortcut?: string
  /** Roadmap phase that builds this module (PRD §12). */
  phase?: number
  description?: string
}

export const primaryNav: NavItem[] = [
  { name: 'today', label: 'Today', path: '/', icon: Sun, shortcut: 'h' },
  {
    name: 'journal', label: 'Journal', path: '/journal', icon: NotebookPen, shortcut: 'j', phase: 4,
    description: 'An end-to-end encrypted journal. Only you, with your passphrase, can read it.',
  },
  {
    name: 'tasks', label: 'Tasks', path: '/tasks', icon: CheckSquare, shortcut: 't', phase: 1,
    description: 'Projects, due dates, priorities, and a Today view that keeps you honest.',
  },
  {
    name: 'tracker', label: 'Tracker', path: '/tracker', icon: LineChart, shortcut: 'r', phase: 3,
    description: 'Habits and daily metrics with streaks and yearly heatmaps.',
  },
  {
    name: 'learn', label: 'Learn', path: '/learn', icon: BookOpen, shortcut: 'l', phase: 2,
    description: 'Linked notes, topics, resources, and spaced-repetition flashcards.',
  },
  {
    name: 'analytics', label: 'Analytics', path: '/analytics', icon: BarChart3, shortcut: 'a', phase: 5,
    description: 'Task completion, habit consistency, and learning time — all in one place.',
  },
]

export const settingsNav: NavItem = { name: 'settings', label: 'Settings', path: '/settings', icon: Settings, shortcut: 's' }
