# params[:subtask_counts] is { task_id => [total, done] } from Task.subtask_counts_for, so
# list endpoints don't run one COUNT per task (N+1). params[:with_subtasks] adds the subtasks.
class TaskResource
  include Alba::Resource

  attributes :id, :title, :description, :status, :priority, :due_date, :due_at, :estimate_minutes,
    :completed_at, :project_id, :section_id, :parent_id, :recurrence_rule, :created_at, :updated_at
  attribute(:position) { |task| task.position.to_f }
  attribute(:overdue) { |task| task.overdue? }
  attribute(:subtask_count) { |task| params.fetch(:subtask_counts, {}).fetch(task.id, [ 0, 0 ])[0] }
  attribute(:subtask_done_count) { |task| params.fetch(:subtask_counts, {}).fetch(task.id, [ 0, 0 ])[1] }
  many :tags, resource: TagResource

  attribute :subtasks, if: proc { params[:with_subtasks] } do |task|
    TaskResource.new(task.subtasks.includes(:tags)).to_h
  end
end
