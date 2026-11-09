# TSK-7: recurring tasks. A small subset of RFC 5545 RRULE, e.g. "FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,WE".
class AddRecurrenceToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :recurrence_rule, :text
    add_check_constraint :tasks, "recurrence_rule IS NULL OR char_length(recurrence_rule) <= 120", name: "tasks_recurrence_rule_length"
    # Discarded rows are scanned by the trash view and the 30-day purge job.
    add_index :tasks, :discarded_at, where: "discarded_at IS NOT NULL", name: "index_tasks_in_trash"
    add_index :notes, :discarded_at, where: "discarded_at IS NOT NULL", name: "index_notes_in_trash"
  end
end
