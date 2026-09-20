Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "runs#index"

  # Locally generated media (e.g. C1 candidates saved under tmp/) lives outside public/, so serve
  # it through a checked controller instead of exposing the filesystem.
  get "media/*path", to: "media#show", as: :media, format: false

  # Notebook UI: a run is one page of step cells.
  resources :runs, only: [:index, :show, :create] do
    member do
      post :run_next
      post :run_to_decision
      post :approve
      post :abandon
    end

    resources :steps, only: [], controller: "run_steps" do
      member do
        post :run
        post :interpret
        post :decide
        post :decision
        post :narrow
        post :note
        get  :composer
      end
    end
  end
end
