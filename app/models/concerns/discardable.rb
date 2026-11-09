# Soft delete: rows get a discarded_at timestamp instead of being removed, so a trash
# view can restore them later (GLB-5). Discarded rows are hidden through the `kept` scope.
module Discardable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(discarded_at: nil) }
  end

  def discarded? = discarded_at.present?

  def discard!
    update!(discarded_at: Time.current) unless discarded?
  end
end
