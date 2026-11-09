# params[:open_task_counts] is { project_id => count }, preloaded with one GROUP BY query.
class ProjectResource
  include Alba::Resource

  attributes :id, :name, :color, :icon, :archived_at, :created_at, :updated_at
  attribute(:position) { |project| project.position.to_f }
  attribute(:archived) { |project| project.archived? }
  attribute(:open_task_count) { |project| params.fetch(:open_task_counts, {}).fetch(project.id, 0) }
  many :sections, resource: SectionResource
end
