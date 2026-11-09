class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_one :journal_vault, dependent: :destroy

  # users.settings keys and their types. Unknown keys are dropped.
  SETTINGS = { "journal_mood_mirror" => :boolean, "week_start" => :integer }.freeze

  def settings=(value)
    clean = value.to_h.stringify_keys.slice(*SETTINGS.keys).to_h do |key, v|
      [ key, SETTINGS[key] == :boolean ? ActiveModel::Type::Boolean.new.cast(v) : Integer(v, exception: false) ]
    end
    super((settings || {}).merge(clean))
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  # Browsers may report legacy aliases (e.g. "Asia/Calcutta"); store the canonical name.
  normalizes :time_zone, with: ->(tz) { TZInfo::Timezone.get(tz).canonical_identifier rescue tz }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 10 }, allow_nil: true
  validate :time_zone_exists
  validate :only_one_user, on: :create

  private
    def time_zone_exists
      errors.add(:time_zone, "is not a known time zone") unless ActiveSupport::TimeZone[time_zone.to_s]
    end

    # Lumen is single-user (PRD §1.4).
    def only_one_user
      errors.add(:base, "An account already exists") if User.exists?
    end
end
