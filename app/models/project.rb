class Project < ApplicationRecord
  include Positionable

  has_many :sections, -> { order(:position) }, inverse_of: :project
  has_many :tasks

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(:position, :id) }

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 100 }
  validates :color, inclusion: { in: Palette::COLORS }

  def archived? = archived_at.present?

  def archived=(value)
    self.archived_at = ActiveModel::Type::Boolean.new.cast(value) ? (archived_at || Time.current) : nil
  end
end
