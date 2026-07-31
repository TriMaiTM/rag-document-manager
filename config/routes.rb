Rails.application.routes.draw do
  resource :session, only: [ :new, :create, :destroy ]
  resource :registration, only: [ :new, :create ]
  resources :passwords, param: :token, only: [ :new, :create, :edit, :update ]

  root "home#index"
  get "up" => "rails/health#show", as: :rails_health_check
  resources :workspaces, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    resources :memberships, only: [ :index, :create, :update, :destroy ]
  end
end
