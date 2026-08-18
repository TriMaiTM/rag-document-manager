Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  root "home#index"
  get "up" => "rails/health#show", as: :rails_health_check
  resources :workspaces, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    patch :reorder, on: :collection
    resource :semantic_search, only: :show
    resources :chat_sessions, only: [ :index, :show, :create, :update, :destroy ] do
      resources :chat_messages, only: :create do
        post :retry, on: :member
      end
    end
    resources :memberships, only: [ :index, :create, :update, :destroy ]
    resources :documents, only: [ :index, :show, :new, :create, :destroy ] do
      get :download, on: :member
      get :processing_status, on: :member
      post :retry_processing, on: :member
    end
  end

  resource :onboarding, controller: "onboarding", only: [ :show, :update ]

  namespace :admin do
    root to: "dashboard#index"
    get "dashboard", to: "dashboard#index"
    resources :users, only: [ :index, :show, :update ]
    resources :workspaces, only: [ :index, :show ]
    resources :settings, only: [ :index, :create, :update ]
    patch "settings", to: "settings#update"
  end
end
