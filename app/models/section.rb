class Section < ApplicationRecord
  include Positionable

  belongs_to :project
  has_many :tasks

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 100 }

  private
    def position_siblings = Section.where(project_id:)
end
