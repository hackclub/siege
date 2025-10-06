Rails.application.configure do
  # Configure Mission Control Jobs authentication
  config.mission_control.jobs.base_controller_class = "AdminController"
end
