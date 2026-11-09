class TrackerEntry < ApplicationRecord
  belongs_to :tracker

  normalizes :note, with: ->(note) { note.strip.presence }

  validates :logged_on, presence: true
  validates :value, numericality: { greater_than_or_equal_to: 0, less_than: 1_000_000 }
  validates :note, length: { maximum: 500 }
  validate :value_fits_kind, :not_in_the_future

  private
    def value_fits_kind
      return unless tracker && value
      errors.add(:value, "must be 0 or 1") if tracker.kind_boolean? && ![ 0, 1 ].include?(value)
      errors.add(:value, "must be 1–#{Tracker::SCALE_MAX}") if tracker.kind_scale? && !(1..Tracker::SCALE_MAX).cover?(value)
      errors.add(:value, "must be a whole number") if (tracker.kind_count? || tracker.kind_duration?) && value != value.round
    end

    # "Today" is the user's today (Time.zone is the user's zone during requests).
    def not_in_the_future
      errors.add(:logged_on, "can't be in the future") if logged_on && logged_on > Date.current
    end
end
