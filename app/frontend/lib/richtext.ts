import type { RichDoc } from '@/api/tasks'

/**
 * Plain text ↔ TipTap/ProseMirror JSON. Task descriptions are stored as a doc so the rich
 * editor (Phase 2) can take over without a data migration; until then each line is a paragraph.
 */
export function textToDoc(text: string): RichDoc | null {
  const trimmed = text.replace(/\s+$/, '')
  if (!trimmed) return null
  return {
    type: 'doc',
    content: trimmed.split('\n').map((line) => (line ? { type: 'paragraph', content: [{ type: 'text', text: line }] } : { type: 'paragraph' })),
  }
}

interface Node {
  type?: string
  text?: string
  content?: Node[]
}

export function docToText(doc: RichDoc | null | undefined): string {
  if (!doc?.content) return ''
  const textOf = (node: Node): string => node.text ?? (node.content ?? []).map(textOf).join('')
  return (doc.content as Node[]).map(textOf).join('\n')
}
