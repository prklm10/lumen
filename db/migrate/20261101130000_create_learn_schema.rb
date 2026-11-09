# Phase 2 — Learn (PRD §4.5, §8.5): folders, notes and the wiki-link graph between them.
class CreateLearnSchema < ActiveRecord::Migration[8.1]
  def change
    # Trigram similarity: fuzzy title matching ("postgress" still finds "Postgres").
    enable_extension "pg_trgm"

    create_table :folders do |t|
      # A folder tree of any depth. Deleting a folder is handled in the app (its contents move
      # up a level), so the FK only guards against dangling parents.
      t.references :parent, foreign_key: { to_table: :folders, on_delete: :restrict }
      t.string :name, null: false
      t.decimal :position, null: false
      t.timestamps
    end
    add_check_constraint :folders, "char_length(name) BETWEEN 1 AND 100", name: "folders_name_length"
    add_check_constraint :folders, "parent_id IS NULL OR parent_id <> id", name: "folders_not_own_parent"

    create_table :notes do |t|
      t.references :folder, foreign_key: { on_delete: :nullify }
      t.text :title, null: false
      t.string :icon
      t.jsonb :content, null: false, default: { type: "doc", content: [] } # TipTap JSON: the source of truth
      t.text :content_text, null: false, default: ""                       # plain text extracted on save
      t.virtual :search_vector, type: :tsvector, stored: true, as: <<~SQL.squish
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(content_text, '')), 'B')
      SQL
      t.boolean :pinned, null: false, default: false
      t.decimal :position, null: false
      t.integer :lock_version, null: false, default: 0 # optimistic locking: two tabs can't overwrite each other
      t.datetime :discarded_at
      t.timestamps
    end
    add_check_constraint :notes, "char_length(title) BETWEEN 1 AND 200", name: "notes_title_length"
    add_index :notes, :search_vector, using: :gin
    add_index :notes, :title, using: :gin, opclass: :gin_trgm_ops, name: "index_notes_on_title_trgm"
    add_index :notes, "lower(title)", where: "discarded_at IS NULL", name: "index_notes_kept_on_lower_title"
    add_index :notes, :updated_at, where: "discarded_at IS NULL", name: "index_notes_kept_by_recent"

    # [[Wiki links]]. target_title is kept so a link to a note that doesn't exist yet resolves
    # as soon as a note with that title is created.
    create_table :note_links do |t|
      t.references :source_note, null: false, foreign_key: { to_table: :notes, on_delete: :cascade }, index: false
      t.references :target_note, foreign_key: { to_table: :notes, on_delete: :nullify }
      t.column :target_title, :citext, null: false
      t.datetime :created_at, null: false
    end
    add_index :note_links, %i[source_note_id target_title], unique: true
    add_index :note_links, :target_title
  end
end
