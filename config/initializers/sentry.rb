Sentry.init do |config|
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn)
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  
  # Set traces_sample_rate to 1.0 to capture 100%
  # of transactions for tracing.
  # We recommend adjusting this value in production
  config.traces_sample_rate = 0.1
  
  # Set profiles_sample_rate to profile 10% of sampled transactions.
  config.profiles_sample_rate = 0.1
  
  config.environment = Rails.env
  config.enabled_environments = %w[production]
end
