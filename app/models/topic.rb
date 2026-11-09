class Topic < ApplicationRecord
  has_many :notes, dependent: :nullify
  has_many :resources, dependent: :nullify
  has_many :study_sessions, dependent: :nullify
  has_many :flashcards, dependent: :nullify

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 60 }, uniqueness: true
  validates :color, inclusion: { in: Palette::COLORS }
end
