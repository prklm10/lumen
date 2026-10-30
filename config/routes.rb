Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resource :session, only: %i[show create destroy]
      resource :setup, only: :create
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Everything else is the Vue SPA. Leave /api and Rails engine paths (Active Storage) alone.
  root "spa#show"
  get "*path", to: "spa#show", format: false,
    constraints: ->(req) { !req.path.start_with?("/api/", "/rails/") }
end
