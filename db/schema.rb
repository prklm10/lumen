# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_01_094359) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "event_enum", ["created", "status_changed", "rescheduled", "discarded"]
  create_enum "priority_enum", ["none", "low", "medium", "high", "urgent"]
  create_enum "status_enum", ["todo", "in_progress", "done", "cancelled"]

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", default: "violet", null: false
    t.string "icon"
    t.decimal "position", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sections", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "name", limit: 100, null: false
    t.decimal "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_sections_on_project_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "taggings", force: :cascade do |t|
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "task_events", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.enum "event", null: false, enum_type: "event_enum"
    t.text "from_status"
    t.text "to_status"
    t.date "from_due_date"
    t.date "to_due_date"
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["occurred_at"], name: "index_task_events_on_occurred_at"
    t.index ["task_id", "occurred_at"], name: "index_task_events_on_task_id_and_occurred_at"
    t.index ["task_id"], name: "index_task_events_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "project_id"
    t.bigint "section_id"
    t.bigint "parent_id"
    t.text "title", null: false
    t.jsonb "description"
    t.enum "status", default: "todo", null: false, enum_type: "status_enum"
    t.enum "priority", default: "none", null: false, enum_type: "priority_enum"
    t.date "due_date"
    t.integer "estimate_minutes"
    t.datetime "completed_at"
    t.decimal "positions", null: false
    t.virtual "search_vector", type: :tsvector, as: "to_tsvector('simple'::regconfig, COALESCE(title, ''::text))", stored: true
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_tasks_on_parent_id"
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["section_id"], name: "index_tasks_on_section_id"
    t.check_constraint "char_length(btrim(title)) >= 1 AND char_length(btrim(title)) <= 500", name: "tasks_title_check"
  end

  create_table "users", force: :cascade do |t|
    t.citext "email_address", null: false
    t.string "password_digest", null: false
    t.string "time_zone", default: "UTC", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "sections", "projects", on_delete: :cascade
  add_foreign_key "sessions", "users", on_delete: :cascade
  add_foreign_key "taggings", "tags", on_delete: :cascade
  add_foreign_key "task_events", "tasks", on_delete: :cascade
  add_foreign_key "tasks", "projects", on_delete: :nullify
  add_foreign_key "tasks", "sections", on_delete: :nullify
  add_foreign_key "tasks", "tasks", column: "parent_id", on_delete: :cascade
end
