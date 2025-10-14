class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show edit update destroy submit hours update_status ]
  before_action :require_authentication, only: %i[ check_identity store_idv_rec ]
  before_action :require_address_for_verification, only: %i[ submit ]
  before_action :check_not_banned, except: %i[ show index ]
  before_action :decorate_project, only: %i[ show edit ]
  before_action :check_creation_eligibility, only: [ :new, :create ]
  before_action :check_project_ownership, only: %i[ show edit update submit ]
  before_action :check_project_edit_permission, only: %i[ edit update ]
  before_action :check_project_deletion_permission, only: %i[ destroy ]
  before_action :check_admin_access, only: %i[ update_status ]

  # GET /projects or /projects.json
  def index
    if current_user
      @projects = current_user.projects.visible_to_user(current_user).decorate
    else
      @projects = []
    end

    # Pre-fetch votes for finished projects to calculate average scores (admin only)
    if can_access_admin?
      finished_projects = @projects.select(&:finished?)
      if finished_projects.any?
        project_ids = finished_projects.map(&:id)
        @vote_averages = Vote.where(project_id: project_ids, voted: true)
                             .group(:project_id)
                             .average(:star_count)
                             .transform_values { |avg| avg.to_f.round(2) }
      else
        @vote_averages = {}
      end
    end
  end

  # GET /projects/1 or /projects/1.json
  def show
    if @project.finished?
      # Only expose vote data to admins
      if can_access_admin?
        @votes = Vote.where(project_id: @project.id)
        cast_votes = @votes.where(voted: true)
        @average_score = cast_votes.any? ? cast_votes.average(:star_count).to_f.round(2) : nil
      end
    end
  end

  # GET /projects/new
  def new
    @project = Project.new
  end

  # GET /projects/1/edit
  def edit
  end

  # POST /projects or /projects.json
  def create
    @project = current_user.projects.build(project_params)

    # Ensure time override is applied based on current Flipper flags
    @project.set_time_override_from_flipper

    respond_to do |format|
      if @project.save
        # Log project creation
        current_user.add_audit_log(
          action: "Project created",
          actor: current_user,
          details: {
            "project_name" => @project.name,
            "project_id" => @project.id,
            "project_status" => @project.status
          }
        )

        format.html { redirect_to @project, notice: "Project was successfully created." }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1 or /projects/1.json
  def update
    # Skip screenshot validation if a new screenshot is being uploaded
    if params.dig(:project, :screenshot).present?
      Rails.logger.info "New screenshot being uploaded for project #{@project.id} - User: #{current_user.id}"
      @project.skip_screenshot_validation!
    end

    # Skip screenshot validation for admin edits to handle corrupted/missing screenshots
    if can_access_admin?
      @project.skip_screenshot_validation!
    end

    respond_to do |format|
      if @project.update(project_params)
        # Log project update
        current_user.add_audit_log(
          action: "Project updated",
          actor: current_user,
          details: {
            "project_name" => @project.name,
            "project_id" => @project.id,
            "project_status" => @project.status
          }
        )

        format.html { redirect_to @project, notice: "Project was successfully updated." }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1 or /projects/1.json
  def destroy
    @project.destroy!

    respond_to do |format|
      format.html { redirect_to projects_path, status: :see_other, notice: "Project was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # POST /projects/1/submit
  def submit
    # Validate project is in building status
    unless @project.building?
      respond_to do |format|
        format.html { redirect_to @project, alert: "Project cannot be submitted in its current state." }
        format.json { render json: { error: "Project cannot be submitted in its current state." }, status: :unprocessable_entity }
      end
      return
    end

    # Validate user is not banned
    if current_user.banned?
      respond_to do |format|
        format.html { redirect_to @project, alert: "You are banned and cannot submit projects." }
        format.json { render json: { error: "You are banned and cannot submit projects." }, status: :forbidden }
      end
      return
    end

    # Validate project is not locked
    if @project.locked?
      respond_to do |format|
        format.html { redirect_to @project, alert: "This project is locked and cannot be submitted." }
        format.json { render json: { error: "This project is locked and cannot be submitted." }, status: :unprocessable_entity }
      end
      return
    end

    # Validate required fields
    if @project.repo_url.blank?
      respond_to do |format|
        format.html { redirect_to @project, alert: "Repository URL is required." }
        format.json { render json: { error: "Repository URL is required." }, status: :unprocessable_entity }
      end
      return
    end

    if @project.demo_url.blank?
      respond_to do |format|
        format.html { redirect_to @project, alert: "Demo URL is required." }
        format.json { render json: { error: "Demo URL is required." }, status: :unprocessable_entity }
      end
      return
    end

    # Validate screenshot
    unless @project.screenshot.attached? && @project.screenshot_valid?
      respond_to do |format|
        format.html { redirect_to @project, alert: "A valid screenshot is required." }
        format.json { render json: { error: "A valid screenshot is required." }, status: :unprocessable_entity }
      end
      return
    end

    # Validate hackatime projects (must have at least one)
    if @project.hackatime_projects.blank? || @project.hackatime_projects.empty?
      respond_to do |format|
        format.html { redirect_to @project, alert: "At least one Hackatime project is required." }
        format.json { render json: { error: "At least one Hackatime project is required." }, status: :unprocessable_entity }
      end
      return
    end

    # Update the is_update flag if provided
    if params[:is_update].present?
      @project.skip_screenshot_validation!
      @project.update!(is_update: params[:is_update])
    end

    respond_to do |format|
      if @project.submit!
        format.html { redirect_to @project, notice: "Project was successfully submitted!" }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { redirect_to @project, alert: @project.errors.full_messages.join(", ") }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /api/project_hours/:id
  def hours
    current_week_hours = 0

    Rails.logger.info "[ProjectHours] Calculating hours for project #{@project.id}"
    Rails.logger.info "[ProjectHours] Project has hackatime_projects: #{@project.hackatime_projects.inspect}"

    # If project has hackatime projects, calculate total hours for current week
    if @project.hackatime_projects.present?
      # Get the current week's start and end dates
      current_week_start = Date.current.beginning_of_week(:monday)
      current_week_end = Date.current.end_of_week(:sunday)

      # Fetch actual hours from Hackatime API for the specific project names
      start_date_str = current_week_start.strftime("%Y-%m-%d")
      end_date_str = current_week_end.strftime("%Y-%m-%d")

      Rails.logger.info "[ProjectHours] Fetching Hackatime data for date range: #{start_date_str} to #{end_date_str}"

      # Get Hackatime projects data for the current week
      projects_data = hackatime_projects_for(start_date_str, end_date_str)

      Rails.logger.info "[ProjectHours] Received #{projects_data.length} projects from Hackatime API"
      Rails.logger.debug "[ProjectHours] Available projects: #{projects_data.map { |p| p['name'] }.join(', ')}"

      # Sum up hours for the specific projects associated with this project
      total_seconds = 0
      @project.hackatime_projects.each do |project_name|
        matching_project = projects_data.find { |p| p["name"].to_s == project_name.to_s }
        if matching_project
          project_seconds = matching_project["total_seconds"] || 0
          total_seconds += project_seconds
          Rails.logger.info "[ProjectHours] Found matching project '#{project_name}': #{project_seconds} seconds"
        else
          Rails.logger.warn "[ProjectHours] No matching project found for '#{project_name}'"
        end
      end

      # Convert seconds to hours
      current_week_hours = (total_seconds / 3600.0).round(1)
      Rails.logger.info "[ProjectHours] Total calculated hours: #{current_week_hours}"
    else
      Rails.logger.info "[ProjectHours] No hackatime_projects configured for project #{@project.id}"
    end

    render json: {
      hours: current_week_hours,
      week_start: Date.current.beginning_of_week(:monday).strftime("%Y-%m-%d"),
      week_end: Date.current.end_of_week(:sunday).strftime("%Y-%m-%d")
    }
  end

  # GET /projects/1/check_identity
  def check_identity
    # First check if user has an address - required for identity verification
    unless is_full_user?
      render json: {
        status: "no_address",
        message: "We need just a couple more details from you to complete your account so you can submit your project!",
        redirect_url: "#{new_chambers_path}?return_to=submit_project&project_id=#{params[:id] || @project&.id}"
      }
      return
    end

    # Check if user has idv_rec
    if current_user.idv_rec.blank?
      render json: {
        status: "not_verified",
        message: "You are not yet identity verified. Please verify through idv before continuing."
      }
      return
    end

    # Make request to identity verification API
    begin
      response = HTTP.get("https://identity.hackclub.com/api/external/check?idv_id=#{current_user.idv_rec}")

      if response.status.success?
        result = JSON.parse(response.body.to_s)["result"]

        case result
        when "not_found", "needs_submission"
          render json: {
            status: "not_verified",
            message: "You are not yet identity verified. Please verify through idv before continuing."
          }
        when "pending"
          render json: {
            status: "pending",
            message: "Your identity verification is currently pending. Please wait for this to complete before proceeding."
          }
        when "rejected", "verified_but_over_18"
          render json: {
            status: "ineligible",
            message: "Sorry, but you are ineligible for Siege. Please contact @Olive on slack for more details."
          }
        when "verified_eligible"
          render json: { status: "verified" }
        else
          render json: {
            status: "error",
            message: "Unknown verification status. Please contact @Olive on slack for more details."
          }
        end
      else
        render json: {
          status: "error",
          message: "Failed to check identity verification status. Please try again or contact @Olive on slack."
        }
      end
    rescue => e
      Rails.logger.error "Identity verification check failed: #{e.message}"
      render json: {
        status: "error",
        message: "Failed to check identity verification status. Please try again or contact @Olive on slack."
      }
    end
  end

  # POST /process_identity_and_address
  def process_identity_and_address
    # Expect the full identity data to be passed from the frontend
    identity_data = params[:identity_data]
    idv_rec = params[:idv_rec]

    Rails.logger.info "Processing identity and address with idv_rec: #{idv_rec}"

    if identity_data.blank? || idv_rec.blank?
      Rails.logger.error "Missing identity data or idv_rec"
      render json: { status: "error", message: "Missing verification data" }
      return
    end

    begin
      # Store the idv_rec
      current_user.update!(idv_rec: idv_rec)

      # Process identity data if user doesn't have address yet
      if current_user.address.blank? && identity_data["addresses"]&.any?
        primary_address = identity_data["addresses"].find { |addr| addr["primary"] } || identity_data["addresses"].first

        if primary_address
          # Create address from identity data
          address_attrs = {
            first_name: identity_data["first_name"],
            last_name: identity_data["last_name"],
            birthday: Date.parse(identity_data["birthday"]),
            line_one: primary_address["line_1"],
            line_two: primary_address["line_2"],
            city: primary_address["city"],
            state: primary_address["state"],
            postcode: primary_address["postal_code"],
            country: primary_address["country"]
          }

          # Create address and meeple
          address = current_user.build_address(address_attrs)
          meeple = current_user.build_meeple(color: "blue") unless current_user.meeple.present?

          if address.save && (meeple.nil? || meeple.save)
            Rails.logger.info "Address auto-created from identity verification for user #{current_user.id}"

            # All required data collected, ask for optional shipping name
            render json: {
              status: "address_created",
              message: "Identity verified and address set up successfully!",
              needs_shipping_name: true,
              extracted_data: address_attrs
            }
          else
            # Address creation failed, need manual setup
            render json: {
              status: "partial_data",
              message: "Identity verified but address setup needs completion.",
              redirect_url: new_chambers_path,
              extracted_data: address_attrs
            }
          end
        else
          # No address data in identity response
          render json: {
            status: "missing_address",
            message: "Identity verified but address information is missing.",
            redirect_url: new_chambers_path
          }
        end
      else
        # User already has address, just update idv_rec
        render json: { status: "verified" }
      end
    rescue => e
      Rails.logger.error "Identity and address processing failed: #{e.message}"
      render json: {
        status: "error",
        message: "Failed to process identity verification."
      }
    end
  end

  # POST /set_shipping_name
  def set_shipping_name
    shipping_name = params[:shipping_name]

    if current_user.address.present?
      if current_user.address.update(shipping_name: shipping_name)
        render json: { status: "success", message: "Shipping name updated successfully!" }
      else
        render json: { status: "error", message: "Failed to update shipping name." }
      end
    else
      render json: { status: "error", message: "No address found." }
    end
  end

  # POST /store_idv_rec
  def store_idv_rec
    idv_rec = params[:idv_rec]

    if idv_rec.blank?
      render json: { success: false, error: "No idv_rec provided" }
      return
    end

    if current_user.update(idv_rec: idv_rec)
      render json: { success: true }
    else
      render json: { success: false, error: "Failed to save idv_rec" }
    end
  end

  # PATCH /projects/1/update_status
  def update_status
    new_status = params[:status]

    if %w[building submitted pending_voting waiting_for_review finished].include?(new_status)
      # Skip screenshot validation when updating status to handle corrupted/missing screenshots
      @project.skip_screenshot_validation!

      if @project.update(status: new_status)
        redirect_to @project, notice: "Project status updated to #{new_status}."
      else
        redirect_to @project, alert: "Failed to update project status."
      end
    else
      redirect_to @project, alert: "Invalid status."
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      begin
        @project = Project.find(params.expect(:id))
        
        # Check if project is hidden and user is not super admin
        if @project.hidden? && !current_user&.super_admin?
          Rails.logger.warn "[Project] Hidden project #{params[:id]} accessed by non-super-admin user #{current_user&.id}"
          respond_to do |format|
            format.html { redirect_to root_path, alert: "Project not found." }
            format.json { render json: { error: "Project not found" }, status: :not_found }
          end
          return
        end
      rescue ActiveRecord::RecordNotFound
        Rails.logger.warn "[Project] Project with ID #{params[:id]} not found for user #{current_user&.id}"
        respond_to do |format|
          format.html { redirect_to root_path, alert: "Project not found." }
          format.json { render json: { error: "Project not found" }, status: :not_found }
        end
      end
    end

    # Decorate loaded project for read-only views so decorator methods are available.
    def decorate_project
      @project = @project.decorate if @project.present?
    end

    # Only allow a list of trusted parameters through.
    def project_params
      # Build list of allowed parameters - time_override_days only for admins
      allowed_params = [ :name, :repo_url, :demo_url, :description, :screenshot, { hackatime_projects: [] } ]
      allowed_params << :time_override_days if can_access_admin?
      
      permitted_params = params.expect(project: allowed_params)

      # Clean up hackatime_projects array - remove empty strings and nil values
      if permitted_params[:hackatime_projects].present?
        permitted_params[:hackatime_projects] = permitted_params[:hackatime_projects].reject(&:blank?)
      end

      # Handle screenshot removal
      if params[:remove_screenshot] == "true"
        if @project&.screenshot&.attached?
          Rails.logger.info "Removing screenshot for project #{@project.id} - User: #{current_user.id}"
          # Properly purge the blob and file
          @project.screenshot.purge_later
        end
        permitted_params.delete(:screenshot)
      end

      permitted_params
    end

    def check_creation_eligibility
      unless helpers.can_create_project?
        redirect_to projects_path, alert: helpers.project_creation_message
      end
    end

    def check_project_ownership
      # For show action, allow any signed-in user to view
      if action_name == 'show'
        unless user_signed_in?
          redirect_to root_path, alert: "You must be signed in to view projects."
        end
        # If user is signed in, allow them to view any project
        return
      else
        # For edit/update/submit actions, require ownership or admin
        unless @project.user == current_user || can_access_admin?
          redirect_to @project, alert: "You don't have permission to perform this action."
        end
      end
    end

    def check_project_edit_permission
      # Admins can always edit projects
      return if can_access_admin?

      # Regular users cannot edit projects once they reach pending_voting, waiting_for_review, or finished status
      unless @project.editable_by_user?
        redirect_to @project, alert: "This project cannot be edited as it has entered the review phase."
      end
    end

    def check_admin_access
      unless can_access_admin?
        redirect_to root_path, alert: "You don't have permission to perform this action."
      end
    end

    def check_project_deletion_permission
      # Admins can always delete
      return if can_access_admin?

      # Project owner can only delete if it's from the current week
      if @project.user == current_user
        current_week = helpers.current_week_number
        project_week = helpers.week_number_for_date(@project.created_at)

        unless project_week == current_week
          redirect_to @project, alert: "You can only delete projects from the current week."
          nil
        end
      else
        # Not the owner and not an admin
        redirect_to @project, alert: "You don't have permission to perform this action."
      end
    end
end
