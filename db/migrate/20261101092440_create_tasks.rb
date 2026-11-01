class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_enum :status_enum, %w[todo in_progress done cancelled]
    create_enum :priority_enum, %w[none low medium high urgent]

    create_table :tasks do |t|
      t.references :project, null: true, foreign_key: { on_delete: :nullify }
      t.references :section, null: true, foreign_key: { on_delete: :nullify }
      t.references :parent,  null: true, foreign_key: { to_table: :tasks, on_delete: :cascade }
      t.column :title, "text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 500)"
      t.jsonb :description, null: true
      t.enum :status, null: false, enum_type: :status_enum, default: "todo"
      t.enum :priority, null: false, enum_type: :priority_enum, default: 'none'
      t.date :due_date, null: true
      t.integer :estimate_minutes, null: true
      t.datetime :completed_at, null: true
      t.decimal :positions, null: false
      t.virtual :search_vector,
        type: :tsvector,
        as: "to_tsvector('simple', coalesce(title, ''))",
        stored: true
      t.datetime :discarded_at, null: true

      t.timestamps
    end
  end
end
