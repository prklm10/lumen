# column	type	rules
# id	bigint PK
# task_id	FK → tasks	NOT NULL, ON DELETE CASCADE
# event	text	NOT NULL, CHECK IN (created, status_changed, rescheduled, discarded)
# from_status	text	nullable
# to_status	text	nullable
# from_due_date	date	nullable
# to_due_date	date	nullable
# occurred_at	timestamptz	NOT NULL default now()
# Add an index on (task_id, occurred_at) and one on (occurred_at). There is no updated_at: rows are never updated. The model should be read-only after create (def readonly? = persisted?).
class CreateTaskEvents < ActiveRecord::Migration[8.1]
  def change
    create_enum :event_enum, %w[created status_changed rescheduled discarded]

    create_table :task_events do |t|
      t.references :task, null: false, foreign_key: { on_delete: :cascade }
      t.enum :event, null: false, enum_type: :event_enum
      t.text :from_status, null: true
      t.text :to_status, null: true
      t.date :from_due_date, null: true
      t.date :to_due_date, null: true
      t.datetime :occurred_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :task_events, [ :task_id, :occurred_at ]
    add_index :task_events, :occurred_at
  end
end
