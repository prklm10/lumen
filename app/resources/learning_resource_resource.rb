# Serializes Resource (a book/course/…); named to avoid reading as "resource resource".
class LearningResourceResource
  include Alba::Resource

  attributes :id, :topic_id, :title, :url, :kind, :status, :progress, :rating, :started_on, :finished_on, :created_at, :updated_at
  attribute(:minutes_studied) { |r| params.fetch(:minutes, {}).fetch(r.id, 0) }
end
