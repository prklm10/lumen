class FolderResource
  include Alba::Resource

  attributes :id, :name, :parent_id
  attribute(:position) { |folder| folder.position.to_f }
end
