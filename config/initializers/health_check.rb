HealthCheck.setup do |config|
  # Checks to run (removed 'cache' since we're using Solid Cache, not Redis)
  config.standard_checks = [ 'database', 'migrations' ]
  
  # Optional checks
  config.full_checks = ['database', 'migrations', 'emailconf']
  
  # Make it accessible at /health
  config.uri = 'health'
end
