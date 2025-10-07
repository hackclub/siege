Blazer.user_class = "User"
Blazer.user_method = "current_user"

# Configure authentication
Blazer.authenticate = proc do |controller|
  # Only allow super admins
  if controller.respond_to?(:current_user) && controller.current_user
    controller.current_user.super_admin?
  else
    false
  end
end

# Configure data sources
Blazer.data_sources = {
  "main" => {
    "url" => ENV["DATABASE_URL"]
  }
}

# Configure timeouts
Blazer.query_timeout = 30
Blazer.cache_timeout = 5.minutes

# Configure checks
Blazer.checks = {
  "error" => ->(check) { check.state == "error" },
  "timing" => ->(check) { check.state == "timing" }
}

# Configure smart variables
Blazer.smart_variables = true

# Configure smart columns
Blazer.smart_columns = true

# Configure smart columns for specific tables
Blazer.smart_columns_settings = {
  "users" => {
    "rank" => { "smart" => true },
    "status" => { "smart" => true }
  },
  "projects" => {
    "status" => { "smart" => true },
    "fraud_status" => { "smart" => true }
  }
}
