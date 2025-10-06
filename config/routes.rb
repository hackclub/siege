Rails.application.routes.draw do
  resources :projects, path: 'armory' do
    member do
      post :submit
      patch :update_status
    end
  end
  
  # Legacy redirect for old project URLs
  get "/projects", to: redirect("/armory")
  get "/projects/new", to: redirect("/armory/new")
  get "/projects/:id", to: redirect("/armory/%{id}")
  get "/projects/:id/edit", to: redirect("/armory/%{id}/edit")
  post "/projects/:id/submit", to: redirect("/armory/%{id}/submit", status: 307)
  patch "/projects/:id/update_status", to: redirect("/armory/%{id}/update_status", status: 307)
  
  root "sessions#new"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "/auth/slack_openid/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"

  resources :sessions, only: [ :create, :destroy ]
  get "/sessions/new", to: redirect("/")
  delete "/logout", to: "sessions#destroy"
  get "/welcome", to: "welcome#index", as: :welcome
  post "/welcome/complete", to: "welcome#complete", as: :welcome_complete
  get "/keep", to: "home#index", as: :keep
  get "/great-hall", to: "great_hall#index", as: :great_hall
  get "/map", to: "map#index", as: :map
  get "/great-hall/thanks", to: "great_hall#thanks", as: :great_hall_thanks
  get "/market", to: "market#index", as: :market
  post "/market/purchase", to: "market#purchase", as: :market_purchase
  get "/market/mercenary_price", to: "market#mercenary_price", as: :market_mercenary_price
  get "/market/user_coins", to: "market#user_coins", as: :market_user_coins
  post "/market/set_main_device", to: "market#set_main_device", as: :market_set_main_device
  post "/market/refund_item", to: "market#refund_item", as: :market_refund_item
  get "/market/user_purchases", to: "market#user_purchases", as: :market_user_purchases
  get "/market/get_main_device", to: "market#get_main_device", as: :market_get_main_device
  get "/market/user_region_info", to: "market#user_region_info", as: :market_user_region_info
  get "/market/tech_tree_data", to: "market#tech_tree_data", as: :market_tech_tree_data

  # Voting routes
  resources :votes, only: [] do
    member do
      patch :update_stars
      patch :toggle_vote
    end
  end

  resources :ballots, only: [] do
    member do
      patch :submit
    end
  end


  get "/admin", to: "admin#index", as: :admin
  get "/admin/projects", to: "admin#projects", as: :admin_projects
  get "/admin/users", to: "admin#users", as: :admin_users
  get "/admin/ballots", to: "admin#ballots", as: :admin_ballots
  get "/admin/referrals", to: "admin#referrals", as: :admin_referrals
  get "/admin/weekly-overview", to: "admin#weekly_overview", as: :admin_weekly_overview
  get "/admin/analytics", to: "admin#analytics", as: :admin_analytics
  get "/admin/shop-purchases", to: "admin#shop_purchases", as: :admin_shop_purchases
  get "/admin/shop-purchases/:id", to: "admin#shop_purchase_details", as: :admin_shop_purchase_details
  get "/admin/weekly-overview/:week/:user_id", to: "admin#weekly_overview_user", as: :admin_weekly_overview_user
  patch "/admin/shop-purchases/:id/fulfillment", to: "admin#update_purchase_fulfillment", as: :admin_update_purchase_fulfillment
  delete "/admin/shop-purchases/:id", to: "admin#delete_shop_purchase", as: :admin_delete_shop_purchase
  post "/admin/shop-purchases/:id/refund", to: "admin#refund_shop_purchase", as: :admin_refund_shop_purchase
  post "/admin/weekly-overview/:week/:user_id/submit_to_airtable", to: "admin#submit_to_airtable", as: :admin_submit_to_airtable
  post "/admin/weekly-overview/:week/:user_id/update_coins", to: "admin#update_user_coins", as: :admin_update_user_coins
  post "/admin/weekly-overview/:week/:user_id/save_multiplier", to: "admin#save_reviewer_multiplier", as: :admin_save_reviewer_multiplier
  post "/admin/weekly-overview/:week/:user_id/update_project_status", to: "admin#update_project_status_admin", as: :admin_update_project_status
  post "/admin/weekly-overview/:week/:user_id/update_reviewer_feedback", to: "admin#update_reviewer_feedback", as: :admin_update_reviewer_feedback
  post "/admin/projects/:project_id/update_coin_value", to: "admin#update_project_coin_value", as: :admin_update_project_coin_value
  post "/admin/projects/:project_id/update_created_date", to: "admin#update_project_created_date", as: :admin_update_project_created_date
  delete "/admin/projects/:id", to: "admin#destroy_project", as: :admin_project
  patch "/admin/projects/:id/hide", to: "admin#hide_project", as: :admin_hide_project
  patch "/admin/projects/:id/unhide", to: "admin#unhide_project", as: :admin_unhide_project
  get "/admin/ballots/:id", to: "admin#ballot_details", as: :admin_ballot_details
  get "/admin/ballots/:id/edit", to: "admin#edit_ballot", as: :edit_admin_ballot
  patch "/admin/ballots/:id", to: "admin#update_ballot", as: :admin_ballot
  delete "/admin/ballots/:id", to: "admin#destroy_ballot"
  get "/admin/users/:id", to: "admin#user_details", as: :admin_user_details
  get "/admin/users/:id/hackatime_trust", to: "admin#user_hackatime_trust", as: :admin_user_hackatime_trust
  post "/admin/users/:id/add_coins", to: "admin#add_coins", as: :admin_add_coins
  post "/admin/users/:id/unlock_color", to: "admin#unlock_color", as: :admin_unlock_color
  post "/admin/users/:id/relock_color", to: "admin#relock_color", as: :admin_relock_color
  post "/admin/users/:id/update_rank", to: "admin#update_rank", as: :admin_update_rank
  patch "/admin/users/:id/update_meeple_color", to: "admin#update_meeple_color", as: :admin_update_meeple_color
  patch "/admin/users/:id/update_address", to: "admin#update_address", as: :admin_update_address
  post "/admin/users/:id/clear_verification", to: "admin#clear_verification", as: :admin_clear_verification
  post "/admin/users/:id/set_referrer", to: "admin#set_referrer", as: :admin_set_referrer
  post "/admin/users/:id/clear_referrer", to: "admin#clear_referrer", as: :admin_clear_referrer
  post "/admin/users/:id/clear_main_device", to: "admin#clear_main_device", as: :admin_clear_main_device
  post "/admin/users/:id/set_out", to: "admin#set_out", as: :admin_set_out
  post "/admin/users/:id/set_active", to: "admin#set_active", as: :admin_set_active
  post "/admin/users/:id/add_cosmetic", to: "admin#add_cosmetic", as: :admin_add_cosmetic
  delete "/admin/users/:id/remove_cosmetic", to: "admin#remove_cosmetic", as: :admin_remove_cosmetic
  post "/admin/users/:id/set_banned", to: "admin#set_banned", as: :admin_set_banned
  post "/admin/users/:id/toggle_fraud_team", to: "admin#toggle_fraud_team", as: :admin_toggle_fraud_team
  delete "/admin/users/:id/delete", to: "admin#destroy_user", as: :admin_destroy_user
  post "/admin/projects/:id/update_fraud_status", to: "admin#update_fraud_status", as: :admin_update_fraud_status
  get "/review", to: "review#index", as: :review
  get "/review/projects/:id", to: "review#show", as: :review_project
  patch "/review/projects/:id/status", to: "review#update_status", as: :review_project_status
  post "/review/projects/:id/submit_review", to: "review#submit_review", as: :review_submit_review
  delete "/review/projects/:id/remove_video", to: "review#remove_video", as: :review_remove_video
  get "/fraud", to: "greg#index", as: :fraud
  get "/fraud/projects/:id", to: "greg#show", as: :fraud_project
  post "/fraud/projects/:id/fraud_status", to: "greg#update_fraud_status", as: :fraud_update_fraud_status
  get "/admin/flipper", to: "admin/flipper#index", as: :admin_flipper
  post "/admin/refresh-hackatime-cache", to: "admin#refresh_hackatime_cache", as: :admin_refresh_hackatime_cache

  # Admin cosmetics management
  namespace :admin do
    resources :cosmetics, only: [:index, :show, :new, :create, :edit, :update, :destroy]
    resources :physical_items, only: [:index, :show, :new, :create, :edit, :update, :destroy]
  end

  # Super admin constraint for monitoring tools
  super_admin_constraint = lambda { |request|
    if request.session[:user_id]
      user = User.find_by(id: request.session[:user_id])
      user&.super_admin?
    else
      false
    end
  }
  
  # Mount monitoring dashboards (super admins only)
  mount Flipper::UI.app(Flipper) => "/admin/flipper/ui", :constraints => super_admin_constraint
  mount MissionControl::Jobs::Engine, at: "/admin/jobs", :constraints => super_admin_constraint
  mount PgHero::Engine, at: "/admin/pghero", :constraints => super_admin_constraint
  
  # Mount health check endpoints (accessible to all - for uptime monitoring)
  health_check_routes

  resource :address, only: [ :show, :new, :create, :edit, :update ]
  resource :chambers, controller: "addresses", only: [ :show, :new, :create, :edit, :update ]

  # Meeple API endpoints
  get "/meeple/current_color", to: "meeple#current_color"
  get "/meeple/asset_paths", to: "meeple#asset_paths"

  # Admin key verification
  post "/verify_admin_key", to: "home#verify_admin_key"
  post "/set_rank", to: "home#set_rank"

  # API endpoints
  get "/api/project_hours/:id", to: "projects#hours"

  # Submit API endpoints
  post "/api/submit/authorize", to: "submit_api#authorize"
  get "/api/submit/status/:auth_id", to: "submit_api#status"

  # Identity verification
  get "/check_identity", to: "projects#check_identity"
  post "/process_identity_and_address", to: "projects#process_identity_and_address"
  post "/set_shipping_name", to: "projects#set_shipping_name"
  post "/store_idv_rec", to: "projects#store_idv_rec"

  # Identity verification callback

  # Countdown timer page
  get "/countdown", to: "countdown#index"
  get "/castle", to: "castle#index", as: :castle
  get "/identity_verification_callback", to: "sessions#identity_verification_callback"

  # Slack webhook endpoints
  post "/slack/events", to: "slack#events"



  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
