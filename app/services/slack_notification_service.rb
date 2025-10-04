class SlackNotificationService
  REPLY_CHANNEL_ID = "C09FBH34MFY"

  def initialize
    @client = Slack::Web::Client.new(token: Rails.application.credentials.slack[:bot_token])
  end



  def send_reviewer_feedback_notification(project)
    return unless project.reviewer_feedback.present? && project.user.slack_id.present?

    coin_value = project.coin_value || 0
    message = "Woah, you're rich! You just got #{coin_value} :siege-coin: for your #{project.name} project. Here's what the reviewer had to say: #{project.reviewer_feedback}"

    send_direct_message(project.user.slack_id, message)
  rescue => e
    Rails.logger.error "Failed to send reviewer feedback notification for project #{project.id}: #{e.message}"
  end

  def send_review_notification(project, review_status, feedback_changed, video_changed = false, reviewer = nil, include_reviewer_handle = false)
    return unless project.user.slack_id.present?
    
    # Get reviewer handle for mention if requested
    reviewer_mention = "A stonemason"
    if include_reviewer_handle && reviewer&.slack_id.present?
      reviewer_mention = "<@#{reviewer.slack_id}>"
    end
    
    # Check if there's video content
    video_text = video_changed && project.reviewer_video.attached? ? " 📹 They also left you a video review!" : ""
    
    case review_status
    when "reject"
      # Always send cracks in wall message for rejections
      message = "#{reviewer_mention} checked out your #{project.name} project and there were a few cracks in the walls. Here's what they said: #{project.stonemason_feedback}#{video_text}"
      send_direct_message(project.user.slack_id, message)
    when "add_comment"
      # Only send message if feedback was updated or video was added
      if (feedback_changed && project.stonemason_feedback.present?) || video_changed
        feedback_part = project.stonemason_feedback.present? ? ": #{project.stonemason_feedback}" : ""
        message = "#{reviewer_mention} checked out your #{project.name} project#{feedback_part}#{video_text}"
        send_direct_message(project.user.slack_id, message)
      end
    when "accept"
      # Send approval message - with feedback if updated, generic if not
      if feedback_changed && project.stonemason_feedback.present?
        message = "Great news! #{reviewer_mention} approved your #{project.name} project! Here's what they said: #{project.stonemason_feedback}#{video_text}"
      else
        message = "Great news! #{reviewer_mention} approved your #{project.name} project!#{video_text}"
      end
      send_direct_message(project.user.slack_id, message)
      
      # Also send pending voting notification for approved projects
      message = "The diplomats have been sent out to preach about #{project.name}! They should be back in a few days to report how it went..."
      send_direct_message(project.user.slack_id, message)
    when "accept_not_following_theme"
      # Send approval message for non-themed projects
      if feedback_changed && project.stonemason_feedback.present?
        message = "Good news! #{reviewer_mention} approved your #{project.name} project! Here's what they said: #{project.stonemason_feedback}#{video_text}"
      else
        message = "Good news! #{reviewer_mention} approved your #{project.name} project!#{video_text}"
      end
      send_direct_message(project.user.slack_id, message)
      
      # Send waiting for review notification
      message = "Because your project didn't follow the theme, it'll skip voting and go directly to review."
      send_direct_message(project.user.slack_id, message)
    end
  rescue => e
    Rails.logger.error "Failed to send review notification for project #{project.id}: #{e.message}"
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
