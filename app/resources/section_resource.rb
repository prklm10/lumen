class SectionResource
  include Alba::Resource

  attributes :id, :name, :project_id
  attribute(:position) { |section| section.position.to_f }
end
