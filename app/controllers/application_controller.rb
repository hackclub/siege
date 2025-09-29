class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  before_action :require_authentication
  before_action :redirect_new_users_to_welcome

  unless Rails.env.production?
    around_action :n_plus_one_detection

    def n_plus_one_detection
      Prosopite.scan
      yield
    ensure
      Prosopite.finish
    end
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    if session[:user_id]
      begin
        @current_user = User.find(session[:user_id])
      rescue ActiveRecord::RecordNotFound
        Rails.logger.warn "[Auth] User with ID #{session[:user_id]} not found, clearing session"
        reset_session
        @current_user = nil
      end
    else
      @current_user = nil
    end

    @current_user
  end

  def user_signed_in?
    current_user.present?
  end

  def is_full_user?
    user_signed_in? && current_user&.address&.present?
  end

  def require_authentication
    redirect_to root_path unless user_signed_in?
  end

  def require_no_authentication
    redirect_to castle_path if user_signed_in?
  end

  def require_address
    redirect_to new_chambers_path unless is_full_user?
  end

  def require_address_for_verification
    unless is_full_user?
      # Store the current path to return to after address setup
      session[:return_to_after_address] = request.fullpath
      redirect_to new_chambers_path, notice: "Please set up your address details to continue with project submission."
    end
  end

  def check_not_banned
    if current_user&.banned?
      respond_to do |format|
        format.html { redirect_to root_path, alert: "You are banned from Siege. If you believe this is a mistake, please contact @Olive on Slack." }
        format.json { render json: { success: false, error: "You are banned from Siege. If you believe this is a mistake, please contact @Olive on Slack." }, status: :forbidden }
      end
    end
  end

  def redirect_new_users_to_welcome
    if current_user&.new? && !on_welcome_page?
      redirect_to welcome_path
    end
  end

  def on_welcome_page?
    controller_name == "welcome" || controller_name == "sessions"
  end

  def can_access_admin?
    current_user&.admin? || current_user&.super_admin?
  end

  def can_access_review?
    current_user&.viewer? || current_user&.admin? || current_user&.super_admin?
  end

  def can_access_fraud_dashboard?
    current_user&.can_access_fraud_dashboard?
  end

  def feature_enabled?(feature_name)
    Flipper.enabled?(feature_name, current_user)
  end

  def flipper_actor
    current_user
  end

  helper_method :current_user, :user_signed_in?, :can_access_admin?, :can_access_review?, :can_access_fraud_dashboard?, :feature_enabled?, :flipper_actor
end
