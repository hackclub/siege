class UpdateHackatimeDaysJob < ApplicationJob
  queue_as :default

  def perform
    # Process the last 3 weeks
    end_date = Date.current
    start_date = end_date - 21.days
    
    Rails.logger.info "[UpdateHackatimeDays] Processing #{start_date} to #{end_date}"
    
    (start_date..end_date).each do |date|
      process_date(date)
    end
    
    Rails.logger.info "[UpdateHackatimeDays] Completed processing #{(end_date - start_date + 1).to_i} days"
  end
  
  private
  
  def process_date(date)
    date_start = date.strftime("%Y-%m-%d")
    date_end = date.strftime("%Y-%m-%d")
    
    total_hours = 0.0
    user_ids_set = Set.new
    
    # Get all Siege projects (we only count time for projects in the system)
    all_siege_projects = Project.all
    
    # Group projects by user for efficient processing
    projects_by_user = all_siege_projects.group_by(&:user_id)
    
    User.find_each do |user|
      next unless user.slack_id.present?
      
      # Get user's projects
      user_projects = projects_by_user[user.id] || []
      next if user_projects.empty?
      
      begin
        # Get hackatime data for this specific day
        projs = ApplicationController.helpers.hackatime_projects_for_user(user, date_start, date_end)
        next if projs.empty?
        
        # Calculate total time for this user on this day for Siege projects only
        user_day_seconds = 0
        
        user_projects.each do |project|
          next unless project.hackatime_projects&.any?
          
          project.hackatime_projects.each do |project_name|
            match = projs.find { |p| p["name"].to_s == project_name.to_s }
            if match
              project_seconds = match.dig("total_seconds") || 0
              user_day_seconds += project_seconds
            end
          end
        end
        
        # Only count user if they logged time on a Siege project this day
        if user_day_seconds > 0
          user_hours = user_day_seconds / 3600.0
          total_hours += user_hours
          user_ids_set.add(user.id)
        end
        
      rescue => e
        Rails.logger.error "[UpdateHackatimeDays] Error processing user #{user.id} for date #{date}: #{e.message}"
        next
      end
      
      # Small delay to avoid rate limiting
      sleep 0.1
    end
    
    # Create or update HackatimeDay record
    hackatime_day = HackatimeDay.find_or_initialize_by(date: date)
    hackatime_day.total_hours = total_hours.round(2)
    hackatime_day.user_ids = user_ids_set.to_a
    
    if hackatime_day.save
      Rails.logger.info "[UpdateHackatimeDays] #{date}: #{total_hours.round(2)}h, #{user_ids_set.size} users"
    else
      Rails.logger.error "[UpdateHackatimeDays] Failed to save #{date}: #{hackatime_day.errors.full_messages.join(', ')}"
    end
  rescue => e
    Rails.logger.error "[UpdateHackatimeDays] Error processing date #{date}: #{e.message}"
  end
end
