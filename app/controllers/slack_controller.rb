class SlackController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :require_authentication

  def events
    # Handle Slack URL verification challenge
    if params[:challenge]
      render json: { challenge: params[:challenge] }
      return
    end

    # Handle event callbacks
    event_data = params[:event]
    
    if event_data && event_data[:type] == "message" && event_data[:channel_type] == "im"
      # This is a direct message to the bot
      handle_direct_message(event_data)
    end

    render json: { status: "ok" }
  rescue => e
    Rails.logger.error "Slack webhook error: #{e.message}"
    render json: { error: "Internal server error" }, status: 500
  end

  private

  def handle_direct_message(event_data)
    user_slack_id = event_data[:user]
    message_text = event_data[:text]

    # Ignore bot messages and messages without text
    return if event_data[:bot_id] || message_text.blank?

    # Handle the reply using our notification service
    SlackNotificationService.new.handle_reply_message(user_slack_id, message_text)
  rescue => e
    Rails.logger.error "Failed to handle direct message from #{user_slack_id}: #{e.message}"
  end
end
