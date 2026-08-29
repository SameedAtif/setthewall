Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Pipeline dashboard + actions
  root "pipeline#index"
  post "pipeline/ideate",        to: "pipeline#ideate"
  post "pipeline/track_a",       to: "pipeline#start_track_a"
  post "pipeline/track_b",       to: "pipeline#start_track_b"
  post "pipeline/daily",         to: "pipeline#start_daily"
  post "pipeline/refresh_stats", to: "pipeline#refresh_stats"
  post "pipeline/export",        to: "pipeline#export"
  post "pipeline/propose",       to: "pipeline#propose"

  resources :reviews, only: [:index]
  resources :human_gates, only: [:show, :update]
  resources :kb_proposals, only: [:index, :show, :update] do
    member { post :apply }
  end
end
