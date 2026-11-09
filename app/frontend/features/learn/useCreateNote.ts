import { useRouter } from 'vue-router'
import { useNoteMutations } from '@/composables/useNotes'

/** Creates an empty note (optionally in a folder) and opens it with the title focused. */
export function useCreateNote() {
  const router = useRouter()
  const { create } = useNoteMutations()
  return async (folderId: number | null = null) => {
    const note = await create.mutateAsync({ title: 'Untitled', folder_id: folderId })
    router.push({ name: 'note', params: { id: note.id } })
  }
}
