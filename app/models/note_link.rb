class NoteLink < ApplicationRecord
  belongs_to :source_note, class_name: "Note"
  belongs_to :target_note, class_name: "Note", optional: true
end
