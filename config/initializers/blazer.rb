Blazer.configure do |config|
  config.user_class = "User"
  config.user_method = :current_user
  config.user_name = :name
  config.user_email = :email
  config.user_id = :id

  config.before_action do |controller|
    raise ActionController::RoutingError, "Not Found" unless controller.current_user&.super_admin?
  end

  config.data_sources = {
    "main" => { "url" => ENV["DATABASE_URL"] }
  }

  config.query_timeout = 30
  config.cache_timeout = 5.minutes

  config.smart_variables = true
  config.smart_columns = true
end
