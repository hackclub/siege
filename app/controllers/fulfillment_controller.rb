class FulfillmentController < ApplicationController
  before_action :require_admin

  def index
    @weeks = (1..15).to_a.reverse
    @selected_weeks = if params[:weeks].present?
      params[:weeks].split(',').map(&:to_i)
    else
      []
    end
    
    if @selected_weeks.any?
      @fulfillment_data = fetch_fulfillment_data(@selected_weeks)
      @total_user_weeks = UserWeek.where(week: @selected_weeks).count
      @user_weeks_with_address = UserWeek.where(week: @selected_weeks).includes(:user).select { |uw| uw.user.address.present? }.count
    else
      @fulfillment_data = []
      @total_user_weeks = 0
      @user_weeks_with_address = 0
    end

    respond_to do |format|
      format.html
      format.csv do
        send_data generate_csv(@fulfillment_data), 
                  filename: "fulfillment-weeks-#{@selected_weeks.join('-')}-#{Date.current}.csv",
                  type: 'text/csv'
      end
    end
  end

  private

  def require_admin
    unless current_user&.admin? || current_user&.super_admin?
      redirect_to root_path, alert: "Access denied"
    end
  end

  def fetch_fulfillment_data(weeks)
    # Load all user_weeks for the selected weeks
    user_weeks = UserWeek.where(week: weeks).to_a
    
    # Preload all users with addresses in one query
    user_ids = user_weeks.map(&:user_id).uniq
    users_by_id = User.where(id: user_ids).includes(:address).index_by(&:id)
    
    # Group user_weeks by week for batch processing
    weeks_data = {}
    weeks.each do |week|
      time_range = ApplicationController.helpers.week_date_range(week)
      next unless time_range
      
      weeks_data[week] = {
        start: Date.parse(time_range[0]).beginning_of_day,
        end: Date.parse(time_range[1]).end_of_day
      }
    end
    
    # Preload all projects for all users in the selected weeks
    all_week_starts = weeks_data.values.map { |wd| wd[:start] }
    all_week_ends = weeks_data.values.map { |wd| wd[:end] }
    overall_start = all_week_starts.min
    overall_end = all_week_ends.max
    
    projects_by_user_and_week = {}
    if overall_start && overall_end
      Project.where(user_id: user_ids, created_at: overall_start..overall_end)
             .each do |project|
        weeks.each do |week|
          week_data = weeks_data[week]
          next unless week_data
          
          if project.created_at >= week_data[:start] && project.created_at <= week_data[:end]
            key = [project.user_id, week]
            projects_by_user_and_week[key] ||= []
            projects_by_user_and_week[key] << project
          end
        end
      end
    end
    
    # Group by user to create one row per user
    users_data = {}
    
    # Cache Hackatime API calls by user and time range
    hackatime_cache = {}
    
    user_weeks.each do |user_week|
      user = users_by_id[user_week.user_id]
      next unless user
      
      address = user.address
      
      next unless address.present?
      
      # Initialize user data if not exists
      unless users_data[user.id]
        shipping_name = if address.shipping_name.present?
          address.shipping_name
        else
          "#{address.first_name} #{address.last_name}"
        end
        
        users_data[user.id] = {
          user_id: user.id,
          slack_id: user.slack_id,
          email: user.email,
          name: user.name,
          shipping_name: shipping_name,
          first_name: address.first_name,
          last_name: address.last_name,
          birthday: address.birthday,
          line_one: address.line_one,
          line_two: address.line_two,
          city: address.city,
          state: address.state,
          postcode: address.postcode,
          country: address.country,
          weeks: {}
        }
      end
      
      # Get preloaded projects for this user and week
      week_projects = projects_by_user_and_week[[user.id, user_week.week]] || []
      
      # Calculate actual hours
      total_seconds = 0
      week_projects.each do |project|
        if project.hackatime_projects.present? && project.effective_time_range
          # Cache Hackatime API calls
          cache_key = [user.id, project.effective_time_range]
          projs = hackatime_cache[cache_key] ||= ApplicationController.helpers.hackatime_projects_for_user(
            user,
            *project.effective_time_range
          )
          
          project.hackatime_projects.each do |project_name|
            match = projs.find { |p| p["name"].to_s == project_name.to_s }
            total_seconds += match&.dig("total_seconds") || 0
          end
        end
      end
      
      actual_hours = total_seconds / 3600.0
      effective_goal = user_week.effective_hour_goal
      
      # Store week data
      users_data[user.id][:weeks][user_week.week] = {
        goal: effective_goal,
        hours: actual_hours.round(1),
        met_goal: actual_hours >= effective_goal
      }
    end
    
    # Filter to only users who met at least one goal in the SELECTED weeks
    users_data.values
              .select do |u| 
                u[:weeks].present? && 
                u[:weeks].any? { |week_num, week_data| weeks.include?(week_num) && week_data[:met_goal] == true }
              end
              .sort_by { |u| u[:name] || u[:slack_id] }
  end

  def generate_csv(data)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      # Build header row
      headers = [
        'User ID',
        'Slack ID',
        'Email',
        'Name',
        'Shipping Name',
        'First Name',
        'Last Name',
        'Birthday',
        'Address Line 1',
        'Address Line 2',
        'City',
        'State',
        'Postcode',
        'Country'
      ]
      
      # Add week columns
      (1..15).each do |week|
        headers << "Week #{week} Goal"
        headers << "Week #{week} Hours"
      end
      
      csv << headers
      
      data.each do |user_data|
        row = [
          user_data[:user_id],
          user_data[:slack_id],
          user_data[:email],
          user_data[:name],
          user_data[:shipping_name],
          user_data[:first_name],
          user_data[:last_name],
          user_data[:birthday],
          user_data[:line_one],
          user_data[:line_two],
          user_data[:city],
          user_data[:state],
          user_data[:postcode],
          user_data[:country]
        ]
        
        # Add week data
        (1..15).each do |week|
          week_data = user_data[:weeks][week]
          if week_data
            row << week_data[:goal]
            row << week_data[:hours]
          else
            row << ''
            row << ''
          end
        end
        
        csv << row
      end
    end
  end
end
