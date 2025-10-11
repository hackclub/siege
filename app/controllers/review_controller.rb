class ReviewController < ApplicationController
  before_action :require_review_access
  before_action :set_project, only: [ :show, :update_status, :submit_review, :remove_video ]

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

    # Filter by author name if provided (search name, display_name, and slack_id)
    if params[:author_name].present?
      escaped_name = ActiveRecord::Base.connection.quote_string(params[:author_name])
      @projects = @projects.joins(:user).where("users.name ILIKE ? OR users.display_name ILIKE ? OR users.slack_id ILIKE ?", "%#{escaped_name}%", "%#{escaped_name}%", "%#{escaped_name}%")
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

    unless %w[building submitted pending_voting waiting_for_review finished].include?(new_status)
      redirect_to review_project_path(@project), alert: "Invalid status"
      return
    end

    if @project.update_status!(new_status, current_user, message)
      redirect_to review_project_path(@project), notice: "Project status updated successfully"
    else
      redirect_to review_project_path(@project), alert: "Failed to update project status"
    end
  end

  def submit_review
    review_status = params[:review_status]
    private_notes = params[:private_notes]
    stonemason_feedback = params[:stonemason_feedback]
    reviewer_video = params[:reviewer_video]
    include_reviewer_handle = params[:include_reviewer_handle] == true || params[:include_reviewer_handle] == "true"
    
    unless %w[accept accept_not_following_theme reject add_comment].include?(review_status)
      render json: { success: false, error: "Invalid review status" }
      return
    end
    
    # Store old feedback and video to check for changes
    old_feedback = @project.stonemason_feedback
    old_video_attached = @project.reviewer_video.attached?
    feedback_changed = old_feedback != stonemason_feedback
    video_changed = reviewer_video.present?
    
    # Determine new project status based on review status
    new_project_status = case review_status
    when "accept"
      "pending_voting"
    when "accept_not_following_theme"
      "waiting_for_review"
    when "reject"
      "building"
    when "add_comment"
      @project.status # Keep current status
    end
    
    # Skip screenshot validation
    @project.skip_screenshot_validation!
    
    begin
      # Update stonemason feedback
      @project.update!(stonemason_feedback: stonemason_feedback)
      
      # Attach video if provided
      if reviewer_video.present?
        @project.reviewer_video.attach(reviewer_video)
      end
      
      # Update project status if needed
      if new_project_status != @project.status
        @project.update_status!(new_project_status, current_user, private_notes)
      else
        # If status isn't changing but we have private notes, add them to logs
        if private_notes.present?
          log_entry = {
            timestamp: Time.current.iso8601,
            old_status: @project.status,
            new_status: @project.status,
            reviewer_id: current_user.id,
            reviewer_name: current_user.name,
            message: private_notes
          }
          
          new_logs = @project.logs + [ log_entry ]
          @project.update!(logs: new_logs)
          
          # Add audit log entry
          @project.user.add_audit_log(
            action: "Project review comment added",
            actor: current_user,
            details: {
              "project_name" => @project.name,
              "project_id" => @project.id,
              "message" => private_notes
            }
          )
        end
      end
      
      # Add audit log entry for stonemason feedback if it was updated
      if feedback_changed || video_changed
        @project.user.add_audit_log(
          action: "Review content updated",
          actor: current_user,
          details: {
            "project_name" => @project.name,
            "project_id" => @project.id,
            "stonemason_feedback" => stonemason_feedback,
            "video_attached" => reviewer_video.present?,
            "feedback_changed" => feedback_changed,
            "video_changed" => video_changed
          }
        )
      end
      
      # Send appropriate Slack notification
      SlackNotificationService.new.send_review_notification(@project, review_status, feedback_changed, video_changed, current_user, include_reviewer_handle)
      
      render json: { 
        success: true, 
        message: "Review submitted successfully"
      }
    rescue => e
      render json: { success: false, error: "Error submitting review: #{e.message}" }
    end
  end

  def remove_video
    unless @project.reviewer_video.attached?
      render json: { success: false, error: "No video to remove" }
      return
    end

    begin
      # Remove the video attachment
      @project.reviewer_video.purge
      
      # Add audit log entry
      @project.user.add_audit_log(
        action: "Reviewer video removed",
        actor: current_user,
        details: {
          "project_name" => @project.name,
          "project_id" => @project.id
        }
      )
      
      render json: { 
        success: true, 
        message: "Reviewer video removed successfully"
      }
    rescue => e
      render json: { success: false, error: "Error removing video: #{e.message}" }
    end
  end


  private

  def generate_review_leaderboard(week_number)
    week_range = helpers.week_date_range(week_number)
    return [] unless week_range
    
    week_start_date = Date.parse(week_range[0]).beginning_of_day
    week_end_date = Date.parse(week_range[1]).end_of_day

    # Count review actions by actor (the person doing the reviewing, not being reviewed)
    reviewer_counts = Hash.new(0)
    
    # Look through all users' audit logs to find review actions
    User.where.not(audit_logs: []).find_each do |user|
      user.audit_logs.each do |log|
        review_action = log["action"] == "Project reviewed" || 
                       log["action"] == "Project status updated" ||
                       log["action"] == "Stonemason feedback updated" ||
                       log["action"]&.include?("Coins") && log["action"]&.include?("admin")
        next unless review_action
        
        log_time = Time.parse(log["timestamp"]) rescue nil
        next unless log_time && log_time >= week_start_date && log_time <= week_end_date
        
        # Count the action for the actor (reviewer), not the user being reviewed
        actor_id = log["actor_id"]
        next unless actor_id
        
        reviewer_counts[actor_id] += 1
      end
    end
    
    # Convert to array with user objects and sort
    review_actions = []
    reviewer_counts.each do |actor_id, count|
      reviewer = User.find_by(id: actor_id)
      next unless reviewer
      
      review_actions << {
        user: reviewer,
        count: count
      }
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
