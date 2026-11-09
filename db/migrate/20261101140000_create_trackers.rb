# Phase 3 — Daily tracker (PRD §4.4, §8.4). Not journal data, so stored in plain columns
# that SQL analytics can read.
class CreateTrackers < ActiveRecord::Migration[8.1]
  COLORS = %w[gray red orange amber yellow lime green teal cyan blue indigo violet purple pink].freeze

  def change
    create_enum :tracker_kind, %w[boolean count duration numeric scale]

    create_table :trackers do |t|
      t.string :name, null: false
      t.string :icon                       # an emoji
      t.string :color, null: false, default: "green"
      t.enum :kind, enum_type: :tracker_kind, null: false, default: "boolean"
      t.string :unit                       # "glasses", "km", "hours"… (duration is always minutes)
      t.decimal :target                    # "at least" this much counts as done; null = any check-in counts
      # {"type":"daily"} | {"type":"weekdays","days":[1,3,5]} (ISO: 1 = Monday) | {"type":"weekly","times":3}
      t.jsonb :frequency, null: false, default: { type: "daily" }
      t.decimal :position, null: false
      t.datetime :archived_at
      t.timestamps
    end
    add_check_constraint :trackers, "char_length(name) BETWEEN 1 AND 60", name: "trackers_name_length"
    add_check_constraint :trackers, "color IN (#{COLORS.map { |c| "'#{c}'" }.join(", ")})", name: "trackers_color_in_palette"
    add_check_constraint :trackers, "target IS NULL OR target > 0", name: "trackers_target_positive"
    add_check_constraint :trackers, "frequency->>'type' IN ('daily', 'weekdays', 'weekly')", name: "trackers_frequency_type"

    create_table :tracker_entries do |t|
      t.references :tracker, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :logged_on, null: false
      t.decimal :value, null: false
      t.text :note
      t.timestamps
    end
    # One entry per tracker per day: check-ins are upserts (INSERT … ON CONFLICT).
    add_index :tracker_entries, %i[tracker_id logged_on], unique: true
    add_check_constraint :tracker_entries, "value >= 0", name: "tracker_entries_value_not_negative"
    add_check_constraint :tracker_entries, "note IS NULL OR char_length(note) <= 500", name: "tracker_entries_note_length"
  end
end
