class SyncHackatimeBanStatusJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[SyncHackatimeBanStatus] Starting Hackatime ban status sync"
    
    synced_count = 0
    banned_count = 0
    unbanned_count = 0
    error_count = 0
    
    # Get current week range for API call
    current_week_number = ApplicationController.helpers.current_week_number
    week_range = ApplicationController.helpers.week_date_range(current_week_number)
    
    unless week_range
      Rails.logger.error "[SyncHackatimeBanStatus] Could not get week range"
      return
    end
    
    start_date_str = week_range[0]
    end_date_str = week_range[1]
    
    User.find_each do |user|
      next unless user.slack_id.present?
      
      begin
        # Get Hackatime trust status
        trust_status = get_hackatime_trust_status(user, start_date_str, end_date_str)
        
        if trust_status[:status] == "banned"
          # User is banned on Hackatime
          if user.status != "banned"
            Rails.logger.info "[SyncHackatimeBanStatus] Banning user #{user.id} (#{user.name}) - Hackatime trust value: #{trust_status[:value]}"
            user.update!(status: "banned")
            
            # Add audit log
            user.add_audit_log(
              action: "User auto-banned from Hackatime sync",
              actor: nil,
              details: {
                "hackatime_trust_value" => trust_status[:value],
                "previous_status" => user.status
              }
            )
            
            banned_count += 1
          end
          synced_count += 1
        elsif user.status == "banned" && trust_status[:status] != "banned"
          # User is banned on Siege but NOT banned on Hackatime
          Rails.logger.info "[SyncHackatimeBanStatus] Unbanning user #{user.id} (#{user.name}) - Hackatime trust value: #{trust_status[:value]}"
          user.update!(status: "out")
          
          # Add audit log
          user.add_audit_log(
            action: "User auto-unbanned from Hackatime sync",
            actor: nil,
            details: {
              "hackatime_trust_value" => trust_status[:value],
              "hackatime_status" => trust_status[:status],
              "previous_status" => "banned",
              "new_status" => "out"
            }
          )
          
          unbanned_count += 1
          synced_count += 1
        end
      rescue => e
        Rails.logger.error "[SyncHackatimeBanStatus] Error processing user #{user.id}: #{e.message}"
        error_count += 1
      end
    end
    
    Rails.logger.info "[SyncHackatimeBanStatus] Sync complete: #{synced_count} users checked, #{banned_count} banned, #{unbanned_count} unbanned, #{error_count} errors"
  end
  
  private
  
  def get_hackatime_trust_status(user, start_date_str, end_date_str)
    return { status: "unknown", value: nil } unless user.slack_id.present?
    
    # Get the full cached hackatime stats data using the existing helper
    hackatime_data = ApplicationController.helpers.hackatime_projects_for_user(user, start_date_str, end_date_str) { |data| data }
    
    # Extract trust factor from the cached data
    if hackatime_data.respond_to?(:dig) && hackatime_data.present?
      trust_factor = hackatime_data["trust_factor"]
      
      if trust_factor && trust_factor["trust_value"]
        trust_value = trust_factor["trust_value"]
        
        case trust_value
        when 0
          { status: "neutral", value: trust_value }
        when 1
          { status: "banned", value: trust_value }
        when 2
          { status: "trusted", value: trust_value }
        else
          { status: "unknown", value: trust_value }
        end
      else
        { status: "unknown", value: nil }
      end
    else
      { status: "unknown", value: nil }
    end
  rescue => e
    Rails.logger.error "[SyncHackatimeBanStatus] Failed to get Hackatime trust status for user #{user.id}: #{e.message}"
    { status: "error", value: nil }
  end
end
