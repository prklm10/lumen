# An encrypted journal entry. The server knows its id, date and version — nothing else.
class JournalEntry < ApplicationRecord
  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
  MAX_CIPHERTEXT = 4.megabytes

  validates :id, format: { with: UUID_FORMAT, message: "must be a v4 UUID" }
  validates :entry_date, presence: true
  validates :iv, length: { is: 12 }
  validates :ciphertext, length: { in: 16..MAX_CIPHERTEXT }

  # Writing streak from entry dates alone (they're the one thing the server can see).
  def self.writing_streak(today = Date.current)
    dates = distinct.where(entry_date: ..today).order(entry_date: :desc).limit(3660).pluck(:entry_date)
    expected = dates.first == today ? today : today - 1
    dates.take_while { |date| (date == expected).tap { expected -= 1 } }.size
  end
end
