import type { Priority } from '@/api/tasks'

/**
 * Palette names from the backend (Palette::COLORS) → Tailwind classes. Written out in full
 * so Tailwind's scanner sees every class (it can't see `bg-${name}-500`).
 */
const palette: Record<string, { dot: string; text: string; soft: string }> = {
  gray: { dot: 'bg-zinc-400', text: 'text-zinc-500', soft: 'bg-zinc-500/10 text-zinc-600 dark:text-zinc-300' },
  red: { dot: 'bg-red-500', text: 'text-red-500', soft: 'bg-red-500/10 text-red-700 dark:text-red-300' },
  orange: { dot: 'bg-orange-500', text: 'text-orange-500', soft: 'bg-orange-500/10 text-orange-700 dark:text-orange-300' },
  amber: { dot: 'bg-amber-500', text: 'text-amber-500', soft: 'bg-amber-500/10 text-amber-700 dark:text-amber-300' },
  yellow: { dot: 'bg-yellow-400', text: 'text-yellow-500', soft: 'bg-yellow-400/15 text-yellow-700 dark:text-yellow-300' },
  lime: { dot: 'bg-lime-500', text: 'text-lime-600', soft: 'bg-lime-500/10 text-lime-700 dark:text-lime-300' },
  green: { dot: 'bg-green-500', text: 'text-green-600', soft: 'bg-green-500/10 text-green-700 dark:text-green-300' },
  teal: { dot: 'bg-teal-500', text: 'text-teal-600', soft: 'bg-teal-500/10 text-teal-700 dark:text-teal-300' },
  cyan: { dot: 'bg-cyan-500', text: 'text-cyan-600', soft: 'bg-cyan-500/10 text-cyan-700 dark:text-cyan-300' },
  blue: { dot: 'bg-blue-500', text: 'text-blue-500', soft: 'bg-blue-500/10 text-blue-700 dark:text-blue-300' },
  indigo: { dot: 'bg-indigo-500', text: 'text-indigo-500', soft: 'bg-indigo-500/10 text-indigo-700 dark:text-indigo-300' },
  violet: { dot: 'bg-violet-500', text: 'text-violet-500', soft: 'bg-violet-500/10 text-violet-700 dark:text-violet-300' },
  purple: { dot: 'bg-purple-500', text: 'text-purple-500', soft: 'bg-purple-500/10 text-purple-700 dark:text-purple-300' },
  pink: { dot: 'bg-pink-500', text: 'text-pink-500', soft: 'bg-pink-500/10 text-pink-700 dark:text-pink-300' },
}

export const colorNames = Object.keys(palette)

export function colorClasses(name: string | null | undefined) {
  return palette[name ?? 'gray'] ?? palette.gray!
}

/** Checkbox ring + label per priority, Todoist-style: the more urgent, the louder. */
export const priorityStyles: Record<Priority, { ring: string; fill: string; text: string; label: string }> = {
  urgent: { ring: 'border-red-500', fill: 'bg-red-500/10', text: 'text-red-500', label: 'Urgent' },
  high: { ring: 'border-orange-500', fill: 'bg-orange-500/10', text: 'text-orange-500', label: 'High' },
  medium: { ring: 'border-blue-500', fill: 'bg-blue-500/10', text: 'text-blue-500', label: 'Medium' },
  low: { ring: 'border-zinc-400', fill: 'bg-zinc-400/10', text: 'text-zinc-500', label: 'Low' },
  none: { ring: 'border-muted-foreground/50', fill: '', text: 'text-muted-foreground', label: 'No priority' },
}

export const priorities: Priority[] = ['urgent', 'high', 'medium', 'low', 'none']
