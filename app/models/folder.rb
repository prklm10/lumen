class Folder < ApplicationRecord
  include Positionable

  belongs_to :parent, class_name: "Folder", optional: true, inverse_of: :children
  has_many :children, class_name: "Folder", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_exception
  has_many :notes, dependent: :restrict_with_exception

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 100 }
  validate :parent_is_not_a_descendant

  # This folder's id plus every folder below it, at any depth, in one recursive query.
  def self.subtree_ids(root_id)
    connection.select_values(sanitize_sql_array([ <<~SQL, root_id ])).map(&:to_i)
      WITH RECURSIVE subtree(id) AS (
        SELECT id FROM folders WHERE id = ?
        UNION ALL
        SELECT f.id FROM folders f JOIN subtree s ON f.parent_id = s.id
      )
      SELECT id FROM subtree
    SQL
  end

  # Deleting a folder keeps its contents: subfolders and notes move up to its parent.
  def dissolve!
    transaction do
      children.update_all(parent_id:, updated_at: Time.current)
      Note.where(folder_id: id).update_all(folder_id: parent_id, updated_at: Time.current)
      reload.destroy!
    end
  end

  private
    def position_siblings = Folder.where(parent_id:)

    def parent_is_not_a_descendant
      return unless parent_id && persisted? && parent_id_changed?
      errors.add(:parent_id, "can't be the folder itself or one inside it") if Folder.subtree_ids(id).include?(parent_id)
    end
end
