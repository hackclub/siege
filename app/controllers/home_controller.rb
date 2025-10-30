class HomeController < ApplicationController
  def index
    @current_user = current_user&.decorate
    # Ensure meeple exists for display
    current_user&.ensure_meeple
  end

  def stats
    @current_user = current_user&.decorate
    @week = helpers.current_week_number
    @project_exists = current_user ? current_user.has_project_this_week?(Date.current) : false
    @week_secs = @current_user&.seconds_for_week(@week).to_f || 0
    @current_project = helpers.current_week_project
    @effective_goal_secs = helpers.current_week_effective_hour_goal * 3600
    @week_secs_for_wave = @current_user&.week_seconds_time.to_f || 0
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          week_secs: @week_secs_for_wave,
          effective_goal_secs: @effective_goal_secs,
          today_message: helpers.today_coding_message,
          weekly_stats_html: render_to_string(partial: 'home/weekly_stats_content', formats: [:html])
        }
      end
    end
  end

  def verify_admin_key
    unless user_signed_in?
      render json: { success: false, message: "You must be signed in to use this feature." }, status: :unauthorized
      return
    end

    provided_key = params[:admin_key]
    expected_key = ENV["ADMIN_KEY"]

    if expected_key.present? && provided_key&.strip == expected_key&.strip
      render json: { success: true, message: "Admin key verified! Please select your rank." }
    else
      render json: { success: false, message: "Invalid key." }, status: :unauthorized
    end
  end

  def set_rank
    unless user_signed_in?
      render json: { success: false, message: "You must be signed in to use this feature." }, status: :unauthorized
      return
    end

    # Only allow users with specific Slack ID to change ranks
    unless current_user.slack_id == "U07BN55GN3D"
      render json: { success: false, message: "You do not have permission to use this feature." }, status: :forbidden
      return
    end

    rank = params[:rank]
    valid_ranks = %w[user viewer admin super_admin]

    if valid_ranks.include?(rank)
      current_user.update!(rank: rank)
      render json: { success: true, message: "Rank updated to #{rank}!" }
    else
      render json: { success: false, message: "Invalid rank selected." }, status: :bad_request
    end
  end
end
