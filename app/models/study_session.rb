# Time spent studying a topic, optionally on a specific resource (LRN-10).
class StudySession < ApplicationRecord
  belongs_to :topic, optional: true
  belongs_to :resource, optional: true

  validates :studied_on, presence: true
  validates :duration_minutes, numericality: { only_integer: true, in: 1..1440 }
  validate :not_in_the_future

  before_validation { self.topic_id ||= resource&.topic_id }

  private
    def not_in_the_future
      errors.add(:studied_on, "can't be in the future") if studied_on && studied_on > Date.current
    end
end
