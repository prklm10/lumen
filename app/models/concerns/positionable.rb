# Fractional ordering: `position` is numeric, so an item can be dropped between two others
# by giving it the midpoint (1.5) without renumbering its siblings. New items go last.
module Positionable
  extend ActiveSupport::Concern

  included do
    # before_save, not before_validation: siblings depend on attributes other callbacks may
    # still set during validation (a subtask inherits its parent's project, for example).
    before_save :append_to_end, if: -> { position.nil? }
  end

  private
    # Override to scope ordering to a container (a project's sections, a section's tasks…).
    def position_siblings = self.class.all

    def append_to_end
      self.position = (position_siblings.where.not(id:).maximum(:position) || 0) + 1
    end
end
