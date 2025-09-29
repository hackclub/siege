class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [ :new, :create, :failure ]
  before_action :require_no_authentication, only: [ :create ]

  def new
    # If user is already signed in, redirect to castle
    if user_signed_in?
      redirect_to castle_path
      return
    end
    
    # Store referral ID in cookie if present in params
    if params[:ref].present?
      cookies[:referrer_id] = {
        value: params[:ref],
        expires: 30.days.from_now,
        httponly: true
      }
      # Only redirect if we're not already at the root path
      unless request.path == "/"
        redirect_to "/"
        return
      end
    end
    render :new
  end

  def create
    Rails.logger.info "=== SESSIONS CONTROLLER CREATE CALLED ==="
    Rails.logger.info "Request env keys: #{request.env.keys.grep(/omniauth|slack/)}"

    auth = request.env["omniauth.auth"]
    referrer_id = cookies[:referrer_id]

    Rails.logger.info "OAuth callback received. Auth object present: #{auth.present?}"
    Rails.logger.info "Auth object: #{auth.inspect}" if auth.present?

    begin
      # Check if auth object is present
      unless auth
        Rails.logger.error "No OAuth auth object received"
        redirect_to root_path, alert: "Authentication failed - no OAuth data received."
        return
      end

      # Check if user exists before creating/updating
      slack_id = auth.uid.split("-").second
      existing_user = User.find_by(slack_id: slack_id)

      user = User.from_omniauth(auth, referrer_id)

      if user.persisted?
        session[:user_id] = user.id
        Rails.logger.info "User signed in: #{user.name} (ID: #{user.id})"

        # Don't clear referrer cookie here - let the address controller handle it
        # The cookie will be cleared after the address is successfully created

        if user.address.present?
          redirect_to castle_path, notice: "Successfully signed in!"
        else
          # Check if this is a new user (just created)
          if existing_user.nil?
            redirect_to welcome_path, notice: "Welcome to Siege!"
          else
            redirect_to new_chambers_path, notice: "Please set up your details to continue."
          end
        end
      else
        Rails.logger.error "User not persisted. Errors: #{user.errors.full_messages}"
        redirect_to root_path, alert: "There was an error signing you in."
      end
    rescue => e
      Rails.logger.error "Authentication error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join(', ')}"
      redirect_to root_path, alert: "Authentication failed."
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Signed out successfully!"
  end

  def failure
    redirect_to root_path, alert: "Authentication failed."
  end

  def identity_verification_callback
    # Check if user is signed in
    unless current_user
      redirect_to root_path, alert: "Please sign in to complete identity verification."
      return
    end

    # Get parameters
    idv_rec = params[:idv_rec]
    email = params[:email]

    # If no email provided, use current user's email
    email ||= current_user.email

    # Check if email matches current user
    if email != current_user.email
      redirect_to projects_path, alert: "Email mismatch. Please retry or message @Olive on slack."
      return
    end

    # Store the idv_rec
    if current_user.update(idv_rec: idv_rec)
      redirect_to projects_path, notice: "Successfully verified identity."
    else
      redirect_to projects_path, alert: "Failed to save identity verification. Please try again or message @Olive on slack."
    end
  end
end
