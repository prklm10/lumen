# params: stats ({ id => TrackerStatsQuery::Stats }) and recent ({ id => [entries] }), both
# preloaded for the whole list so serializing N trackers doesn't run N queries.
class TrackerResource
  include Alba::Resource

  attributes :id, :name, :icon, :color, :kind, :unit, :frequency, :system_key, :archived_at, :created_at, :updated_at
  attribute(:target) { |tracker| tracker.target&.to_f }
  attribute(:position) { |tracker| tracker.position.to_f }
  attribute(:archived) { |tracker| tracker.archived? }
  attribute(:stats) { |tracker| params[:stats].fetch(tracker.id, TrackerStatsQuery::Stats.empty).to_h }
  attribute(:recent_entries) do |tracker|
    TrackerEntryResource.new(params[:recent].fetch(tracker.id, [])).to_h
  end
end
