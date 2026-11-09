class Task < ApplicationRecord
  include Discardable
  include Positionable
  include Taggable

  OPEN_STATUSES = %w[todo in_progress].freeze

  belongs_to :project, optional: true
  belongs_to :section, optional: true
  belongs_to :parent, class_name: "Task", optional: true, inverse_of: :subtasks
  has_many :subtasks, -> { kept.order(:position, :id) }, class_name: "Task", foreign_key: :parent_id,
    inverse_of: :parent
  has_many :events, -> { order(:occurred_at, :id) }, class_name: "TaskEvent", dependent: :delete_all

  # Postgres enums (status_enum, priority_enum). Priorities sort in declaration order, so
  # ORDER BY priority DESC puts urgent first. `prefix:` avoids clashing with `Task.none`.
  enum :status, %w[todo in_progress done cancelled].index_by(&:itself), validate: true
  enum :priority, %w[none low medium high urgent].index_by(&:itself), prefix: true, validate: true

  scope :open, -> { where(status: OPEN_STATUSES) }
  scope :top_level, -> { where(parent_id: nil) }

  normalizes :title, with: ->(title) { title.strip }

  validates :title, presence: true, length: { maximum: 500 }
  validates :estimate_minutes, numericality: { only_integer: true, in: 1..10_080 }, allow_nil: true
  validate :parent_is_top_level, :not_a_parent_when_nesting, :section_belongs_to_project, :project_is_active
  validate :recurrence_rule_is_valid

  normalizes :recurrence_rule, with: ->(rule) { rule.strip.upcase.presence }

  before_validation :inherit_container_from_parent, :clear_section_when_project_moves, :sync_due_date_and_time
  before_save :sync_completed_at
  before_save :move_to_end_of_new_container, if: :container_changed?
  after_save :move_subtasks_with_parent, :record_events
  after_save :schedule_next_occurrence, if: -> { saved_change_to_status?(to: "done") && recurrence_rule.present? }
  after_create :record_created_event

  # { parent_id => [subtask count, done count] } for the given tasks, in one query.
  def self.subtask_counts_for(tasks)
    kept.where(parent_id: tasks.map(&:id)).where.not(status: "cancelled").group(:parent_id)
      .pluck(:parent_id, Arel.sql("count(*)"), Arel.sql("count(*) FILTER (WHERE status = 'done')"))
      .to_h { |parent_id, total, done| [ parent_id, [ total, done ] ] }
  end

  def open? = OPEN_STATUSES.include?(status)

  def recurrence = (Recurrence.parse(recurrence_rule) if recurrence_rule.present?)

  # Kept tasks that were discarded at the same moment as this one (a parent and its subtasks).
  def restore!
    transaction do
      Task.where(parent_id: id).where(discarded_at: (discarded_at - 1.second)..(discarded_at + 1.second)).update_all(discarded_at: nil) if discarded_at
      update!(discarded_at: nil)
    end
  end

  def overdue?
    return false unless open? && due_date
    due_at ? due_at < Time.current : due_date < Date.current
  end

  def complete! = update!(status: "done")

  def reopen!
    update!(status: "todo") if done? || cancelled?
  end

  # Discarding a parent also discards its subtasks, all in one transaction.
  def discard!
    transaction do
      subtasks.each(&:discard!)
      super
    end
  end

  private
    def position_siblings = Task.kept.where(project_id:, section_id:, parent_id:)

    def move_to_end_of_new_container = append_to_end

    def container_changed?
      persisted? && !position_changed? && (project_id_changed? || section_id_changed? || parent_id_changed?)
    end

    def inherit_container_from_parent
      return unless parent

      self.project_id = parent.project_id
      self.section_id = parent.section_id
    end

    # Moving to another project (or the Inbox) leaves the old project's section behind.
    def clear_section_when_project_moves
      self.section_id = nil if project_id_changed? && !section_id_changed? && !parent
    end

    # due_at (a moment) wins over due_date (a day): the date is derived in the user's zone.
    # Changing only the date keeps the time of day, so snoozing a 6 pm task keeps it at 6 pm.
    def sync_due_date_and_time
      if due_at_changed? && due_at
        self.due_date = due_at.in_time_zone.to_date
      elsif due_date_changed? && due_date.nil?
        self.due_at = nil
      elsif due_date_changed? && due_at
        local = due_at.in_time_zone
        self.due_at = Time.zone.local(due_date.year, due_date.month, due_date.day, local.hour, local.min)
      end
    end

    def sync_completed_at
      return unless status_changed?
      self.completed_at = done? ? Time.current : nil
    end

    def move_subtasks_with_parent
      return unless saved_change_to_project_id? || saved_change_to_section_id?
      Task.where(parent_id: id).update_all(project_id:, section_id:, updated_at: Time.current)
    end

    # Events are written inside the same transaction as the change: if the save rolls back,
    # so does its history, and analytics never count a change that didn't happen.
    def record_created_event
      events.create!(event: "created", to_status: status, to_due_date: due_date)
    end

    def record_events
      return if previously_new_record?

      if saved_change_to_status?
        from, to = saved_change_to_status
        events.create!(event: "status_changed", from_status: from, to_status: to)
      end
      if saved_change_to_due_date?
        from, to = saved_change_to_due_date
        events.create!(event: "rescheduled", from_due_date: from, to_due_date: to)
      end
      events.create!(event: "discarded", from_status: status) if saved_change_to_discarded_at? && discarded?
    end

    # Completing a recurring task creates the next one (same transaction), copying what makes it
    # "the same task" and moving its due date/time to the next occurrence. The done one stays done.
    def schedule_next_occurrence
      next_date = recurrence.next_occurrence(due_date)
      next_due_at = (Time.zone.local(next_date.year, next_date.month, next_date.day, due_at.in_time_zone.hour, due_at.in_time_zone.min) if due_at)
      copy = Task.create!(
        attributes.slice(*%w[title description priority project_id section_id parent_id estimate_minutes recurrence_rule])
          .merge("due_date" => next_date, "due_at" => next_due_at)
      )
      copy.tags = tags
    end

    def recurrence_rule_is_valid
      return if recurrence_rule.blank?
      self.recurrence_rule = recurrence.to_s
    rescue Recurrence::Invalid => e
      errors.add(:recurrence_rule, e.message)
    end

    def parent_is_top_level
      return unless parent

      errors.add(:parent_id, "can't be a subtask (one level of nesting only)") if parent.parent_id
      errors.add(:parent_id, "can't be the task itself") if parent_id == id
      errors.add(:parent_id, "is not available") if parent.discarded?
    end

    def not_a_parent_when_nesting
      return unless parent_id_changed? && parent_id && persisted?
      errors.add(:parent_id, "can't be set on a task that has subtasks") if Task.kept.exists?(parent_id: id)
    end

    def section_belongs_to_project
      return unless section
      errors.add(:section_id, "belongs to a different project") if section.project_id != project_id
    end

    def project_is_active
      return unless project&.archived? && (new_record? || project_id_changed?)
      errors.add(:project_id, "is archived")
    end
end
