# Shared tags (GLB-4). Tasks today; notes and resources reuse it in Phase 2+.
module Taggable
  extend ActiveSupport::Concern

  included do
    has_many :taggings, as: :taggable, dependent: :delete_all
    has_many :tags, -> { order(:name) }, through: :taggings
  end

  # Replaces the full tag set: `task.tag_names = ["rails", "#Postgres"]`.
  def tag_names=(names)
    self.tags = Array(names).filter_map { |name| Tag.normalize_value_for(:name, name).presence }
      .uniq(&:downcase)
      .map { |name| Tag.find_or_create_by!(name:) }
  end
end
