class GregController < ApplicationController
  before_action :require_fraud_access

  def index
    @projects = Project.includes(:user)
                      .where(status: [ "submitted", "pending_voting", "finished" ])

    # Default to showing only unchecked projects
    fraud_status_filter = params[:fraud_status].presence || "unchecked"

    # Apply fraud status filter
    if fraud_status_filter != "all"
      @projects = @projects.where(fraud_status: fraud_status_filter)
    end

    # Filter by project name if provided
    if params[:name].present?
      escaped_name = ActiveRecord::Base.connection.quote_string(params[:name])
      @projects = @projects.where("name ILIKE ?", "%#{escaped_name}%")
    end

    # Filter by author if provided
    if params[:author].present?
      escaped_author = ActiveRecord::Base.connection.quote_string(params[:author])
      @projects = @projects.joins(:user).where("users.name ILIKE ?", "%#{escaped_author}%")
    end

    # Filter by week if provided
    if params[:week].present? && params[:week].to_i.to_s == params[:week]
      week_number = params[:week].to_i
      week_range = ApplicationController.helpers.week_date_range(week_number)

      if week_range
        week_start_date = Date.parse(week_range[0])
        week_end_date = Date.parse(week_range[1])
        @projects = @projects.where(created_at: week_start_date.beginning_of_day..week_end_date.end_of_day)
      end
    end

    # Filter by fraud reasoning if provided
    if params[:reasoning].present?
      escaped_reasoning = ActiveRecord::Base.connection.quote_string(params[:reasoning])
      @projects = @projects.where("fraud_reasoning ILIKE ?", "%#{escaped_reasoning}%")
    end

    # Order by creation date (oldest first to show lowest week numbers first)
    @projects = @projects.order(created_at: :asc)

    # Get available options for filters
    @fraud_statuses = %w[unchecked sus fraud good]
    @available_weeks = Project.distinct.pluck(:created_at).map do |created_at|
      ApplicationController.helpers.week_number_for_date(created_at)
    end.uniq.sort.reverse

    # Pagination
    @per_page = 25
    @current_page = (params[:page] || 1).to_i
    @total_count = @projects.count
    @total_pages = (@total_count.to_f / @per_page).ceil

    offset = (@current_page - 1) * @per_page
    @projects = @projects.offset(offset).limit(@per_page)

    # Generate leaderboard for fraud review actions this week
    @leaderboard_week = params[:leaderboard_week].present? ? params[:leaderboard_week].to_i : ApplicationController.helpers.current_week_number
    @fraud_leaderboard = generate_fraud_leaderboard(@leaderboard_week)
  end

  def show
    @project = Project.includes(:user).find(params[:id])

    unless @project.fraud_reviewable?
      redirect_to greg_index_path, alert: "Project is not available for fraud review."
      return
    end

    # Get project details including Hackatime data
    @week_number = ApplicationController.helpers.week_number_for_date(@project.created_at)
    @time_range = @project.effective_time_range

    if @time_range && @time_range[0] && @time_range[1]
      @hackatime_data = ApplicationController.helpers.hackatime_projects_for_user(@project.user, @time_range[0], @time_range[1])
    end

    # Get fraud-specific audit logs
    @fraud_audit_logs = @project.user.audit_logs.select do |log|
      log["action"] == "Project fraud status updated" &&
      log.dig("details", "project_id") == @project.id
    end.reverse

    # Get navigation context (previous/next projects based on current filters)
    @navigation = get_project_navigation(@project, params)
  end

  def update_fraud_status
    @project = Project.find(params[:id])

    unless @project.fraud_reviewable?
      render json: { success: false, error: "Project is not available for fraud review." }
      return
    end

    new_fraud_status = params[:fraud_status]
    new_fraud_reasoning = params[:fraud_reasoning]

    unless %w[unchecked sus fraud good].include?(new_fraud_status)
      render json: { success: false, error: "Invalid fraud status" }
      return
    end

    begin
      @project.update_fraud_status!(new_fraud_status, new_fraud_reasoning, current_user)
      render json: {
        success: true,
        message: "Fraud status updated to #{new_fraud_status.humanize}"
      }
    rescue => e
      Rails.logger.error "Failed to update fraud status: #{e.message}"
      render json: { success: false, error: "Failed to update fraud status" }
    end
  end

  private

  def generate_fraud_leaderboard(week_number)
    week_range = ApplicationController.helpers.week_date_range(week_number)
    return [] unless week_range
    
    week_start_date = Date.parse(week_range[0]).beginning_of_day
    week_end_date = Date.parse(week_range[1]).end_of_day

    # Get all users who have made fraud-related audit log entries in the specified week
    fraud_actions = []
    
    User.where.not(audit_logs: []).find_each do |user|
      user_fraud_count = user.audit_logs.count do |log|
        log_time = Time.parse(log["timestamp"]) rescue nil
        next false unless log_time
        
        time_in_range = log_time >= week_start_date && log_time <= week_end_date
        fraud_action = log["action"] == "Project fraud status updated"
        
        time_in_range && fraud_action
      end
      
      if user_fraud_count > 0
        fraud_actions << {
          user: user,
          count: user_fraud_count
        }
      end
    end
    
    fraud_actions.sort_by { |entry| -entry[:count] }.take(10)
  end

  def require_fraud_access
    unless current_user&.can_access_fraud_dashboard?
      redirect_to keep_path, alert: "Access denied. Fraud team access required."
    end
  end

  def get_project_navigation(current_project, filter_params)
    # Convert params to hash safely
    safe_params = filter_params.respond_to?(:permit) ?
      filter_params.permit(:name, :author, :week, :fraud_status, :reasoning).to_h :
      filter_params.to_h

    # Build the same query as index action to get the filtered list
    projects = Project.includes(:user)
                     .where(status: [ "submitted", "pending_voting", "finished" ])

    # Apply the same filters as index action
    fraud_status_filter = safe_params[:fraud_status].presence || safe_params["fraud_status"].presence || "unchecked"

    if fraud_status_filter != "all"
      projects = projects.where(fraud_status: fraud_status_filter)
    end

    name_param = safe_params[:name] || safe_params["name"]
    if name_param.present?
      escaped_name = ActiveRecord::Base.connection.quote_string(name_param)
      projects = projects.where("name ILIKE ?", "%#{escaped_name}%")
    end

    author_param = safe_params[:author] || safe_params["author"]
    if author_param.present?
      escaped_author = ActiveRecord::Base.connection.quote_string(author_param)
      projects = projects.joins(:user).where("users.name ILIKE ?", "%#{escaped_author}%")
    end

    week_param = safe_params[:week] || safe_params["week"]
    if week_param.present? && week_param.to_i.to_s == week_param
      week_number = week_param.to_i
      week_range = ApplicationController.helpers.week_date_range(week_number)

      if week_range
        week_start_date = Date.parse(week_range[0])
        week_end_date = Date.parse(week_range[1])
        projects = projects.where(created_at: week_start_date.beginning_of_day..week_end_date.end_of_day)
      end
    end

    reasoning_param = safe_params[:reasoning] || safe_params["reasoning"]
    if reasoning_param.present?
      escaped_reasoning = ActiveRecord::Base.connection.quote_string(reasoning_param)
      projects = projects.where("fraud_reasoning ILIKE ?", "%#{escaped_reasoning}%")
    end

    # Order the same way as index
    projects = projects.order(created_at: :desc)

    # Get all project IDs in order
    project_ids = projects.pluck(:id)
    current_index = project_ids.index(current_project.id)

    return {
      previous_project_id: nil,
      next_project_id: nil,
      current_position: nil,
      total_count: 0,
      filter_params: safe_params
    } unless current_index

    # Get previous and next project IDs
    previous_id = current_index > 0 ? project_ids[current_index - 1] : nil
    next_id = current_index < project_ids.length - 1 ? project_ids[current_index + 1] : nil

    {
      previous_project_id: previous_id,
      next_project_id: next_id,
      current_position: current_index + 1,
      total_count: project_ids.length,
      filter_params: safe_params
    }
  end
end
