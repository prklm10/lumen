# Permanently deletes tasks and notes that have been in the trash longer than RETENTION.
# Scheduled daily via config/recurring.yml (Solid Queue).
class TrashPurgeJob < ApplicationJob
  RETENTION = 30.days

  def perform(older_than: RETENTION.ago)
    Task.where(discarded_at: ...older_than).find_each(&:destroy!)
    Note.where(discarded_at: ...older_than).find_each(&:destroy!)
  end
end
