Rails.application.routes.draw do
  root "home#index"
  get "up" => "rails/health#show", as: :rails_health_check
  resources :workspaces, only: [ :index, :show, :new, :create, :edit, :update ]
end
