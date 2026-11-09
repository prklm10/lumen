# Phase 6 — Learn: topics, resources, study sessions and spaced-repetition flashcards
# (PRD §4.5 LRN-8…11, §8.5).
class CreateStudySchema < ActiveRecord::Migration[8.1]
  COLORS = %w[gray red orange amber yellow lime green teal cyan blue indigo violet purple pink].freeze

  def change
    create_table :topics do |t|
      t.column :name, :citext, null: false, index: { unique: true }
      t.string :color, null: false, default: "blue"
      t.text :description
      t.timestamps
    end
    add_check_constraint :topics, "char_length(name) BETWEEN 1 AND 60", name: "topics_name_length"
    add_check_constraint :topics, "color IN (#{COLORS.map { |c| "'#{c}'" }.join(", ")})", name: "topics_color_in_palette"

    add_reference :notes, :topic, foreign_key: { on_delete: :nullify }

    create_enum :resource_kind, %w[book course video article podcast other]
    create_enum :resource_status, %w[to_learn in_progress done]
    create_table :resources do |t|
      t.references :topic, foreign_key: { on_delete: :nullify }
      t.text :title, null: false
      t.text :url
      t.enum :kind, enum_type: :resource_kind, null: false, default: "article"
      t.enum :status, enum_type: :resource_status, null: false, default: "to_learn"
      t.integer :progress, limit: 2, null: false, default: 0
      t.integer :rating, limit: 2
      t.date :started_on
      t.date :finished_on
      t.timestamps
    end
    add_check_constraint :resources, "char_length(title) BETWEEN 1 AND 300", name: "resources_title_length"
    add_check_constraint :resources, "progress BETWEEN 0 AND 100", name: "resources_progress_range"
    add_check_constraint :resources, "rating IS NULL OR rating BETWEEN 1 AND 5", name: "resources_rating_range"
    add_check_constraint :resources, "url IS NULL OR url ~* '^https?://'", name: "resources_url_http"

    create_table :study_sessions do |t|
      t.references :topic, foreign_key: { on_delete: :nullify }
      t.references :resource, foreign_key: { on_delete: :nullify }
      t.date :studied_on, null: false
      t.integer :duration_minutes, null: false
      t.text :notes
      t.timestamps
    end
    add_index :study_sessions, :studied_on
    add_check_constraint :study_sessions, "duration_minutes BETWEEN 1 AND 1440", name: "study_sessions_duration_range"

    create_table :flashcards do |t|
      t.references :note, foreign_key: { on_delete: :nullify }
      t.references :topic, foreign_key: { on_delete: :nullify }
      t.text :front, null: false
      t.text :back, null: false
      t.boolean :from_note_syntax, null: false, default: false # written as "Question :: Answer" in a note
      # SM-2 state
      t.decimal :ease, precision: 4, scale: 2, null: false, default: 2.5
      t.integer :interval_days, null: false, default: 0
      t.integer :repetitions, null: false, default: 0
      t.date :due_on, null: false, default: -> { "CURRENT_DATE" }
      t.datetime :last_reviewed_at
      t.timestamps
    end
    add_index :flashcards, :due_on
    add_index :flashcards, %i[note_id front], unique: true, where: "from_note_syntax", name: "index_flashcards_from_note_syntax"
    add_check_constraint :flashcards, "char_length(front) BETWEEN 1 AND 1000 AND char_length(back) BETWEEN 1 AND 4000", name: "flashcards_text_length"
    add_check_constraint :flashcards, "ease >= 1.3", name: "flashcards_ease_floor"

    create_table :flashcard_reviews do |t|
      t.references :flashcard, null: false, foreign_key: { on_delete: :cascade }
      t.integer :grade, limit: 2, null: false
      t.integer :interval_days, null: false
      t.datetime :reviewed_at, null: false
    end
    add_index :flashcard_reviews, :reviewed_at
    add_check_constraint :flashcard_reviews, "grade BETWEEN 0 AND 5", name: "flashcard_reviews_grade_range"
  end
end
