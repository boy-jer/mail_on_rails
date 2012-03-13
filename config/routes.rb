MailOnRails::Application.routes.draw do
  
  resources :users

  resources :domains
  
  match '/set_random_password' => 'users#set_random_password', :as => :set_random_password
  
  match '/set_password' => 'users#set_password', :as => :set_password
  
  match '/reset/:id' => 'users#reset', :as => :reset
  
  root :to => 'application#index'
  
end