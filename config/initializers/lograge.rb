Rails.application.configure do
  config.lograge.enabled = true
  
  # Include additional data in logs
  config.lograge.custom_options = lambda do |event|
    {
      time: event.time,
      user_id: event.payload[:user_id],
      params: event.payload[:params]&.except('controller', 'action', 'format', 'authenticity_token')
    }
  end
  
  # Use JSON formatter for structured logs
  config.lograge.formatter = Lograge::Formatters::Json.new
end
