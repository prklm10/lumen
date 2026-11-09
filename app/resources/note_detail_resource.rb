class NoteDetailResource
  include Alba::Resource

  attributes :id, :title, :icon, :folder_id, :topic_id, :pinned, :content, :lock_version, :created_at, :updated_at
  attribute(:position) { |note| note.position.to_f }
  many :tags, resource: TagResource
  attribute(:backlinks) { |note| note.backlinks.map { |n| { id: n.id, title: n.title, icon: n.icon } } }
end
