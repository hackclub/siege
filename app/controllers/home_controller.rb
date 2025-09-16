class HomeController < ApplicationController
  def index
    @current_user = current_user&.decorate
    # Ensure meeple exists for display
    current_user&.ensure_meeple
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
