Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resource :session, only: %i[show create destroy]
      resource :setup, only: :create
      resource :meta, only: :show, controller: "meta"
      resource :me, only: :update
      resource :weekly_review, only: :show
      resource :export, only: :show do
        get :notes
      end

      resources :tasks, only: %i[index show create update destroy] do
        collection do
          patch :reorder
          get :counts
        end
        member do
          post :complete
          post :reopen
        end
      end
      resources :projects, only: %i[index show create update destroy] do
        resources :sections, only: %i[create update destroy]
      end
      resources :tags, only: %i[index update destroy]

      get "trash", to: "trash#index"
      delete "trash", to: "trash#empty"
      post "trash/:type/:id/restore", to: "trash#restore", as: :trash_restore
      delete "trash/:type/:id", to: "trash#destroy", as: :trash_item

      resources :notes, only: %i[index show create update destroy]
      resources :folders, only: %i[index create update destroy]
      resources :uploads, only: :create
      resource :search, only: :show

      resources :topics, only: %i[index create update destroy]
      resources :resources, only: %i[index create update destroy]
      resources :study_sessions, only: %i[index create destroy]
      resources :flashcards, only: %i[index create update destroy] do
        get :due, on: :collection
        post :review, on: :member
      end

      scope :analytics, controller: :analytics, as: :analytics do
        get :tasks
        get :trackers
        get :learning
      end

      namespace :journal do
        resource :vault, only: %i[show create update]
        resources :entries, only: %i[index show create update destroy] do
          get :dates, on: :collection
        end
      end

      resources :trackers, only: %i[index show create update destroy] do
        post :mood, on: :collection
        resources :entries, only: %i[index update destroy], param: :date, controller: "tracker_entries",
          constraints: { date: /\d{4}-\d{2}-\d{2}/ }
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Uploaded images, resized to WebP and stripped of metadata. Signed-in only.
  get "media/:signed_id/:variant", to: "media#show", as: :media,
    constraints: { variant: Regexp.union(Media::VARIANTS.keys) }

  # Everything else is the Vue SPA. Leave /api and Rails engine paths (Active Storage) alone.
  root "spa#show"
  get "*path", to: "spa#show", format: false,
    constraints: ->(req) { !req.path.start_with?("/api/", "/rails/", "/media/") }
end
