class AddressesController < ApplicationController
  before_action :check_not_banned
  before_action :set_address, only: [ :show, :edit, :update ]
  before_action :verify_address_ownership, only: [ :edit, :update ]
  before_action :set_meeple, only: [ :show, :edit, :update ]
  before_action :require_no_address, only: [ :new, :create ]

  def show
    # Ensure meeple exists for all users
    @meeple = current_user.meeple || current_user.create_meeple(color: "blue", cosmetics: [])

    # Get user's referral count
    @user_referral_count = current_user.referrals.count

    # Get top 5 referrers for the leaderboard (excluding EnterpriseGoose)
    @top_referrers = User.joins(:referrals)
                        .where.not(id: 1)
                        .group("users.id")
                        .order("COUNT(referrals_users.id) DESC")
                        .limit(5)
                        .pluck("users.id, users.name, COUNT(referrals_users.id)")
  end

  def new
    @address = Address.new
    @detected_country = request.location&.country_code.presence || "US"
  end

  def create
    @address = current_user.build_address(address_params)
    @meeple = current_user.build_meeple(color: "blue")

    if @address.save && @meeple.save
      # Check if we need to return to a specific path after address setup
      return_path = session.delete(:return_to_after_address)

      # Handle special submission flow return
      if params[:return_to] == "submit_project" && params[:project_id].present?
        redirect_to project_path(params[:project_id]), notice: "Address set up successfully! You can now submit your project."
      elsif return_path.present?
        redirect_to return_path, notice: "Address set up successfully! Please continue with your submission."
      else
        redirect_to keep_path, notice: "Details created successfully!"
      end
    else
      @detected_country = request.location&.country_code.presence || "US"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    redirect_to new_chambers_path unless @address
    @detected_country = @address.country
  end

  def update
    # Check if this is a JSON request by content type or if it's a meeple-only update
    is_json_request = request.format.json? || request.content_type&.include?("application/json") || params[:meeple]&.present?

    if is_json_request
      meeple_params_data = meeple_params
      Rails.logger.info "Meeple params: #{meeple_params_data.inspect}"
      Rails.logger.info "Current meeple cosmetics: #{@meeple.cosmetics.inspect}"

      if @meeple.update(meeple_params_data)
        render json: { success: true }
      else
        Rails.logger.error "Meeple update failed: #{@meeple.errors.full_messages}"
        render json: { success: false, errors: @meeple.errors.full_messages }, status: :unprocessable_entity
      end
    else
      address_success = address_params.empty? ? true : @address.update(address_params)
      meeple_success = meeple_params.empty? ? true : @meeple.update(meeple_params)

      if address_success && meeple_success
        redirect_to chambers_path, notice: "Details updated successfully!"
      else
        render :edit, status: :unprocessable_entity
      end
    end
  rescue ActionController::ParameterMissing => e
    if request.format.json? || request.content_type&.include?("application/json") || params[:meeple]&.present?
      render json: { success: false, errors: [ "Invalid parameters" ] }, status: :bad_request
    else
      raise e
    end
  end

  private

  def set_address
    @address = current_user.address
  end

  def verify_address_ownership
    # Ensure the address belongs to the current user
    # This is already implicitly guaranteed by set_address using current_user.address
    # but we add explicit verification for security
    if @address && !@address.owned_by?(current_user)
      Rails.logger.warn "[Security] User #{current_user.id} attempted to access address #{@address.id} owned by user #{@address.user_id}"
      redirect_to chambers_path, alert: "Access denied. You can only view your own address details."
      false
    end
  end

  def set_meeple
    @meeple = current_user.meeple || current_user.create_meeple(color: "blue", cosmetics: [])
  end

  def require_no_address
    if current_user&.address&.present?
      redirect_to chambers_path, alert: "You already have details. Please update your existing details if needed."
    end
  end

  def address_params
    return {} if request.format.json? || request.content_type&.include?("application/json") || params[:meeple]&.present?
    params.require(:address).permit(:first_name, :last_name, :birthday, :shipping_name, :line_one, :line_two, :city, :state, :postcode, :country)
  end

  def meeple_params
    return {} unless params[:meeple]&.present?
    params.require(:meeple).permit(:color)
  rescue ActionController::ParameterMissing
    {}
  end
end
