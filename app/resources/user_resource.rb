class UserResource
  include Alba::Resource

  attributes :id, :email_address, :time_zone, :settings
end
