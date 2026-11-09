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

ActiveRecord::Schema[8.1].define(version: 2026_11_01_180000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "event_enum", ["created", "status_changed", "rescheduled", "discarded"]
  create_enum "priority_enum", ["none", "low", "medium", "high", "urgent"]
  create_enum "resource_kind", ["book", "course", "video", "article", "podcast", "other"]
  create_enum "resource_status", ["to_learn", "in_progress", "done"]
  create_enum "status_enum", ["todo", "in_progress", "done", "cancelled"]
  create_enum "tracker_kind", ["boolean", "count", "duration", "numeric", "scale"]

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "flashcard_reviews", force: :cascade do |t|
    t.bigint "flashcard_id", null: false
    t.integer "grade", limit: 2, null: false
    t.integer "interval_days", null: false
    t.datetime "reviewed_at", null: false
    t.index ["flashcard_id"], name: "index_flashcard_reviews_on_flashcard_id"
    t.index ["reviewed_at"], name: "index_flashcard_reviews_on_reviewed_at"
    t.check_constraint "grade >= 0 AND grade <= 5", name: "flashcard_reviews_grade_range"
  end

  create_table "flashcards", force: :cascade do |t|
    t.bigint "note_id"
    t.bigint "topic_id"
    t.text "front", null: false
    t.text "back", null: false
    t.boolean "from_note_syntax", default: false, null: false
    t.decimal "ease", precision: 4, scale: 2, default: "2.5", null: false
    t.integer "interval_days", default: 0, null: false
    t.integer "repetitions", default: 0, null: false
    t.date "due_on", default: -> { "CURRENT_DATE" }, null: false
    t.datetime "last_reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["due_on"], name: "index_flashcards_on_due_on"
    t.index ["note_id", "front"], name: "index_flashcards_from_note_syntax", unique: true, where: "from_note_syntax"
    t.index ["note_id"], name: "index_flashcards_on_note_id"
    t.index ["topic_id"], name: "index_flashcards_on_topic_id"
    t.check_constraint "char_length(front) >= 1 AND char_length(front) <= 1000 AND char_length(back) >= 1 AND char_length(back) <= 4000", name: "flashcards_text_length"
    t.check_constraint "ease >= 1.3", name: "flashcards_ease_floor"
  end

  create_table "folders", force: :cascade do |t|
    t.bigint "parent_id"
    t.string "name", null: false
    t.decimal "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_folders_on_parent_id"
    t.check_constraint "char_length(name::text) >= 1 AND char_length(name::text) <= 100", name: "folders_name_length"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "folders_not_own_parent"
  end

  create_table "journal_entries", id: :uuid, default: nil, force: :cascade do |t|
    t.date "entry_date", null: false
    t.binary "ciphertext", null: false
    t.binary "iv", null: false
    t.integer "version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_date"], name: "index_journal_entries_on_entry_date"
    t.check_constraint "octet_length(ciphertext) >= 16 AND octet_length(ciphertext) <= 4194304", name: "journal_entries_ciphertext_size"
    t.check_constraint "octet_length(iv) = 12", name: "journal_entries_iv_length"
    t.check_constraint "version >= 1", name: "journal_entries_version_positive"
  end

  create_table "journal_vaults", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "kdf_algo", default: "argon2id", null: false
    t.jsonb "kdf_params", null: false
    t.binary "salt", null: false
    t.binary "wrapped_dek", null: false
    t.binary "wrapped_dek_iv", null: false
    t.binary "recovery_salt", null: false
    t.binary "wrapped_dek_recovery", null: false
    t.binary "wrapped_dek_recovery_iv", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_journal_vaults_on_user_id", unique: true
    t.check_constraint "octet_length(salt) = 16 AND octet_length(recovery_salt) = 16", name: "journal_vaults_salt_length"
    t.check_constraint "octet_length(wrapped_dek) = 48 AND octet_length(wrapped_dek_recovery) = 48", name: "journal_vaults_wrapped_length"
    t.check_constraint "octet_length(wrapped_dek_iv) = 12 AND octet_length(wrapped_dek_recovery_iv) = 12", name: "journal_vaults_iv_length"
  end

  create_table "note_links", force: :cascade do |t|
    t.bigint "source_note_id", null: false
    t.bigint "target_note_id"
    t.citext "target_title", null: false
    t.datetime "created_at", null: false
    t.index ["source_note_id", "target_title"], name: "index_note_links_on_source_note_id_and_target_title", unique: true
    t.index ["target_note_id"], name: "index_note_links_on_target_note_id"
    t.index ["target_title"], name: "index_note_links_on_target_title"
  end

  create_table "notes", force: :cascade do |t|
    t.bigint "folder_id"
    t.text "title", null: false
    t.string "icon"
    t.jsonb "content", default: {"type" => "doc", "content" => []}, null: false
    t.text "content_text", default: "", null: false
    t.virtual "search_vector", type: :tsvector, as: "(setweight(to_tsvector('english'::regconfig, COALESCE(title, ''::text)), 'A'::\"char\") || setweight(to_tsvector('english'::regconfig, COALESCE(content_text, ''::text)), 'B'::\"char\"))", stored: true
    t.boolean "pinned", default: false, null: false
    t.decimal "position", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "topic_id"
    t.index "lower(title)", name: "index_notes_kept_on_lower_title", where: "(discarded_at IS NULL)"
    t.index ["discarded_at"], name: "index_notes_in_trash", where: "(discarded_at IS NOT NULL)"
    t.index ["folder_id"], name: "index_notes_on_folder_id"
    t.index ["search_vector"], name: "index_notes_on_search_vector", using: :gin
    t.index ["title"], name: "index_notes_on_title_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["topic_id"], name: "index_notes_on_topic_id"
    t.index ["updated_at"], name: "index_notes_kept_by_recent", where: "(discarded_at IS NULL)"
    t.check_constraint "char_length(title) >= 1 AND char_length(title) <= 200", name: "notes_title_length"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", default: "violet", null: false
    t.string "icon"
    t.decimal "position", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "char_length(name::text) >= 1 AND char_length(name::text) <= 100", name: "projects_name_length"
    t.check_constraint "color::text = ANY (ARRAY['gray'::character varying, 'red'::character varying, 'orange'::character varying, 'amber'::character varying, 'yellow'::character varying, 'lime'::character varying, 'green'::character varying, 'teal'::character varying, 'cyan'::character varying, 'blue'::character varying, 'indigo'::character varying, 'violet'::character varying, 'purple'::character varying, 'pink'::character varying]::text[])", name: "projects_color_in_palette"
  end

  create_table "resources", force: :cascade do |t|
    t.bigint "topic_id"
    t.text "title", null: false
    t.text "url"
    t.enum "kind", default: "article", null: false, enum_type: "resource_kind"
    t.enum "status", default: "to_learn", null: false, enum_type: "resource_status"
    t.integer "progress", limit: 2, default: 0, null: false
    t.integer "rating", limit: 2
    t.date "started_on"
    t.date "finished_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["topic_id"], name: "index_resources_on_topic_id"
    t.check_constraint "char_length(title) >= 1 AND char_length(title) <= 300", name: "resources_title_length"
    t.check_constraint "progress >= 0 AND progress <= 100", name: "resources_progress_range"
    t.check_constraint "rating IS NULL OR rating >= 1 AND rating <= 5", name: "resources_rating_range"
    t.check_constraint "url IS NULL OR url ~* '^https?://'::text", name: "resources_url_http"
  end

  create_table "sections", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "name", limit: 100, null: false
    t.decimal "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_sections_on_project_id"
    t.check_constraint "char_length(name::text) >= 1", name: "sections_name_length"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "study_sessions", force: :cascade do |t|
    t.bigint "topic_id"
    t.bigint "resource_id"
    t.date "studied_on", null: false
    t.integer "duration_minutes", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resource_id"], name: "index_study_sessions_on_resource_id"
    t.index ["studied_on"], name: "index_study_sessions_on_studied_on"
    t.index ["topic_id"], name: "index_study_sessions_on_topic_id"
    t.check_constraint "duration_minutes >= 1 AND duration_minutes <= 1440", name: "study_sessions_duration_range"
  end

  create_table "taggings", force: :cascade do |t|
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.string "taggable_type", null: false
    t.bigint "taggable_id", null: false
    t.index ["tag_id", "taggable_type", "taggable_id"], name: "index_taggings_on_tag_id_and_taggable_type_and_taggable_id", unique: true
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable_type_and_taggable_id"
  end

  create_table "tags", force: :cascade do |t|
    t.citext "name", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.check_constraint "char_length(name::text) >= 1 AND char_length(name::text) <= 50", name: "tags_name_length"
    t.check_constraint "color IS NULL OR (color::text = ANY (ARRAY['gray'::character varying, 'red'::character varying, 'orange'::character varying, 'amber'::character varying, 'yellow'::character varying, 'lime'::character varying, 'green'::character varying, 'teal'::character varying, 'cyan'::character varying, 'blue'::character varying, 'indigo'::character varying, 'violet'::character varying, 'purple'::character varying, 'pink'::character varying]::text[]))", name: "tags_color_in_palette"
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
    t.decimal "position", null: false
    t.virtual "search_vector", type: :tsvector, as: "to_tsvector('simple'::regconfig, COALESCE(title, ''::text))", stored: true
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "due_at"
    t.text "recurrence_rule"
    t.index ["completed_at", "id"], name: "index_tasks_completed_log", order: :desc, where: "((status = 'done'::status_enum) AND (discarded_at IS NULL))"
    t.index ["discarded_at"], name: "index_tasks_in_trash", where: "(discarded_at IS NOT NULL)"
    t.index ["due_date"], name: "index_tasks_open_by_due_date", where: "((discarded_at IS NULL) AND (status = ANY (ARRAY['todo'::status_enum, 'in_progress'::status_enum])))"
    t.index ["parent_id"], name: "index_tasks_on_parent_id"
    t.index ["project_id", "section_id", "position"], name: "index_tasks_kept_by_container", where: "(discarded_at IS NULL)"
    t.index ["search_vector"], name: "index_tasks_on_search_vector", using: :gin
    t.index ["section_id"], name: "index_tasks_on_section_id"
    t.check_constraint "(status = 'done'::status_enum) = (completed_at IS NOT NULL)", name: "tasks_done_iff_completed_at"
    t.check_constraint "char_length(btrim(title)) >= 1 AND char_length(btrim(title)) <= 500", name: "tasks_title_check"
    t.check_constraint "due_at IS NULL OR due_date IS NOT NULL", name: "tasks_due_at_needs_due_date"
    t.check_constraint "estimate_minutes IS NULL OR estimate_minutes >= 1 AND estimate_minutes <= 10080", name: "tasks_estimate_range"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "tasks_not_own_parent"
    t.check_constraint "recurrence_rule IS NULL OR char_length(recurrence_rule) <= 120", name: "tasks_recurrence_rule_length"
  end

  create_table "topics", force: :cascade do |t|
    t.citext "name", null: false
    t.string "color", default: "blue", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_topics_on_name", unique: true
    t.check_constraint "char_length(name::text) >= 1 AND char_length(name::text) <= 60", name: "topics_name_length"
    t.check_constraint "color::text = ANY (ARRAY['gray'::character varying, 'red'::character varying, 'orange'::character varying, 'amber'::character varying, 'yellow'::character varying, 'lime'::character varying, 'green'::character varying, 'teal'::character varying, 'cyan'::character varying, 'blue'::character varying, 'indigo'::character varying, 'violet'::character varying, 'purple'::character varying, 'pink'::character varying]::text[])", name: "topics_color_in_palette"
  end

  create_table "tracker_entries", force: :cascade do |t|
    t.bigint "tracker_id", null: false
    t.date "logged_on", null: false
    t.decimal "value", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tracker_id", "logged_on"], name: "index_tracker_entries_on_tracker_id_and_logged_on", unique: true
    t.check_constraint "note IS NULL OR char_length(note) <= 500", name: "tracker_entries_note_length"
    t.check_constraint "value >= 0::numeric", name: "tracker_entries_value_not_negative"
  end

  create_table "trackers", force: :cascade do |t|
    t.string "name", null: false
    t.string "icon"
    t.string "color", default: "green", null: false
    t.enum "kind", default: "boolean", null: false, enum_type: "tracker_kind"
    t.string "unit"
    t.decimal "target"
    t.jsonb "frequency", default: {"type" => "daily"}, null: false
    t.decimal "position", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "system_key"
    t.index ["system_key"], name: "index_trackers_on_system_key", unique: true, where: "(system_key IS NOT NULL)"
    t.check_constraint "(frequency ->> 'type'::text) = ANY (ARRAY['daily'::text, 'weekdays'::text, 'weekly'::text])", name: "trackers_frequency_type"
    t.check_constraint "char_length(name::text) >= 1 AND char_length(name::text) <= 60", name: "trackers_name_length"
    t.check_constraint "color::text = ANY (ARRAY['gray'::character varying, 'red'::character varying, 'orange'::character varying, 'amber'::character varying, 'yellow'::character varying, 'lime'::character varying, 'green'::character varying, 'teal'::character varying, 'cyan'::character varying, 'blue'::character varying, 'indigo'::character varying, 'violet'::character varying, 'purple'::character varying, 'pink'::character varying]::text[])", name: "trackers_color_in_palette"
    t.check_constraint "target IS NULL OR target > 0::numeric", name: "trackers_target_positive"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "flashcard_reviews", "flashcards", on_delete: :cascade
  add_foreign_key "flashcards", "notes", on_delete: :nullify
  add_foreign_key "flashcards", "topics", on_delete: :nullify
  add_foreign_key "folders", "folders", column: "parent_id", on_delete: :restrict
  add_foreign_key "journal_vaults", "users", on_delete: :cascade
  add_foreign_key "note_links", "notes", column: "source_note_id", on_delete: :cascade
  add_foreign_key "note_links", "notes", column: "target_note_id", on_delete: :nullify
  add_foreign_key "notes", "folders", on_delete: :nullify
  add_foreign_key "notes", "topics", on_delete: :nullify
  add_foreign_key "resources", "topics", on_delete: :nullify
  add_foreign_key "sections", "projects", on_delete: :cascade
  add_foreign_key "sessions", "users", on_delete: :cascade
  add_foreign_key "study_sessions", "resources", on_delete: :nullify
  add_foreign_key "study_sessions", "topics", on_delete: :nullify
  add_foreign_key "taggings", "tags", on_delete: :cascade
  add_foreign_key "task_events", "tasks", on_delete: :cascade
  add_foreign_key "tasks", "projects", on_delete: :nullify
  add_foreign_key "tasks", "sections", on_delete: :nullify
  add_foreign_key "tasks", "tasks", column: "parent_id", on_delete: :cascade
  add_foreign_key "tracker_entries", "trackers", on_delete: :cascade
end
