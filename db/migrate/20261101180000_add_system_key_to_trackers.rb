# TRK-9: built-in trackers (the Mood tracker) are found by a stable key, not by a renameable name.
class AddSystemKeyToTrackers < ActiveRecord::Migration[8.1]
  def change
    add_column :trackers, :system_key, :string
    add_index :trackers, :system_key, unique: true, where: "system_key IS NOT NULL"
  end
end
