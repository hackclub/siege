class YswsReviewController < ApplicationController
  before_action :require_reviewer
  
  def index
    # Reuse the exact same logic as admin#weekly_overview
    # This is essentially a delegated call to the admin weekly overview functionality
    
    # Find all weeks that have projects
    project_weeks = Project.includes(:user).map do |project|
      view_context.week_number_for_date(project.created_at)
    end.uniq.compact.sort.reverse

    if project_weeks.empty?
      current_week = [ view_context.current_week_number, 1 ].max
      @available_weeks = [ current_week ]
    else
      @available_weeks = project_weeks
    end

    @selected_week = if params[:week].present?
      params[:week].to_i
    else
      current_week = view_context.current_week_number
      previous_week = current_week - 1
      @available_weeks.include?(previous_week) ? previous_week : (@available_weeks.first || 1)
    end

    week_range = view_context.week_date_range(@selected_week)

    if week_range
      week_start_date = Date.parse(week_range[0])
      week_end_date = Date.parse(week_range[1])

      @users = User.all.includes(:meeple, :address)

      # Apply user search filter if provided (search name, display_name, and slack_id)
      if params[:user_search].present?
        escaped_search = ActiveRecord::Base.connection.quote_string(params[:user_search])
        @users = @users.where("users.name ILIKE ? OR users.display_name ILIKE ? OR users.slack_id ILIKE ?", "%#{escaped_search}%", "%#{escaped_search}%", "%#{escaped_search}%")
      end

      if params[:user_status].present? && %w[new working out banned all].include?(params[:user_status])
        @user_status_filter = params[:user_status]
        @users = @users.where(status: @user_status_filter) if @user_status_filter != "all"
      else
        @user_status_filter = "all"
      end

      @show_hidden = params[:show_hidden] == "1"
      
      week_projects = if @show_hidden
        Project.where(user_id: @users.pluck(:id), created_at: week_start_date.beginning_of_day..week_end_date.end_of_day).includes(:user)
      else
        Project.visible.where(user_id: @users.pluck(:id), created_at: week_start_date.beginning_of_day..week_end_date.end_of_day).includes(:user)
      end

      # Apply project search filter if provided
      if params[:project_search].present?
        escaped_search = ActiveRecord::Base.connection.quote_string(params[:project_search])
        week_projects = week_projects.where("projects.name ILIKE ?", "%#{escaped_search}%")
      end

      projects_by_user = week_projects.group_by(&:user_id)

      vote_averages = {}
      current_week = view_context.current_week_number
      week_is_past = @selected_week < current_week
      
      if week_is_past
        project_ids = week_projects.pluck(:id)
        if project_ids.any?
          vote_data = Vote.joins(:ballot).where(project_id: project_ids, voted: true).group(:project_id).average(:star_count)
          vote_averages = vote_data.transform_values { |avg| avg.to_f.round(2) }
        end
      end

      @user_data = {}

      @users.each do |user|
        project = projects_by_user[user.id]&.first
        time_seconds = project ? view_context.user_hackatime_time_for_projects(user, [ project ], week_range) : 0
        average_score = project ? vote_averages[project.id] : nil
        
        user_week = UserWeek.find_by(user: user, week: @selected_week)
        mercenary_count = user_week&.mercenary_offset || 0
        arbitrary_offset = user_week&.arbitrary_offset || 0
        total_offset = user_week&.total_offset || 0
        effective_goal = user_week&.effective_hour_goal || (@selected_week == 5 ? 9 : 10)

        @user_data[user.id] = {
          user: user,
          project: project,
          time_seconds: time_seconds,
          time_readable: view_context.format_time_from_seconds(time_seconds),
          average_score: average_score,
          fraud_status: project&.fraud_status,
          fraud_reasoning: project&.fraud_reasoning,
          mercenary_count: mercenary_count,
          arbitrary_offset: arbitrary_offset,
          total_offset: total_offset,
          effective_hour_goal: effective_goal,
          user_week: user_week
        }
      end

      @status_filter = params[:status].present? ? params[:status] : "pending_voting_and_waiting"
      status_filter = @status_filter

      @user_data = @user_data.select do |user_id, data|
        case status_filter
        when "no_project" then data[:project].nil?
        when "building", "submitted", "pending_voting", "waiting_for_review", "finished" then data[:project]&.status == status_filter
        when "pending_voting_and_waiting" then data[:project]&.status.in?(["pending_voting", "waiting_for_review"])
        when "all" then true
        else data[:project]&.status.in?(["pending_voting", "waiting_for_review"])
        end
      end

      if current_user&.can_access_fraud_dashboard?
        @fraud_status_filter = params[:fraud_status].present? ? params[:fraud_status] : "good_and_unchecked"
        fraud_status_filter = @fraud_status_filter

        @user_data = @user_data.select do |user_id, data|
          case fraud_status_filter
          when "unchecked", "sus", "fraud", "good" then data[:project]&.fraud_status == fraud_status_filter
          when "good_and_unchecked" then data[:project]&.fraud_status.in?(["good", "unchecked"])
          when "all" then true
          else true
          end
        end
      end

      @airtable_status_filter = params[:airtable_status].present? ? params[:airtable_status] : "not_submitted"
      airtable_status_filter = @airtable_status_filter

      @user_data = @user_data.select do |user_id, data|
        case airtable_status_filter
        when "not_submitted" then data[:project].nil? || !data[:project].in_airtable
        when "submitted" then data[:project]&.in_airtable == true
        when "all" then true
        else data[:project].nil? || !data[:project].in_airtable
        end
      end

      @total_users = @user_data.count
      @per_page = 25
      @current_page = (params[:page] || 1).to_i
      @total_pages = (@total_users.to_f / @per_page).ceil

      user_data_array = @user_data.to_a
      start_index = (@current_page - 1) * @per_page
      end_index = start_index + @per_page - 1
      @user_data = user_data_array[start_index..end_index].to_h
    else
      @user_data = {}
      @total_users = 0
      @per_page = 25
      @current_page = 1
      @total_pages = 0
    end
    
    # Calculate Airtable submission leaderboard for the selected week
    if week_range
      week_start_date = Date.parse(week_range[0])
      week_end_date = Date.parse(week_range[1])
      
      # Get all projects submitted to Airtable this week by checking logs
      week_projects_with_logs = Project.where(
        created_at: week_start_date.beginning_of_day..week_end_date.end_of_day,
        in_airtable: true
      ).where("json_array_length(logs) > 0")
      
      # Count Airtable submissions by reviewer
      airtable_submissions = Hash.new(0)
      reviewer_names = {}
      
      week_projects_with_logs.each do |project|
        project.logs.each do |log|
          if log["message"]&.include?("Submitted to Airtable")
            reviewer_id = log["reviewer_id"]
            reviewer_name = log["reviewer_name"]
            if reviewer_id && reviewer_name
              airtable_submissions[reviewer_id] += 1
              reviewer_names[reviewer_id] = reviewer_name
            end
          end
        end
      end
      
      # Sort by submission count (descending) and prepare leaderboard data
      @airtable_leaderboard = airtable_submissions.sort_by { |_, count| -count }.map do |reviewer_id, count|
        {
          reviewer_id: reviewer_id,
          reviewer_name: reviewer_names[reviewer_id],
          submission_count: count
        }
      end
    else
      @airtable_leaderboard = []
    end
    
    @is_ysws_review = true
    render 'admin/weekly_overview'
  end
  
  def show
    # Reuse admin#weekly_overview_user logic
    @selected_week = params[:week].to_i
    @user = User.find(params[:user_id])
    week_range = view_context.week_date_range(@selected_week)

    if week_range
      week_start_date = Date.parse(week_range[0])
      week_end_date = Date.parse(week_range[1])

      @project = @user.projects.where(created_at: week_start_date.beginning_of_day..week_end_date.end_of_day).first
      @time_seconds = @project ? view_context.user_hackatime_time_for_projects(@user, [ @project ], @project.effective_time_range) : 0
      @time_readable = view_context.format_time_from_seconds(@time_seconds)
      @votes = @project ? Vote.joins(:ballot).includes(ballot: :user).where(project: @project).order("ballots.created_at DESC") : []
      
      cast_votes = @votes.where(voted: true)
      @average_score = cast_votes.any? ? cast_votes.average(:star_count).to_f.round(2) : nil
      @raw_hours = (@time_seconds / 3600.0).round(2)
      
      # Use the same coin calculation as admin
      @suggested_coins = calculate_project_coins(@user, @project, @raw_hours, @average_score, @selected_week)
      
      @address = @user.address
      @submitted_to_airtable = @project&.in_airtable? || false
      @week = @selected_week
    else
      redirect_to ysws_review_path, alert: "Invalid week selected."
    end
    
    @is_ysws_review = true
    render 'admin/weekly_overview_user'
  end
  
  private
  
  def require_reviewer
    unless current_user&.can_review?
      redirect_to root_path, alert: "You don't have permission to access this page."
    end
  end
  
  def calculate_project_coins(user, project, hours, voting_bonus, week)
    return 0 unless hours && hours > 0
    
    # Get reviewer multiplier (defaults to 2.0)
    reviewer_bonus = project&.reviewer_multiplier || 2.0
    
    # Ensure voting bonus is at least 1
    voting_bonus = [voting_bonus || 1, 1].max
    
    # Weeks 1-4 use simple formula
    if week <= 4
      return (hours * 2 * reviewer_bonus * voting_bonus).round
    end
    
    # Weeks 5+ depend on user status
    if user.status == "out"
      # Out users use simple formula
      return (hours * 2 * reviewer_bonus * voting_bonus).round
    else
      # Working users use complex formula
      # Get the week's hour goal
      hour_goal = ApplicationController.helpers.effective_hour_goal(user, week)
      
      # Calculate base: 5 * reviewer_bonus * voting_bonus
      base = 5 * reviewer_bonus * voting_bonus
      
      # Calculate bonus for hours past goal
      hours_past_goal = [hours - hour_goal, 0].max
      bonus = hours_past_goal * reviewer_bonus * voting_bonus
      
      return (base + bonus).round
    end
  end
end
