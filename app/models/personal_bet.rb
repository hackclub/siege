class PersonalBet < ApplicationRecord
  belongs_to :user
  
  # Calculate current hours for this personal bet
  # Only counts hours from Siege projects with attached hackatime_projects
  def current_hours
    week_range = ApplicationController.helpers.week_date_range(week)
    return 0 unless week_range
    
    # Get user's Siege projects for this week
    user_projects = user.projects.where("created_at >= ? AND created_at <= ?", week_range[0], week_range[1])
    
    total_seconds = 0
    user_projects.each do |project|
      range = project.effective_time_range
      next unless range && range[0] && range[1]
      
      projs = ApplicationController.helpers.hackatime_projects_for_user(user, *range)
      
      project.hackatime_projects.each do |project_name|
        match = projs.find { |p| p["name"].to_s == project_name.to_s }
        total_seconds += match&.dig("total_seconds") || 0
      end
    end
    
    (total_seconds / 3600.0).round(1)
  end
  
  # Check if goal has been reached
  def goal_reached?
    current_hours >= hours_goal
  end
end
