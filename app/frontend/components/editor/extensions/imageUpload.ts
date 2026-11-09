import Image from '@tiptap/extension-image'
import { Plugin, PluginKey } from '@tiptap/pm/state'
import type { EditorView } from '@tiptap/pm/view'
import type { Editor } from '@tiptap/core'
import { reactive } from 'vue'
import { toast } from 'vue-sonner'
import { uploadImage } from '@/api/notes'
import { errorMessage } from '@/composables/useTasks'

/** Upload progress by placeholder id, shown over the image while it uploads. */
export const uploadProgress = reactive(new Map<string, number>())

const ACCEPTED = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/avif', 'image/heic', 'image/heif']

function findImage(editor: Editor, uploadId: string) {
  let found: number | null = null
  editor.state.doc.descendants((node, pos) => {
    if (found === null && node.type.name === 'image' && node.attrs.uploadId === uploadId) found = pos
    return found === null
  })
  return found
}

/**
 * Inserts each file as an image straight away (a local preview), uploads it, then swaps in the
 * server URL. Used for paste, drop and the slash menu's file picker (MED-1, MED-5).
 */
export function insertImages(editor: Editor, files: File[], at?: number) {
  for (const file of files) {
    if (!ACCEPTED.includes(file.type) && !/\.(heic|heif|avif)$/i.test(file.name)) {
      toast.error(`${file.name} isn't a supported image`)
      continue
    }
    const uploadId = crypto.randomUUID()
    uploadProgress.set(uploadId, 0)
    const preview = URL.createObjectURL(file)
    const node = editor.schema.nodes.image!.create({ src: preview, alt: file.name, uploadId })
    const pos = at ?? editor.state.selection.to
    editor.view.dispatch(editor.state.tr.insert(pos, node))

    uploadImage(file, (fraction) => uploadProgress.set(uploadId, fraction))
      .then((upload) => {
        const imagePos = findImage(editor, uploadId)
        if (imagePos === null) return
        editor.view.dispatch(editor.state.tr.setNodeMarkup(imagePos, undefined, {
          src: upload.url, alt: file.name, signedId: upload.signed_id, width: upload.width, height: upload.height, uploadId: null,
        }))
      })
      .catch((error) => {
        toast.error(errorMessage(error))
        const imagePos = findImage(editor, uploadId)
        if (imagePos !== null) editor.view.dispatch(editor.state.tr.delete(imagePos, imagePos + 1))
      })
      .finally(() => {
        uploadProgress.delete(uploadId)
        URL.revokeObjectURL(preview)
      })
  }
}

export function hasPendingUploads(editor: Editor) {
  let pending = false
  editor.state.doc.descendants((node) => {
    if (node.type.name === 'image' && node.attrs.uploadId) pending = true
    return !pending
  })
  return pending
}

function imageFiles(list: FileList | null | undefined) {
  return Array.from(list ?? []).filter((f) => f.type.startsWith('image/') || /\.(heic|heif|avif)$/i.test(f.name))
}

export const UploadableImage = Image.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      signedId: { default: null, renderHTML: (a) => (a.signedId ? { 'data-signed-id': a.signedId } : {}) },
      width: { default: null },
      height: { default: null },
      uploadId: { default: null, rendered: false },
    }
  },

  addProseMirrorPlugins() {
    const editor = this.editor
    return [
      new Plugin({
        key: new PluginKey('imageUpload'),
        props: {
          handlePaste(_view, event) {
            const files = imageFiles(event.clipboardData?.files)
            if (!files.length) return false
            insertImages(editor, files)
            return true
          },
          handleDrop(view: EditorView, event) {
            const files = imageFiles(event.dataTransfer?.files)
            if (!files.length) return false
            event.preventDefault()
            const pos = view.posAtCoords({ left: event.clientX, top: event.clientY })?.pos
            insertImages(editor, files, pos)
            return true
          },
        },
      }),
    ]
  },
})
