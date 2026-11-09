# Sidebar/list shape: no content, so the full tree of notes stays small.
class NoteResource
  include Alba::Resource

  attributes :id, :title, :icon, :folder_id, :topic_id, :pinned, :created_at, :updated_at
  attribute(:position) { |note| note.position.to_f }
end
