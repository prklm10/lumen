class StudySessionResource
  include Alba::Resource

  attributes :id, :topic_id, :resource_id, :studied_on, :duration_minutes, :notes, :created_at
end
