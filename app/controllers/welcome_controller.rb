class WelcomeController < ApplicationController
  def index
    # Show welcome page for new users
    @current_week = helpers.current_week_number
    @week_type = @current_week <= 3 ? "prep" : "siege"
    @is_prep_week = @week_type == "prep"
    @siege_started = @current_week >= 4
    @can_get_framework = @current_week == 4
  end

  def complete
    # Check if terms were accepted (checkbox sends "on" when checked)
    if params[:terms_accepted] == "on"
      # Update user status from 'new' to 'working' when they complete the welcome flow
      if current_user&.status == "new"
        # Process referral before changing status
        process_referral_on_welcome_completion

        current_user.update(status: "working")
      end

      redirect_to castle_path, notice: "Welcome to Siege! Your account is now set up."
    else
      redirect_to welcome_path, alert: "You must agree to the hackatime terms to continue."
    end
  end

  private

  def process_referral_on_welcome_completion
    # Handle referrer_id - prioritize cookie, then manual input
    if current_user.referrer_id.nil?
      referrer_id = nil

      # Check cookie
      if cookies[:referrer_id].present?
        referrer_id = cookies[:referrer_id].to_i

        # Process referrer_id if found and valid
        if referrer_id && referrer_id > 0 && User.exists?(referrer_id)
          # Prevent self-referral
          if referrer_id != current_user.id
            current_user.update(referrer_id: referrer_id)
            Rails.logger.info "Referral processed on welcome completion - User: #{current_user.id}, Referrer: #{referrer_id}"

            # Clear the referrer cookie after successful assignment
            cookies.delete(:referrer_id)
          end
        end
      end
    end
  end
end
