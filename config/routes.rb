Rails.application.routes.draw do
  mount ActionCable.server => '/cable'
  
  scope "(:locale)", locale: /ar|en/ do
    devise_for :users
    root 'home#index'
    get 'discovery', to: 'home#index'
    
    namespace :cms do
      resources :programs do
        member do
          post :upload
        end
      end
    end
  end
  
  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => proc { [200, {}, ["OK"]] }
  
  get "test/broadcast/:program_id", to: "test#broadcast_test"

  namespace :api do
    namespace :cms do
      resources :programs, only: [:index, :show, :create, :update, :destroy] do
        member do
          post :ingest_complete
          post :publish
        end
      end
      
      resources :uploads, only: [] do
        collection do
          post :sign
          get :sign 
        end
      end
      
      namespace :mediaconvert do
        post :callback
      end
    end

    namespace :discovery do
      resources :programs, only: [:index, :show]
      get 'search', to: 'search#index'
      get 'search/suggestions', to: 'search#suggestions'
      get 'search/featured', to: 'search#featured'
      get 'search/recent', to: 'search#recent'
      
      post 'analytics/track_view', to: 'analytics#track_view'
      post 'analytics/track_progress', to: 'analytics#track_progress'
      get 'analytics/popular', to: 'analytics#popular'
    end
  end
end
