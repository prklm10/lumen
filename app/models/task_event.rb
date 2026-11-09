# Append-only history of a task (TSK-12): what analytics (Phase 5) are computed from.
class TaskEvent < ApplicationRecord
  belongs_to :task

  enum :event, %w[created status_changed rescheduled discarded].index_by(&:itself)

  def readonly? = persisted?
end
