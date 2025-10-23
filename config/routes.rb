Rails.application.routes.draw do
  # Armory routes (primary routes using /armory URL structure)
  get "/armory", to: "projects#index", as: :projects
  get "/armory/new", to: "projects#new", as: :new_project
  post "/armory", to: "projects#create"
  get "/armory/explore", to: "projects#explore", as: :explore_projects
  get "/armory/:id", to: "projects#show", as: :project
  get "/armory/:id/edit", to: "projects#edit", as: :edit_project
  patch "/armory/:id", to: "projects#update"
  put "/armory/:id", to: "projects#update"
  delete "/armory/:id", to: "projects#destroy"
  post "/armory/:id/submit", to: "projects#submit", as: :submit_project
  patch "/armory/:id/update_status", to: "projects#update_status", as: :update_status_project
  
  # Redirects from old /projects URLs to /armory equivalents
  get "/projects", to: redirect("/armory")
  get "/projects/new", to: redirect("/armory/new")
  get "/projects/explore", to: redirect("/armory/explore")
  get "/projects/:id", to: redirect { |params, _| "/armory/#{params[:id]}" }
  get "/projects/:id/edit", to: redirect { |params, _| "/armory/#{params[:id]}/edit" }
  
  root "sessions#new"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  
  # Health check endpoints
  get "health" => "health_check/health_check#index", as: :health_check
  get "health/full" => "health_check/health_check#index", as: :health_check_full

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
  get "/great-hall/reset-ballot", to: "great_hall#reset_ballot", as: :great_hall_reset_ballot
  get "/market", to: "market#index", as: :market
  post "/market/purchase", to: "market#purchase", as: :market_purchase
  get "/market/mercenary_price", to: "market#mercenary_price", as: :market_mercenary_price
  get "/market/time_travelling_mercenary_data", to: "market#time_travelling_mercenary_data", as: :market_time_travelling_mercenary_data
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
  get "/admin/dashboard", to: "admin#dashboard", as: :admin_dashboard
  get "/admin/projects", to: "admin#projects", as: :admin_projects
  get "/admin/users", to: "admin#users", as: :admin_users
  get "/admin/ballots", to: "admin#ballots", as: :admin_ballots
  get "/admin/referrals", to: "admin#referrals", as: :admin_referrals
  get "/admin/weekly-overview", to: "admin#weekly_overview", as: :admin_weekly_overview
  get "/admin/analytics", to: "admin#analytics", as: :admin_analytics
  
  # Mystereeple management routes
  get "/admin/mystereeple", to: "admin/mystereeple#index", as: :admin_mystereeple
  get "/admin/mystereeple/windows", to: "admin/mystereeple#windows", as: :admin_mystereeple_windows
  patch "/admin/mystereeple/windows/:id/update_days", to: "admin/mystereeple#update_window_days", as: :admin_mystereeple_update_window_days
  patch "/admin/mystereeple/windows/:id/toggle", to: "admin/mystereeple#toggle_window", as: :admin_mystereeple_toggle_window
  
  get "/admin/mystereeple/bets", to: "admin#bets", as: :admin_bets
  post "/admin/mystereeple/bets/:id/refund", to: "admin#refund_bet", as: :admin_refund_bet
  post "/admin/mystereeple/bets/:id/payout", to: "admin#payout_bet", as: :admin_payout_bet
  delete "/admin/mystereeple/bets/:id", to: "admin#delete_bet", as: :admin_delete_bet
  
  # YSWS Review routes (for reviewers)
  get "/ysws-review", to: "ysws_review#index", as: :ysws_review
  get "/ysws-review/:week/:user_id", to: "ysws_review#show", as: :ysws_review_user
  get "/admin/shop-purchases", to: "admin#shop_purchases", as: :admin_shop_purchases
  get "/admin/shop-purchases/:id", to: "admin#shop_purchase_details", as: :admin_shop_purchase_details
  get "/admin/weekly-overview/:week/:user_id", to: "admin#weekly_overview_user", as: :admin_weekly_overview_user
  get "/admin/projects/:project_id/github-commits", to: "admin#github_commits", as: :admin_github_commits
  patch "/admin/shop-purchases/:id/fulfillment", to: "admin#update_purchase_fulfillment", as: :admin_update_purchase_fulfillment
  delete "/admin/shop-purchases/:id", to: "admin#delete_shop_purchase", as: :admin_delete_shop_purchase
  post "/admin/shop-purchases/:id/refund", to: "admin#refund_shop_purchase", as: :admin_refund_shop_purchase
  post "/admin/weekly-overview/:week/:user_id/submit_to_airtable", to: "admin#submit_to_airtable", as: :admin_submit_to_airtable
  post "/admin/weekly-overview/:week/:user_id/update_coins", to: "admin#update_user_coins", as: :admin_update_user_coins
  post "/admin/weekly-overview/:week/:user_id/save_multiplier", to: "admin#save_reviewer_multiplier", as: :admin_save_reviewer_multiplier
  post "/admin/weekly-overview/:week/:user_id/update_arbitrary_offset", to: "admin#update_arbitrary_offset", as: :admin_update_arbitrary_offset
  get "/admin/weekly-overview/:week/:user_id/user_week_data", to: "admin#get_user_week_data", as: :admin_get_user_week_data
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
  post "/admin/shop_purchases/:id/mark_time_traveller_used", to: "admin#mark_time_traveller_used", as: :admin_mark_time_traveller_used
  post "/admin/users/:id/set_out", to: "admin#set_out", as: :admin_set_out
  post "/admin/users/:id/set_active", to: "admin#set_active", as: :admin_set_active
  post "/admin/users/bulk_set_out", to: "admin#bulk_set_out", as: :admin_bulk_set_out
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
  post "/admin/clear-github-cache", to: "admin#clear_github_cache", as: :admin_clear_github_cache

  # Admin cosmetics management
  namespace :admin do
    resources :cosmetics, only: [:index, :show, :new, :create, :edit, :update, :destroy]
    resources :physical_items, only: [:index, :show, :new, :create, :edit, :update, :destroy]
    resources :mystereeple_shop_items, only: [:index, :show, :new, :create, :edit, :update, :destroy]
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
  mount Flipper::UI.app(Flipper) => "/admin/flipper/ui", constraints: super_admin_constraint
  mount MissionControl::Jobs::Engine, at: "/admin/jobs", constraints: super_admin_constraint
  mount PgHero::Engine, at: "/admin/pghero", constraints: super_admin_constraint
  mount Blazer::Engine, at: "/admin/blazer", constraints: super_admin_constraint

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

  # Public Beta API endpoints
  namespace :api do
    get "public-beta", to: "public_beta#index"
    get "public-beta/projects", to: "public_beta#projects"
    get "public-beta/project/:id", to: "public_beta#project"
    get "public-beta/user/:id_or_slack_id", to: "public_beta#user"
    get "public-beta/shop", to: "public_beta#shop"
    get "public-beta/leaderboard", to: "public_beta#leaderboard"
  end

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
  get "/catacombs", to: "catacombs#index", as: :catacombs
  get "/catacombs/last_week_hours", to: "catacombs#last_week_hours"
  post "/catacombs/place_personal_bet", to: "catacombs#place_personal_bet"
  post "/catacombs/place_global_bet", to: "catacombs#place_global_bet"
  post "/catacombs/collect_personal_bet", to: "catacombs#collect_personal_bet"
  post "/catacombs/collect_global_bet", to: "catacombs#collect_global_bet"
  get "/catacombs/current_progress", to: "catacombs#current_progress"
  get "/catacombs/shop_items", to: "catacombs#shop_items"
  post "/catacombs/purchase_shop_item", to: "catacombs#purchase_shop_item"
  post "/catacombs/log_runes", to: "catacombs#log_runes"
  get "/identity_verification_callback", to: "sessions#identity_verification_callback"

  # Slack webhook endpoints
  post "/slack/events", to: "slack#events"



  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
