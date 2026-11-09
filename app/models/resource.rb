# A book, course, video, article or podcast you're learning from (LRN-9).
class Resource < ApplicationRecord
  belongs_to :topic, optional: true
  has_many :study_sessions, dependent: :nullify

  enum :kind, %w[book course video article podcast other].index_by(&:itself), validate: true
  enum :status, %w[to_learn in_progress done].index_by(&:itself), validate: true

  normalizes :title, with: ->(t) { t.strip }
  normalizes :url, with: ->(u) { u.strip.presence }

  validates :title, presence: true, length: { maximum: 300 }
  validates :url, format: { with: %r{\Ahttps?://\S+\z}i, message: "must start with http:// or https://" }, allow_nil: true
  validates :progress, numericality: { only_integer: true, in: 0..100 }
  validates :rating, numericality: { only_integer: true, in: 1..5 }, allow_nil: true

  before_save :track_dates

  private
    # Status drives the dates and progress, so "done" always means 100% and has a finish date.
    def track_dates
      self.started_on ||= Date.current if in_progress? || done?
      if done?
        self.progress = 100
        self.finished_on ||= Date.current
      else
        self.finished_on = nil
      end
      self.status = "in_progress" if to_learn? && progress.positive? && progress_changed?
    end
end
