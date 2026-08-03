Rails.application.routes.draw do
  devise_for :users

  root "home#index"
  get "up" => "rails/health#show", as: :rails_health_check
  resources :workspaces, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    resources :memberships, only: [ :index, :create, :update, :destroy ]
    resources :documents, only: [ :index, :show, :new, :create, :destroy ] do
      get :download, on: :member
    end
  end
end
