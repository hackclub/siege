class RefreshHackatimeCacheJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[RefreshHackatimeCache] Starting cache refresh for active users"
    
    active_users = User.where("updated_at > ?", 24.hours.ago)
    Rails.logger.info "[RefreshHackatimeCache] Found #{active_users.count} active users"
    
    active_users.find_each do |user|
      next unless user.slack_id
      
      today = Date.current.strftime("%Y-%m-%d")
      tomorrow = (Date.current + 1).strftime("%Y-%m-%d")
      
      week_range = ApplicationController.helpers.week_date_range(ApplicationController.helpers.current_week_number)
      next unless week_range
      
      begin
        ApplicationController.helpers.hackatime_projects_for_user(user, today, tomorrow)
        
        ApplicationController.helpers.hackatime_projects_for_user(user, week_range[0], week_range[1])
        
        Rails.logger.info "[RefreshHackatimeCache] Refreshed cache for user #{user.name} (#{user.slack_id})"
      rescue => e
        Rails.logger.error "[RefreshHackatimeCache] Error refreshing cache for user #{user.name}: #{e.message}"
      end
    end
    
    Rails.logger.info "[RefreshHackatimeCache] Completed cache refresh"
  end
end
