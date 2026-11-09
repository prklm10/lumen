class TrackerEntryResource
  include Alba::Resource

  attributes :logged_on, :note
  attribute(:value) { |entry| entry.value.to_f }
end
