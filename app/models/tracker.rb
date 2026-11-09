class Tracker < ApplicationRecord
  include Positionable

  KINDS = %w[boolean count duration numeric scale].freeze
  FREQUENCY_TYPES = %w[daily weekdays weekly].freeze
  SCALE_MAX = 5

  has_many :entries, class_name: "TrackerEntry", dependent: :delete_all

  # prefix: `count` would clash with Tracker.count, so methods are kind_count?, kind_boolean?…
  enum :kind, KINDS.index_by(&:itself), prefix: true, validate: true

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(:position, :id) }

  normalizes :name, with: ->(name) { name.strip }
  normalizes :unit, with: ->(unit) { unit.strip.presence }

  validates :name, presence: true, length: { maximum: 60 }
  validates :color, inclusion: { in: Palette::COLORS }
  validates :icon, length: { maximum: 16 }
  validates :target, numericality: { greater_than: 0 }, allow_nil: true
  validate :frequency_shape

  before_validation :normalize_for_kind

  # The built-in Mood tracker (TRK-9). The journal can mirror each entry's mood here, by the
  # user's choice — it's then stored unencrypted, which the settings screen spells out.
  def self.mood!
    find_or_create_by!(system_key: "mood") do |t|
      t.assign_attributes(name: "Mood", icon: "😊", color: "amber", kind: "scale", frequency: { "type" => "daily" })
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(system_key: "mood")
  end

  def archived? = archived_at.present?

  def archived=(value)
    self.archived_at = ActiveModel::Type::Boolean.new.cast(value) ? (archived_at || Time.current) : nil
  end

  def frequency_type = frequency["type"]

  # Whether a day's value counts as "done" — the same rule TrackerStatsQuery uses in SQL.
  def met?(value)
    return false if value.nil?
    return value >= 1 if kind_boolean?
    target ? value >= target : true
  end

  private
    def normalize_for_kind
      self.frequency = (frequency.presence || { "type" => "daily" }).to_h.stringify_keys
      self.unit = nil if kind_boolean? || kind_duration? || kind_scale?
      self.target = nil if kind_boolean?
    end

    def frequency_shape
      case frequency_type
      when "daily"
        self.frequency = { "type" => "daily" }
      when "weekdays"
        days = Array(frequency["days"]).map { |d| Integer(d, exception: false) }
        if days.empty? || days.any? { |d| d.nil? || !d.between?(1, 7) }
          errors.add(:frequency, "needs at least one weekday (1 = Monday … 7 = Sunday)")
        else
          self.frequency = { "type" => "weekdays", "days" => days.uniq.sort }
        end
      when "weekly"
        times = Integer(frequency["times"], exception: false)
        if times&.between?(1, 7)
          self.frequency = { "type" => "weekly", "times" => times }
        else
          errors.add(:frequency, "needs 1–7 times a week")
        end
      else
        errors.add(:frequency, "must be daily, specific weekdays, or N times a week")
      end
    end

    def position_siblings = Tracker.all
end
