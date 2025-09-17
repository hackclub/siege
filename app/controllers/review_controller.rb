class ReviewController < ApplicationController
  before_action :require_review_access
  before_action :set_project, only: [ :show, :update_status ]

  def index
    @projects = Project.visible_to_user(current_user).includes(:user)

    # Default to showing only submitted projects unless status is explicitly specified
    if params[:status].present?
      @projects = @projects.where(status: params[:status])
    else
      @projects = @projects.where(status: "submitted")
    end

    # Filter by name if provided
    if params[:name].present?
      escaped_name = ActiveRecord::Base.connection.quote_string(params[:name])
      @projects = @projects.where("name ILIKE ?", "%#{escaped_name}%")
    end

    # Filter by owner if provided
    if params[:owner].present?
      escaped_owner = ActiveRecord::Base.connection.quote_string(params[:owner])
      @projects = @projects.joins(:user).where("users.name ILIKE ?", "%#{escaped_owner}%")
    end

    # Filter by week if provided
    if params[:week].present?
      week_number = params[:week].to_i
      week_range = helpers.week_date_range(week_number)
      if week_range
        week_start_date = Date.parse(week_range[0])
        week_end_date = Date.parse(week_range[1])
        @projects = @projects.where(created_at: week_start_date.beginning_of_day..week_end_date.end_of_day)
      end
    end

    # Sort based on sort parameter
    case params[:sort]
    when "oldest"
      @projects = @projects.order(created_at: :asc)
    when "newest"
      @projects = @projects.order(created_at: :desc)
    when "most_hours"
      # Join with hackatime_projects and sum up the estimated hours
      # For now, we'll use the count of hackatime projects as a proxy
      @projects = @projects.left_joins("LEFT JOIN jsonb_array_elements_text(projects.hackatime_projects) AS hp(value) ON true")
                           .group("projects.id")
                           .order("COUNT(hp.value) DESC, projects.created_at DESC")
    when "least_hours"
      @projects = @projects.left_joins("LEFT JOIN jsonb_array_elements_text(projects.hackatime_projects) AS hp(value) ON true")
                           .group("projects.id")
                           .order("COUNT(hp.value) ASC, projects.created_at DESC")
    else
      # Default to newest
      @projects = @projects.order(created_at: :desc)
    end

    # Decorate projects for view helpers
    @projects = @projects.decorate

    # Get unique users and statuses for filter dropdowns
    @users = User.joins(:projects).select(:id, :name).distinct.order(:name)
    @statuses = Project.distinct.pluck(:status).compact.sort

    # Get available weeks for filter dropdown
    @available_weeks = (1..helpers.current_week_number).to_a.reverse

    # Generate leaderboard for review actions this week
    @leaderboard_week = params[:leaderboard_week].present? ? params[:leaderboard_week].to_i : helpers.current_week_number
    @review_leaderboard = generate_review_leaderboard(@leaderboard_week)
  end

  def show
    # Detailed view of a single project for review
    @project = @project.decorate
  end

  def update_status
    new_status = params[:new_status]
    message = params[:message]

    unless %w[building submitted pending_voting finished].include?(new_status)
      redirect_to review_project_path(@project), alert: "Invalid status"
      return
    end

    if @project.update_status!(new_status, current_user, message)
      redirect_to review_project_path(@project), notice: "Project status updated successfully"
    else
      redirect_to review_project_path(@project), alert: "Failed to update project status"
    end
  end

  def update_stonemason_feedback
    @project = Project.find(params[:id])
    
    # Check if project is hidden and user is not super admin
    if @project.hidden? && !current_user&.super_admin?
      render json: { success: false, error: "Project not found" }
      return
    end
    
    stonemason_feedback = params[:stonemason_feedback]
    
    # Skip screenshot validation when updating stonemason feedback
    @project.skip_screenshot_validation!
    
    if @project.update(stonemason_feedback: stonemason_feedback)
      # Send Slack notification
      SlackNotificationService.new.send_stonemason_feedback_notification(@project)
      
      render json: { 
        success: true, 
        message: "Stonemason feedback updated for #{@project.user.name}'s project"
      }
    else
      render json: { success: false, error: "Failed to update stonemason feedback" }
    end
  rescue => e
    render json: { success: false, error: "Error updating stonemason feedback: #{e.message}" }
  end

  private

  def generate_review_leaderboard(week_number)
    week_range = helpers.week_date_range(week_number)
    return [] unless week_range
    
    week_start_date = Date.parse(week_range[0]).beginning_of_day
    week_end_date = Date.parse(week_range[1]).end_of_day

    # Get all users who have made review-related audit log entries in the specified week
    review_actions = []
    
    User.where.not(audit_logs: []).find_each do |user|
      user_review_count = user.audit_logs.count do |log|
        log_time = Time.parse(log["timestamp"]) rescue nil
        next false unless log_time
        
        time_in_range = log_time >= week_start_date && log_time <= week_end_date
        review_action = log["action"] == "Project reviewed" || 
                       log["action"] == "Project status updated" ||
                       log["action"] == "Stonemason feedback updated"
        
        time_in_range && review_action
      end
      
      if user_review_count > 0
        review_actions << {
          user: user,
          count: user_review_count
        }
      end
    end
    
    review_actions.sort_by { |entry| -entry[:count] }.take(10)
  end

  def set_project
    @project = Project.find(params[:id])
    
    # Check if project is hidden and user is not super admin
    if @project.hidden? && !current_user&.super_admin?
      redirect_to review_index_path, alert: "Project not found."
    end
  end

  def require_review_access
    unless current_user&.viewer? || current_user&.admin? || current_user&.super_admin?
      redirect_to keep_path, alert: "Access denied. Viewer privileges required."
    end
  end
end
