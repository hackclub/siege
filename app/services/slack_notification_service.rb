class SlackNotificationService
  REPLY_CHANNEL_ID = "C09FBH34MFY"

  def initialize
    @client = Slack::Web::Client.new(token: Rails.application.credentials.slack[:bot_token])
  end

  def send_stonemason_feedback_notification(project)
    return unless project.stonemason_feedback.present? && project.user.slack_id.present?

    message = "A stonemason checked out your #{project.name} project and there were a few cracks in the walls. Here's what they said: #{project.stonemason_feedback}"

    send_direct_message(project.user.slack_id, message)
  rescue => e
    Rails.logger.error "Failed to send stonemason feedback notification for project #{project.id}: #{e.message}"
  end

  def send_reviewer_feedback_notification(project)
    return unless project.reviewer_feedback.present? && project.user.slack_id.present?

    coin_value = project.coin_value || 0
    message = "Woah, you're rich! You just got #{coin_value} :siege-coin: for your #{project.name} project. Here's what the reviewer had to say: #{project.reviewer_feedback}"

    send_direct_message(project.user.slack_id, message)
  rescue => e
    Rails.logger.error "Failed to send reviewer feedback notification for project #{project.id}: #{e.message}"
  end

  def send_pending_voting_notification(project)
    return unless project.user.slack_id.present?

    message = "The diplomats have been sent out to preach about #{project.name}! They should be back in a few days to report how it went..."

    send_direct_message(project.user.slack_id, message)
  rescue => e
    Rails.logger.error "Failed to send pending voting notification for project #{project.id}: #{e.message}"
  end

  def handle_reply_message(user_slack_id, reply_text)
    # Find user by slack_id
    user = User.find_by(slack_id: user_slack_id)
    username = user&.name || "Unknown User"

    # Send message to the specified channel
    channel_message = "Message from #{username}: #{reply_text}"
    
    @client.chat_postMessage(
      channel: REPLY_CHANNEL_ID,
      text: channel_message
    )
  rescue => e
    Rails.logger.error "Failed to handle reply message from user #{user_slack_id}: #{e.message}"
  end

  private

  def send_direct_message(slack_user_id, message)
    return unless slack_user_id.present? && message.present?
    return unless Rails.application.credentials.slack&.dig(:bot_token).present?

    # Open a DM channel with the user
    dm_response = @client.conversations_open(users: slack_user_id)
    channel_id = dm_response.channel.id

    # Send the message
    @client.chat_postMessage(
      channel: channel_id,
      text: message
    )

    Rails.logger.info "Sent Slack notification to user #{slack_user_id}: #{message}"
  rescue Slack::Web::Api::Errors::SlackError => e
    Rails.logger.error "Slack API error sending message to #{slack_user_id}: #{e.message}"
    raise
  rescue => e
    Rails.logger.error "Unexpected error sending Slack message to #{slack_user_id}: #{e.message}"
    raise
  end
end
