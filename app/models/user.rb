class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

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
