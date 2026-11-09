class Flashcard < ApplicationRecord
  belongs_to :note, optional: true
  belongs_to :topic, optional: true
  has_many :reviews, class_name: "FlashcardReview", dependent: :delete_all

  # "Question :: Answer" on one line of a note becomes a card (LRN-11).
  SYNTAX = /\A\s*(.{1,1000}?)\s+::\s+(.{1,4000})\s*\z/

  scope :due, ->(today = Date.current) { where(due_on: ..today) }

  normalizes :front, :back, with: ->(t) { t.strip }

  validates :front, presence: true, length: { maximum: 1000 }
  validates :back, presence: true, length: { maximum: 4000 }

  before_validation { self.topic_id ||= note&.topic_id }

  # Grades are 0–5 (SM-2); the UI offers Again (1), Hard (3), Good (4), Easy (5).
  def review!(grade)
    result = Sm2.review(ease: ease.to_f, interval_days:, repetitions:, grade:)
    transaction do
      update!(ease: result.ease, interval_days: result.interval_days, repetitions: result.repetitions, due_on: result.due_on, last_reviewed_at: Time.current)
      reviews.create!(grade:, interval_days: result.interval_days, reviewed_at: Time.current)
    end
  end

  # What each grade would schedule, for the buttons' "in 6d" hints.
  def preview
    [ 1, 3, 4, 5 ].to_h { |g| [ g, Sm2.review(ease: ease.to_f, interval_days:, repetitions:, grade: g).interval_days ] }
  end

  # Creates, updates and removes a note's "Q :: A" cards to match its text. Cards are matched by
  # their question, so editing an answer keeps the card's review history.
  def self.sync_from_note(note)
    pairs = note.content_text.to_s.lines.filter_map { |line| line.match(SYNTAX)&.captures&.map(&:strip) }.uniq(&:first)
    existing = where(note:, from_note_syntax: true).index_by(&:front)
    pairs.each do |front, back|
      card = existing.delete(front) || new(note:, front:, from_note_syntax: true)
      card.update!(back:) if card.new_record? || card.back != back
    end
    existing.each_value(&:destroy!)
  end
end
