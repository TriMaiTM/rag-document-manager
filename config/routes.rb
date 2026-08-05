Rails.application.routes.draw do
  devise_for :users

  root "home#index"
  get "up" => "rails/health#show", as: :rails_health_check
  resources :workspaces, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    resource :semantic_search, only: :show
    resources :chat_sessions, only: [ :index, :show, :create, :destroy ] do
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
end
