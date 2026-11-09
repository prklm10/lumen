class Tag < ApplicationRecord
  has_many :taggings, dependent: :delete_all

  normalizes :name, with: ->(name) { name.to_s.strip.delete_prefix("#").strip }

  validates :name, presence: true, length: { maximum: 50 }, uniqueness: true
  validates :color, inclusion: { in: Palette::COLORS }, allow_nil: true
end
