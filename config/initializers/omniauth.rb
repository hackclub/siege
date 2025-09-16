slack_creds = Rails.application.credentials.slack
base_url    = Rails.application.credentials.dig(Rails.env.to_sym, :base_url)

Rails.logger.info "Slack OAuth Configuration:"
Rails.logger.info "  Environment: #{Rails.env}"
Rails.logger.info "  Slack creds present: #{slack_creds.present?}"
Rails.logger.info "  Base URL: #{base_url}"
Rails.logger.info "  Client ID present: #{slack_creds&.dig(:client_id).present?}"
Rails.logger.info "  Client Secret present: #{slack_creds&.dig(:client_secret).present?}"
Rails.logger.info "  Team ID present: #{slack_creds&.dig(:team_id).present?}"

if slack_creds.present? && slack_creds[:client_id] && slack_creds[:client_secret] && slack_creds[:team_id] && base_url
  Rails.logger.info "Configuring Slack OAuth with redirect URI: #{base_url}/auth/slack_openid/callback"
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :slack_openid,
             slack_creds[:client_id],
             slack_creds[:client_secret],
             {
               scope: "openid,profile,email",
               redirect_uri: "#{base_url}/auth/slack_openid/callback",
               team: slack_creds[:team_id] # Only let people in the Hack Club Slack log in
             }
  end
else
  Rails.logger.error "Slack OAuth not configured - missing required credentials or base_url"
end

# Enable OmniAuth logging in all environments for debugging
OmniAuth.config.logger = Rails.logger

OmniAuth.config.on_failure = proc { |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
}
