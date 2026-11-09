# Completes the Phase 1 schema (docs/phase-1-tasks.md §3) on top of the create_* migrations:
# polymorphic taggings, case-insensitive unique tags, due times, and the constraints and
# indexes that keep the data honest at the database level.
class FinishTasksSchema < ActiveRecord::Migration[8.1]
  # Kept literal: migrations must not depend on app code that can change later (Palette::COLORS).
  COLORS = %w[gray red orange amber yellow lime green teal cyan blue indigo violet purple pink].freeze
  COLOR_LIST = COLORS.map { |c| "'#{c}'" }.join(", ")

  def change
    # tags — case-insensitive, unique names
    reversible do |dir|
      dir.up   { change_column :tags, :name, :citext, null: false }
      dir.down { change_column :tags, :name, :string, null: false }
    end
    add_index :tags, :name, unique: true
    add_check_constraint :tags, "char_length(name) BETWEEN 1 AND 50", name: "tags_name_length"
    add_check_constraint :tags, "color IS NULL OR color IN (#{COLOR_LIST})", name: "tags_color_in_palette"

    # taggings — polymorphic so notes and resources can reuse tags later
    change_table :taggings, bulk: true do |t|
      t.string :taggable_type, null: false
      t.bigint :taggable_id, null: false
      t.remove :updated_at, type: :datetime, null: false
    end
    add_index :taggings, %i[tag_id taggable_type taggable_id], unique: true
    add_index :taggings, %i[taggable_type taggable_id]
    remove_index :taggings, :tag_id # covered by the unique index's leading column

    # projects / sections
    add_check_constraint :projects, "char_length(name) BETWEEN 1 AND 100", name: "projects_name_length"
    add_check_constraint :projects, "color IN (#{COLOR_LIST})", name: "projects_color_in_palette"
    add_check_constraint :sections, "char_length(name) >= 1", name: "sections_name_length"

    # tasks
    rename_column :tasks, :positions, :position
    add_column :tasks, :due_at, :datetime

    add_check_constraint :tasks, "(status = 'done') = (completed_at IS NOT NULL)", name: "tasks_done_iff_completed_at"
    add_check_constraint :tasks, "due_at IS NULL OR due_date IS NOT NULL", name: "tasks_due_at_needs_due_date"
    add_check_constraint :tasks, "parent_id IS NULL OR parent_id <> id", name: "tasks_not_own_parent"
    add_check_constraint :tasks, "estimate_minutes IS NULL OR estimate_minutes BETWEEN 1 AND 10080",
      name: "tasks_estimate_range"

    # Today / Upcoming / counts only ever look at open, kept tasks — a partial index stays small.
    add_index :tasks, :due_date, where: "discarded_at IS NULL AND status IN ('todo', 'in_progress')",
      name: "index_tasks_open_by_due_date"
    add_index :tasks, %i[project_id section_id position], where: "discarded_at IS NULL",
      name: "index_tasks_kept_by_container"
    add_index :tasks, %i[completed_at id], order: { completed_at: :desc, id: :desc },
      where: "status = 'done' AND discarded_at IS NULL", name: "index_tasks_completed_log"
    add_index :tasks, :search_vector, using: :gin
    remove_index :tasks, :project_id # covered by index_tasks_kept_by_container
  end
end
