class AdminController < ApplicationController
  before_action :require_admin_access

  def index
    # Current week info
    @current_week_number = view_context.current_week_number

    # User statistics
    @total_users = User.count
    @users_working = User.where(status: "working").count

    # Project statistics by status
    @projects_building = Project.where(status: "building").count
    @projects_submitted = Project.where(status: "submitted").count
    @projects_pending_voting = Project.where(status: "pending_voting").count
    @projects_finished = Project.where(status: "finished").count
    @total_projects = Project.count
  end

  def projects
    # Only show hidden projects if super admin has explicitly checked the box
    if current_user&.super_admin? && params[:show_hidden] == 'true'
      @projects = Project.all.includes(:user)
      @show_hidden = true
    else
      # Default: only show visible projects (for both super admins and regular users)
      @projects = Project.visible.includes(:user)
      @show_hidden = false
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

    # Filter by status if provided
    if params[:status].present? && %w[building submitted pending_voting finished].include?(params[:status])
      @projects = @projects.where(status: params[:status])
    end

    # Filter by week if provided
    if params[:week].present? && params[:week].to_i.to_s == params[:week]
      week_number = params[:week].to_i
      week_range = view_context.week_date_range(week_number)

      if week_range
        week_start_date = Date.parse(week_range[0])
        week_end_date = Date.parse(week_range[1])
        @projects = @projects.where(created_at: week_start_date.beginning_of_day..week_end_date.end_of_day)
      end
    end

    # Order by creation date (newest first) with secondary sort by name
    @projects = @projects.order(created_at: :desc, name: :asc).decorate

    # Get unique users for the owner filter dropdown
    @users = User.joins(:projects).select(:id, :name).distinct.order(:name)

    # Get all possible statuses for the status filter
    @statuses = %w[building submitted pending_voting finished]

    # Get available weeks for the week filter dropdown
    @available_weeks = Project.distinct.pluck(:created_at).map do |created_at|
      view_context.week_number_for_date(created_at)
    end.uniq.sort.reverse

    # Pagination
    @per_page = 25
    @current_page = (params[:page] || 1).to_i
    @total_count = @projects.count
    @total_pages = (@total_count.to_f / @per_page).ceil

    offset = (@current_page - 1) * @per_page
    @projects = @projects.offset(offset).limit(@per_page)
  end

  def users
    @users = User.all.includes(:projects, :meeple, :address, :referrer)

    # Filter by name if provided (search name, display_name, and slack_id)
    if params[:name].present?
      escaped_name = ActiveRecord::Base.connection.quote_string(params[:name])
      @users = @users.where("users.name ILIKE ? OR users.display_name ILIKE ? OR users.slack_id ILIKE ?", "%#{escaped_name}%", "%#{escaped_name}%", "%#{escaped_name}%")
    end

    # Filter by referred_by if provided (search by referrer name or ID)
    if params[:referred_by].present?
      # Try to find users where the referrer matches the search term by ID, name, or display_name
      escaped_referrer = ActiveRecord::Base.connection.quote_string(params[:referred_by])
      @users = @users.joins("JOIN users AS referrers ON users.referrer_id = referrers.id")
                     .where("referrers.id::text = ? OR referrers.name ILIKE ? OR referrers.display_name ILIKE ?",
                            escaped_referrer, "%#{escaped_referrer}%", "%#{escaped_referrer}%")
    end

    # Filter by status if provided
    if params[:status].present? && %w[out working completed].include?(params[:status])
      @users = @users.where(status: params[:status])
    end

    # Filter by rank if provided
    if params[:rank].present? && %w[user viewer admin super_admin].include?(params[:rank])
      @users = @users.where(rank: params[:rank])
    end

    # Filter by hackatime trust if provided
    if params[:hackatime_trust].present? && %w[trusted neutral banned unknown].include?(params[:hackatime_trust])
      # Store the filter value to apply after fetching trust data
      @hackatime_trust_filter = params[:hackatime_trust]
    end

    # Filter by age if provided (super admin only)
    if current_user&.super_admin? && (params[:min_age].present? || params[:max_age].present?)
      @users = filter_users_by_age(@users, params[:min_age], params[:max_age])
    end

    # Order by name with secondary sort by creation date
    @users = @users.order("users.name", "users.created_at DESC")

    # Preload associations to avoid N+1 queries
    @users = @users.includes(:projects, :meeple)

    # Pre-calculate project counts and week seconds for each user
    current_week_number = view_context.current_week_number
    @user_week_seconds = {}
    @user_project_counts = {}
    # @user_hackatime_trust = {} # Moved to async loading

    # Get week date range for efficient querying
    week_range = view_context.week_date_range(current_week_number)

    if week_range
      week_start_date = Date.parse(week_range[0])
      week_end_date = Date.parse(week_range[1])

      # Pre-fetch all projects for the current week
      week_projects = Project.where(
        user_id: @users.pluck(:id),
        created_at: week_start_date.beginning_of_day..week_end_date.end_of_day
      ).includes(:user)

      # Group projects by user_id for efficient lookup
      projects_by_user = week_projects.group_by(&:user_id)

      # Pre-calculate all project counts in a single query
      project_counts = Project.where(user_id: @users.pluck(:id))
                             .group(:user_id)
                             .count

      # Store user IDs for later processing
      user_ids = @users.pluck(:id)

      # Pre-fetch all users with their associations to avoid N+1 queries
      users_by_id = @users.index_by(&:id)

      user_ids.each do |user_id|
        @user_project_counts[user_id] = project_counts[user_id] || 0

        # Calculate week seconds efficiently using the new helper
        user_week_projects = projects_by_user[user_id] || []
        # Use project's effective time range instead of standard week range
        user = users_by_id[user_id]
        @user_week_seconds[user_id] = view_context.user_hackatime_time_for_projects(user, user_week_projects, nil)

        # Hackatime trust status will be loaded asynchronously
      end
    else
      # Fallback if week range is not available
      # Pre-calculate all project counts in a single query
      project_counts = Project.where(user_id: @users.pluck(:id))
                             .group(:user_id)
                             .count

      # Store user IDs for later processing
      user_ids = @users.pluck(:id)

      # Pre-fetch all users with their associations to avoid N+1 queries
      users_by_id = @users.index_by(&:id)

      user_ids.each do |user_id|
        @user_project_counts[user_id] = project_counts[user_id] || 0
        @user_week_seconds[user_id] = 0
        # Hackatime trust status will be loaded asynchronously
      end
    end

    # Get all possible statuses and ranks for filters
    @user_statuses = %w[out working completed]
    @user_ranks = %w[user viewer admin super_admin]

    # Note: Hackatime trust filtering is not available synchronously
    # Users can filter by trust status after the page loads using the async data

    # Pagination
    @per_page = 25
    @current_page = (params[:page] || 1).to_i

    # Get total count after filtering
    @total_count = @users.count
    @total_pages = (@total_count.to_f / @per_page).ceil

    # Apply pagination to the array
    offset = (@current_page - 1) * @per_page
    @users = @users[offset, @per_page] || []
  end

  def referrals
    # Get referral counts for each user (excluding EnterpriseGoose)
    @referral_counts = User.joins(:referrals)
                          .where.not(id: 1)
                          .group("users.id")
                          .count("referrals_users.id")

    # Get users who have referred others, sorted by referral count
    user_ids_with_counts = @referral_counts.sort_by { |user_id, count| -count }.map(&:first)
    @referrers = User.where(id: user_ids_with_counts).index_by(&:id).values_at(*user_ids_with_counts).compact
  end

  def refresh_hackatime_cache
    begin
      # Clear hackatime cache for all users
      # Since SolidCache doesn't support delete_matched, we'll clear cache for all users
      # by iterating through users and clearing their specific cache keys
      cleared_count = 0

      User.where.not(slack_id: nil).find_each do |user|
        clean_id = user.slack_id.sub(/^T0266FRGM-/, "")

        # Clear cache for common date ranges (last 30 days worth of potential cache entries)
        (0..30).each do |days_ago|
          start_date = (Date.current - days_ago).strftime("%Y-%m-%d")
          end_date = start_date

          cache_key = [ "hackatime", "stats", "features:projects", clean_id, start_date, end_date ].join(":")
          if Rails.cache.delete(cache_key)
            cleared_count += 1
          end
        end
      end

      redirect_to admin_users_path, notice: "Hackatime cache cleared (#{cleared_count} entries). Trust status will be refreshed on next page load."
    rescue => e
      redirect_to admin_users_path, alert: "Failed to clear cache: #{e.message}"
    end
  end

  def ballots
    @ballots = Ballot.all.includes(:user, votes: [ project: :user ])

    # Filter by user if provided
    if params[:user].present?
      escaped_user = ActiveRecord::Base.connection.quote_string(params[:user])
      @ballots = @ballots.joins(:user).where("users.name ILIKE ?", "%#{escaped_user}%")
    end

    # Filter by week if provided
    if params[:week].present?
      @ballots = @ballots.where(week: params[:week])
    end

    # Filter by voted status if provided
    if params[:voted].present? && %w[true false].include?(params[:voted])
      @ballots = @ballots.where(voted: params[:voted] == "true")
    end

    # Order by week (descending) with secondary sort by user name
    @ballots = @ballots.order(week: :desc, created_at: :desc)

    # Get unique users for the user filter dropdown
    @users = User.joins(:ballots).select(:id, :name).distinct.order(:name)

    # Get all possible weeks for the week filter dropdown
    @weeks = Ballot.distinct.pluck(:week).sort.reverse

    # Pagination
    @per_page = 25
    @current_page = (params[:page] || 1).to_i
    @total_count = @ballots.count
    @total_pages = (@total_count.to_f / @per_page).ceil

    offset = (@current_page - 1) * @per_page
    @ballots = @ballots.offset(offset).limit(@per_page)
  end

  def ballot_details
    @ballot = Ballot.includes(:user, votes: [ project: :user ]).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_ballots_path, alert: "Ballot not found."
  end

  def edit_ballot
    @ballot = Ballot.includes(:user, votes: [ project: :user ]).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_ballots_path, alert: "Ballot not found."
  end

  def update_ballot
    @ballot = Ballot.find(params[:id])
    if @ballot.update(ballot_params)
      redirect_to admin_ballot_details_path(@ballot), notice: "Ballot updated successfully."
    else
      redirect_to edit_admin_ballot_path(@ballot), alert: "Failed to update ballot: #{@ballot.errors.full_messages.join(', ')}"
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_ballots_path, alert: "Ballot not found."
  end

  def destroy_ballot
    @ballot = Ballot.find(params[:id])
    @ballot.destroy
    redirect_to admin_ballots_path, notice: "Ballot deleted successfully."
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_ballots_path, alert: "Ballot not found."
  end

  def user_details
    return unless find_user_safely
    @projects = @user.projects.includes(:user).order(created_at: :desc).decorate

    # Calculate user's current week progress
    @current_week_seconds = @user.decorate.week_seconds(view_context.current_week_number)
    @current_week_progress = (@current_week_seconds / 36000.0 * 100).round(1)
    @current_week_readable = view_context.format_time_from_seconds(@current_week_seconds)

    # Get user's total coins and project count
    @total_coins = @user.coins || 0
    @project_count = @user.projects.count

    # Get user's ballots
    @ballots = @user.ballots.includes(votes: [ project: :user ]).order(week: :desc)

    # Get user's shop purchases (with error handling for autoloading issues)
    begin
      @shop_purchases = @user.shop_purchases.order(purchased_at: :desc)
      @fulfilled_purchases = @shop_purchases.fulfilled
      @unfulfilled_purchases = @shop_purchases.unfulfilled
    rescue NameError => e
      Rails.logger.warn "Could not load shop purchases for user #{@user.id}: #{e.message}"
      @shop_purchases = []
      @fulfilled_purchases = []
      @unfulfilled_purchases = []
    end

    # Get Hackatime trust status
    @hackatime_trust_status = get_hackatime_trust_status(@user)
  end

  def user_hackatime_trust
    return unless find_user_safely
    @hackatime_trust = get_hackatime_trust_status(@user)

    render json: @hackatime_trust
  end

  def add_coins
    return unless find_user_safely
    coins_to_add = params[:coins].to_i

    if coins_to_add != 0
      current_coins = @user.coins || 0
      new_balance = current_coins + coins_to_add

      @user.update!(coins: new_balance)

      # Log the coin change
      @user.add_audit_log(
        action: "Coins #{coins_to_add > 0 ? 'added' : 'removed'} by admin",
        actor: current_user,
        details: {
          "previous_balance" => current_coins,
          "change_amount" => coins_to_add,
          "new_balance" => new_balance
        }
      )

      action_word = coins_to_add > 0 ? "Added" : "Removed"
      redirect_to admin_user_details_path(@user), notice: "#{action_word} #{coins_to_add.abs} coins #{coins_to_add > 0 ? 'to' : 'from'} #{@user.name}. New balance: #{@user.coins}"
    else
      redirect_to admin_user_details_path(@user), alert: "Cannot add/remove 0 coins."
    end
  end

  def unlock_color
    return unless find_user_safely
    color = params[:color]

    if @user.meeple && %w[blue red pink green orange purple cyan yellow].include?(color)
      if @user.meeple.unlock_color(color)
        # Log color unlock
        @user.add_audit_log(
          action: "Meeple color unlocked by admin",
          actor: current_user,
          details: {
            "color" => color,
            "meeple_id" => @user.meeple.id
          }
        )

        redirect_to admin_user_details_path(@user), notice: "Unlocked #{color.capitalize} color for #{@user.name}."
      else
        redirect_to admin_user_details_path(@user), alert: "Failed to unlock color."
      end
    else
      redirect_to admin_user_details_path(@user), alert: "Invalid color or user has no meeple."
    end
  end

  def relock_color
    return unless find_user_safely
    color = params[:color]

    if @user.meeple && %w[blue red pink green orange purple cyan yellow].include?(color)
      if color == @user.meeple.color
        redirect_to admin_user_details_path(@user), alert: "Cannot relock #{@user.name}'s current meeple color (#{color.capitalize}). Change their meeple color first."
      elsif @user.meeple.relock_color(color)
        redirect_to admin_user_details_path(@user), notice: "Relocked #{color.capitalize} color for #{@user.name}."
      else
        redirect_to admin_user_details_path(@user), alert: "Color #{color.capitalize} was not unlocked for this user."
      end
    else
      redirect_to admin_user_details_path(@user), alert: "Invalid color or user has no meeple."
    end
  end

  def update_rank
    return unless find_user_safely
    new_rank = params[:rank]

    # Check permissions based on current user's rank
    allowed_ranks = if current_user.super_admin?
      %w[user viewer admin super_admin]
    elsif current_user.admin?
      %w[user viewer]
    else
      []
    end

    if allowed_ranks.include?(new_rank)
      # Prevent users from demoting themselves below admin level
      if @user == current_user && !%w[admin super_admin].include?(new_rank)
        redirect_to admin_user_details_path(@user), alert: "You cannot demote yourself below admin level."
      else
        old_rank = @user.rank
        @user.update!(rank: new_rank)

        # Log the rank change
        @user.add_audit_log(
          action: "Rank updated by admin",
          actor: current_user,
          details: {
            "previous_rank" => old_rank,
            "new_rank" => new_rank
          }
        )

        redirect_to admin_user_details_path(@user), notice: "Updated #{@user.name}'s rank to #{new_rank.humanize}."
      end
    else
      redirect_to admin_user_details_path(@user), alert: "You don't have permission to set that rank."
    end
  end

  def update_meeple_color
    return unless find_user_safely
    color = params[:color]

    if @user.meeple && %w[blue red pink green orange purple cyan yellow].include?(color)
      if @user.meeple.color_unlocked?(color)
        if @user.meeple.update(color: color)
          render json: { success: true }
        else
          render json: { success: false, errors: @user.meeple.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { success: false, errors: [ "Color #{color.capitalize} is not unlocked for this user" ] }, status: :unprocessable_entity
      end
    else
      render json: { success: false, errors: [ "Invalid color or user has no meeple" ] }, status: :bad_request
    end
  end

  def update_address
    return unless find_user_safely

    if @user.address
      if @user.address.update(address_params)
        redirect_to admin_user_details_path(@user), notice: "Updated address for #{@user.name}."
      else
        redirect_to admin_user_details_path(@user), alert: "Failed to update address: #{@user.address.errors.full_messages.join(', ')}"
      end
    else
      redirect_to admin_user_details_path(@user), alert: "User has no address to update."
    end
  end

  def clear_verification
    return unless find_user_safely

    if @user.update(idv_rec: nil)
      render json: { success: true, message: "Cleared verification for #{@user.name}" }
    else
      render json: { success: false, error: "Failed to clear verification" }
    end
  end

  def clear_main_device
    return unless find_user_safely

    if @user.update(main_device: nil)
      render json: { success: true, message: "Cleared main device for #{@user.name}" }
    else
      render json: { success: false, error: "Failed to clear main device" }
    end
  end

  def toggle_fraud_team
    unless current_user.super_admin?
      render json: { success: false, error: "Access denied. Super admin privileges required." }
      return
    end

    return unless find_user_safely

    on_fraud_team = ActiveModel::Type::Boolean.new.cast(params[:on_fraud_team])
    old_status = @user.on_fraud_team?

    if @user.update(on_fraud_team: on_fraud_team)
      # Log the fraud team status change
      @user.add_audit_log(
        action: "Fraud team status updated",
        actor: current_user,
        details: {
          "previous_status" => old_status ? "on team" : "not on team",
          "new_status" => on_fraud_team ? "on team" : "not on team"
        }
      )

      action_word = on_fraud_team ? "added to" : "removed from"
      render json: { success: true, message: "#{@user.name} #{action_word} fraud team" }
    else
      render json: { success: false, error: "Failed to update fraud team status" }
    end
  end

  def set_referrer
    return unless find_user_safely

    referrer_id = params[:referrer_id].to_i

    # If referrer_id is 0 or empty, clear the referrer
    if referrer_id == 0
      if @user.update(referrer_id: nil)
        redirect_to admin_user_details_path(@user), notice: "Cleared referrer for #{@user.name}"
      else
        redirect_to admin_user_details_path(@user), alert: "Failed to clear referrer"
      end
      return
    end

    # Validate that the referrer exists
    referrer = User.find_by(id: referrer_id)
    unless referrer
      redirect_to admin_user_details_path(@user), alert: "Referrer user with ID #{referrer_id} not found"
      return
    end

    # Validate that user is not referring themselves
    if referrer_id == @user.id
      redirect_to admin_user_details_path(@user), alert: "User cannot refer themselves"
      return
    end

    # Validate that it's not a circular referral
    if referrer.referrer_id == @user.id
      redirect_to admin_user_details_path(@user), alert: "Cannot create circular referral"
      return
    end

    if @user.update(referrer_id: referrer_id)
      redirect_to admin_user_details_path(@user), notice: "Set #{referrer.name} as referrer for #{@user.name}"
    else
      redirect_to admin_user_details_path(@user), alert: "Failed to set referrer: #{@user.errors.full_messages.join(', ')}"
    end
  end

  def clear_referrer
    return unless find_user_safely

    if @user.update(referrer_id: nil)
      redirect_to admin_user_details_path(@user), notice: "Cleared referrer for #{@user.name}"
    else
      redirect_to admin_user_details_path(@user), alert: "Failed to clear referrer"
    end
  end

  def set_out
    return unless find_user_safely

    old_status = @user.status
    if @user.update(status: "out")
      # Log status change
      @user.add_audit_log(
        action: "User marked as out by admin",
        actor: current_user,
        details: {
          "previous_status" => old_status,
          "new_status" => "out"
        }
      )

      render json: { success: true, message: "Marked #{@user.name} as out" }
    else
      render json: { success: false, error: "Failed to mark user as out" }
    end
  end

  def set_active
    return unless find_user_safely

    old_status = @user.status
    if @user.update(status: "working")
      # Log status change
      @user.add_audit_log(
        action: "User marked as active by admin",
        actor: current_user,
        details: {
          "previous_status" => old_status,
          "new_status" => "working"
        }
      )

      render json: { success: true, message: "Marked #{@user.name} as active" }
    else
      render json: { success: false, error: "Failed to mark user as active" }
    end
  end

  def set_banned
    return unless find_user_safely

    old_status = @user.status
    if @user.update(status: "banned")
      # Log status change
      @user.add_audit_log(
        action: "User banned by admin",
        actor: current_user,
        details: {
          "previous_status" => old_status,
          "new_status" => "banned"
        }
      )

      render json: { success: true, message: "Banned #{@user.name}" }
    else
      render json: { success: false, error: "Failed to ban user" }
    end
  end

  def destroy_user
    # Require super admin privileges
    unless current_user.super_admin?
      redirect_to admin_user_details_path(params[:id]), alert: "Only super admins can delete users."
      return
    end

    user = User.find(params[:id])
    user_name = user.name

    # Prevent deletion of super admins
    if user.super_admin?
      redirect_to admin_user_details_path(user), alert: "Cannot delete super admin users."
      return
    end

    # Prevent deletion of the current user
    if user == current_user
      redirect_to admin_user_details_path(user), alert: "Cannot delete your own account."
      return
    end

    # Manually delete associated records to avoid autoloading issues
    begin
      user.shop_purchases.destroy_all if user.respond_to?(:shop_purchases)
    rescue => e
      Rails.logger.warn "Could not delete shop purchases for user #{user.id}: #{e.message}"
    end

    user.destroy
    redirect_to admin_users_path, notice: "User #{user_name} has been deleted."
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_users_path, alert: "User not found."
  end

  def weekly_overview
    # Find all weeks that have projects by calculating week numbers for all projects
    project_weeks = Project.includes(:user).map do |project|
      view_context.week_number_for_date(project.created_at)
    end.uniq.compact.sort.reverse

    # If no projects exist, default to current week or at least week 1
    if project_weeks.empty?
      current_week = [ view_context.current_week_number, 1 ].max
      @available_weeks = [ current_week ]
    else
      @available_weeks = project_weeks
    end

    # Set selected week - default to previous week, or most recent week with projects, or from params
    @selected_week = if params[:week].present?
      params[:week].to_i
    else
      current_week = view_context.current_week_number
      previous_week = current_week - 1
      # Use previous week if it exists in available weeks, otherwise use most recent
      @available_weeks.include?(previous_week) ? previous_week : (@available_weeks.first || 1)
    end

    # Get week date range
    week_range = view_context.week_date_range(@selected_week)

    if week_range
      week_start_date = Date.parse(week_range[0])
      week_end_date = Date.parse(week_range[1])

      # Get all users, optionally filtered by status
      @users = User.all.includes(:meeple, :address)

      # Apply user status filter if provided
      if params[:user_status].present? && %w[new working out banned all].include?(params[:user_status])
        @user_status_filter = params[:user_status]
        if @user_status_filter != "all"
          @users = @users.where(status: @user_status_filter)
        end
      else
        @user_status_filter = "all"  # Default to showing all users
      end

      # Handle show hidden projects checkbox - all users respect this setting
      @show_hidden = params[:show_hidden] == "1"
      
      # Pre-fetch all projects for the selected week to avoid N+1 queries
      if @show_hidden
        # Show all projects including hidden ones
        week_projects = Project.where(
          user_id: @users.pluck(:id),
          created_at: week_start_date.beginning_of_day..week_end_date.end_of_day
        ).includes(:user)
      else
        # Show only visible projects for ALL users (including super admins)
        week_projects = Project.visible.where(
          user_id: @users.pluck(:id),
          created_at: week_start_date.beginning_of_day..week_end_date.end_of_day
        ).includes(:user)
      end

      # Group projects by user_id for efficient lookup
      projects_by_user = week_projects.group_by(&:user_id)

      # Pre-fetch votes for past weeks to avoid N+1 queries
      vote_averages = {}
      current_week = view_context.current_week_number
      # A week is in the past (voting has started) if it's less than the current week
      # This includes negative weeks (-1, -2, etc.) which are definitely in the past
      week_is_past = @selected_week < current_week
      if week_is_past
        project_ids = week_projects.pluck(:id)
        if project_ids.any?
          vote_data = Vote.joins(:ballot)
                         .where(project_id: project_ids, voted: true)
                         .group(:project_id)
                         .average(:star_count)

          vote_averages = vote_data.transform_values { |avg| avg.to_f.round(2) }
        end
      end

      @user_data = {}

      @users.each do |user|
        # Get project for this user from the pre-fetched data
        project = projects_by_user[user.id]&.first

        # Calculate time spent on project for this week
        time_seconds = if project
          view_context.user_hackatime_time_for_projects(user, [ project ], week_range)
        else
          0
        end

        # Get average score from pre-fetched data
        average_score = project ? vote_averages[project.id] : nil

        @user_data[user.id] = {
          user: user,
          project: project,
          time_seconds: time_seconds,
          time_readable: view_context.format_time_from_seconds(time_seconds),
          average_score: average_score,
          fraud_status: project&.fraud_status,
          fraud_reasoning: project&.fraud_reasoning
        }
      end

      # Apply status filter - default to pending_voting if no status specified
      @status_filter = params[:status].present? ? params[:status] : "pending_voting"
      status_filter = @status_filter

      @user_data = @user_data.select do |user_id, data|
        case status_filter
        when "no_project"
          data[:project].nil?
        when "building", "submitted", "pending_voting", "finished"
          data[:project]&.status == status_filter
        when "all"
          true
        else
          data[:project]&.status == "pending_voting" # fallback to pending_voting
        end
      end

      # Apply fraud status filter (only available to fraud team members)
      if current_user&.can_access_fraud_dashboard?
        @fraud_status_filter = params[:fraud_status].present? ? params[:fraud_status] : "good_and_unchecked"
        fraud_status_filter = @fraud_status_filter

        @user_data = @user_data.select do |user_id, data|
          case fraud_status_filter
          when "unchecked", "sus", "fraud", "good"
            data[:project]&.fraud_status == fraud_status_filter
          when "good_and_unchecked"
            data[:project]&.fraud_status.in?(["good", "unchecked"])
          when "all"
            true
          else
            true # no filter applied if invalid fraud status
          end
        end
      end

      # Pagination for weekly overview
      @total_users = @user_data.count
      @per_page = 25
      @current_page = (params[:page] || 1).to_i
      @total_pages = (@total_users.to_f / @per_page).ceil

      # Convert to array and paginate
      user_data_array = @user_data.to_a
      start_index = (@current_page - 1) * @per_page
      end_index = start_index + @per_page - 1
      @user_data = user_data_array[start_index..end_index].to_h
    else
      @user_data = {}
      @total_users = 0
      @per_page = 25
      @current_page = 1
      @total_pages = 0
    end
  end

  def weekly_overview_user
    @selected_week = params[:week].to_i
    @user = User.find(params[:user_id])

    # Get week date range
    week_range = view_context.week_date_range(@selected_week)

    if week_range
      week_start_date = Date.parse(week_range[0])
      week_end_date = Date.parse(week_range[1])

      # Find project for this specific week
      @project = @user.projects.where(
        created_at: week_start_date.beginning_of_day..week_end_date.end_of_day
      ).first

      # Calculate time spent on project for this week
      @time_seconds = if @project
        # Use project's effective time range instead of standard week range
        view_context.user_hackatime_time_for_projects(@user, [ @project ], @project.effective_time_range)
      else
        0
      end
      @time_readable = view_context.format_time_from_seconds(@time_seconds)

      # Get votes for this project
      @votes = if @project
        Vote.joins(:ballot).includes(ballot: :user).where(project: @project).order("ballots.created_at DESC")
      else
        []
      end

      # Calculate average score (only from cast votes)
      cast_votes = @votes.where(voted: true)
      @average_score = cast_votes.any? ? cast_votes.average(:star_count).to_f.round(2) : nil

      # Calculate raw hours for the hour override default
      @raw_hours = (@time_seconds / 3600.0).round(2)

      # Calculate suggested coin amount (hours * average score)
      @suggested_coins = if @average_score && @raw_hours > 0
        (@raw_hours * @average_score).round
      else
        0
      end

      # Get user's address for airtable submission
      @address = @user.address

      # Check if project has been submitted to airtable
      @submitted_to_airtable = @project&.in_airtable? || false
    else
      redirect_to admin_weekly_overview_path, alert: "Invalid week selected."
    end
  end

  def update_user_coins
    @user = User.find(params[:user_id])
    @selected_week = params[:week].to_i
    use_calculated_amount = params[:use_calculated] == "true"
    
    # Get week date range to find the project
    week_range = view_context.week_date_range(@selected_week)
    week_start_date = Date.parse(week_range[0])
    week_end_date = Date.parse(week_range[1])

    # Find project for this specific week
    project = @user.projects.where(
      created_at: week_start_date.beginning_of_day..week_end_date.end_of_day
    ).first

    unless project
      render json: { success: false, error: "No project found for this user in week #{@selected_week}" }
      return
    end

    # Calculate coins using saved multiplier if requested, otherwise use manual amount
    if use_calculated_amount
      # Calculate based on project's stored multiplier
      time_seconds = view_context.user_hackatime_time_for_projects(@user, [project], project.effective_time_range)
      raw_hours = (time_seconds / 3600.0).round(2)
      
      # Get votes for average score calculation
      votes = Vote.joins(:ballot).includes(ballot: :user).where(project: project)
      cast_votes = votes.where(voted: true)
      average_score = cast_votes.any? ? cast_votes.average(:star_count).to_f.round(2) : 0
      
      # Use stored multiplier or default to 2.0
      multiplier = project.reviewer_multiplier || 2.0
      base_coins = (raw_hours * average_score).round
      calculated_coins = (base_coins * multiplier).round
      
      coins_to_add = calculated_coins
    else
      # Use manual amount from form
      coins_to_add = params[:coins].to_i
    end

    current_coins = @user.coins || 0
    new_coins = current_coins + coins_to_add

    ActiveRecord::Base.transaction do
      # Update user's coin balance
      if @user.update(coins: new_coins)
        # Update project's coin value
        project.skip_screenshot_validation!
        current_coin_value = project.coin_value || 0
        new_coin_value = current_coin_value + coins_to_add
        project.update!(coin_value: new_coin_value)

        # Send Slack notification if project has reviewer feedback and coins were added
        if coins_to_add > 0 && project.reviewer_feedback.present?
          SlackNotificationService.new.send_reviewer_feedback_notification(project)
        end

        action_word = coins_to_add > 0 ? "Added" : "Removed"
        calculation_note = use_calculated_amount ? 
          " (calculated: #{raw_hours}h × #{average_score} score × #{multiplier} multiplier)" : 
          " (manual entry)"
        
        render json: {
          success: true,
          message: "#{action_word} #{coins_to_add.abs} coins #{coins_to_add > 0 ? 'to' : 'from'} #{@user.name}#{calculation_note}. New balance: #{new_coins}, project value: #{new_coin_value}",
          new_user_balance: new_coins,
          new_project_coin_value: new_coin_value
        }
      else
        render json: { success: false, error: "Failed to update coin balance" }
      end
    end
  rescue => e
    render json: { success: false, error: "Error updating coins: #{e.message}" }
  end

  def save_reviewer_multiplier
    @user = User.find(params[:user_id])
    @selected_week = params[:week].to_i
    multiplier = params[:multiplier].to_f

    # Get week date range to find the project
    week_range = view_context.week_date_range(@selected_week)
    week_start_date = Date.parse(week_range[0])
    week_end_date = Date.parse(week_range[1])

    # Find project for this specific week
    project = @user.projects.where(
      created_at: week_start_date.beginning_of_day..week_end_date.end_of_day
    ).first

    if project
      # Skip screenshot validation when updating reviewer multiplier
      project.skip_screenshot_validation!

      if project.update(reviewer_multiplier: multiplier)
        render json: {
          success: true,
          message: "Saved reviewer multiplier #{multiplier} for #{project.name}"
        }
      else
        render json: { success: false, error: "Failed to save reviewer multiplier" }
      end
    else
      render json: { success: false, error: "No project found for this user in week #{@selected_week}" }
    end
  rescue => e
    render json: { success: false, error: "Error saving reviewer multiplier: #{e.message}" }
  end

  def update_project_status_admin
    @user = User.find(params[:user_id])
    @selected_week = params[:week].to_i
    new_status = params[:status]

    # Get week date range to find the project
    week_range = view_context.week_date_range(@selected_week)
    week_start_date = Date.parse(week_range[0])
    week_end_date = Date.parse(week_range[1])

    # Find project for this specific week
    project = @user.projects.where(
      created_at: week_start_date.beginning_of_day..week_end_date.end_of_day
    ).first

    unless %w[building submitted pending_voting finished].include?(new_status)
      render json: { success: false, error: "Invalid status" }
      return
    end

    if project
      # Skip screenshot validation when updating status
      project.skip_screenshot_validation!
      old_status = project.status

      if project.update(status: new_status)
        # Add audit log entry for status change
        @user.add_audit_log(
          action: "Project status updated",
          actor: current_user,
          details: {
            "project_name" => project.name,
            "project_id" => project.id,
            "old_status" => old_status,
            "new_status" => new_status
          }
        )

        render json: {
          success: true,
          message: "Updated #{project.name} status from #{old_status} to #{new_status}"
        }
      else
        render json: { success: false, error: "Failed to update project status" }
      end
    else
      render json: { success: false, error: "No project found for this user in week #{@selected_week}" }
    end
  rescue => e
    render json: { success: false, error: "Error updating project status: #{e.message}" }
  end

  def update_reviewer_feedback
    @user = User.find(params[:user_id])
    @selected_week = params[:week].to_i
    reviewer_feedback = params[:reviewer_feedback]

    # Get week date range to find the project
    week_range = view_context.week_date_range(@selected_week)
    week_start_date = Date.parse(week_range[0])
    week_end_date = Date.parse(week_range[1])

    # Find project for this specific week
    project = @user.projects.where(
      created_at: week_start_date.beginning_of_day..week_end_date.end_of_day
    ).first

    if project
      # Skip screenshot validation when updating reviewer feedback
      project.skip_screenshot_validation!

      if project.update(reviewer_feedback: reviewer_feedback)
        # Add audit log entry for project review
        @user.add_audit_log(
          action: "Project reviewed",
          actor: current_user,
          details: {
            "project_name" => project.name,
            "project_id" => project.id,
            "reviewer_feedback" => reviewer_feedback,
            "coin_value" => project.coin_value || 0
          }
        )
        
        # Don't send Slack notification here - it will be sent when coins are awarded
        
        render json: {
          success: true,
          message: "Reviewer feedback updated for #{@user.name}'s project"
        }
      else
        render json: { success: false, error: "Failed to update reviewer feedback" }
      end
    else
      render json: { success: false, error: "No project found for this user in week #{@selected_week}" }
    end
  rescue => e
    render json: { success: false, error: "Error updating reviewer feedback: #{e.message}" }
  end

  def update_project_coin_value
    @project = Project.find(params[:project_id])
    new_coin_value = params[:coin_value].to_f

    @project.skip_screenshot_validation!
    if @project.update(coin_value: new_coin_value)
      render json: {
        success: true,
        message: "Updated #{@project.name}'s coin value to #{new_coin_value}"
      }
    else
      render json: { success: false, error: "Failed to update project coin value" }
    end
  rescue => e
    render json: { success: false, error: "Error updating project coin value: #{e.message}" }
  end

  def update_project_created_date
    @project = Project.find(params[:project_id])
    new_created_date = params[:created_date]

    begin
      parsed_date = Date.parse(new_created_date)
      @project.skip_screenshot_validation!
      if @project.update(created_at: parsed_date)
        render json: {
          success: true,
          message: "Updated #{@project.name}'s created date to #{parsed_date.strftime('%B %d, %Y')}"
        }
      else
        render json: { success: false, error: "Failed to update project created date" }
      end
    rescue ArgumentError
      render json: { success: false, error: "Invalid date format. Please use YYYY-MM-DD format." }
    end
  rescue => e
    render json: { success: false, error: "Error updating project created date: #{e.message}" }
  end

  def submit_to_airtable
    @user = User.find(params[:user_id])
    @selected_week = params[:week].to_i

    # Get week date range
    week_range = view_context.week_date_range(@selected_week)
    week_start_date = Date.parse(week_range[0])
    week_end_date = Date.parse(week_range[1])

    # Find project for this specific week
    @project = @user.projects.where(
      created_at: week_start_date.beginning_of_day..week_end_date.end_of_day
    ).first

    unless @project
      redirect_to admin_weekly_overview_user_path(@selected_week, @user.id), alert: "No project found for this user in week #{@selected_week}."
      return
    end

    # Get parameters from the form
    hour_override = params[:hour_override].to_f
    justification = params[:justification]

    begin
      # Extract GitHub username from repo URL
      github_username = extract_github_username(@project.repo_url)

      # Calculate time spent
      time_seconds = view_context.user_hackatime_time_for_projects(@user, [ @project ], week_range)
      hours_estimate = (time_seconds / 3600.0).round(2)

      # Prepare override hours justification (combine existing logs with new justification)
      override_justification = build_override_justification(@project, justification)

      # Submit to Airtable
      airtable_response = submit_project_to_airtable({
        code_url: @project.repo_url,
        playable_url: @project.demo_url,
        first_name: @user.address&.first_name,
        last_name: @user.address&.last_name,
        email: @user.email,
        screenshot: (@project.screenshot.attached? && @project.screenshot_valid?) ? [ {
          url: url_for(@project.screenshot),
          filename: @project.screenshot.filename.to_s
        } ] : nil,
        description: @project.description,
        github_username: github_username,
        address_line_1: @user.address&.line_one,
        address_line_2: @user.address&.line_two,
        city: @user.address&.city,
        state: @user.address&.state,
        country: @user.address&.country,
        zip: @user.address&.postcode,
        birthday: @user.address&.birthday,
        override_hours: hour_override > 0 ? hour_override : nil,
        override_justification: override_justification,
        slack_username: @user.name,
        hours_estimate: hours_estimate,
        idv_rec: @user.idv_rec,
        shipping_name: @user.address&.shipping_name
      })

      if airtable_response[:success]
        # Skip screenshot validation for Airtable updates
        @project.skip_screenshot_validation!

        # Mark project as submitted to airtable (but don't automatically set to finished)
        @project.update!(in_airtable: true)

        # Add log entry
        log_entry = {
          timestamp: Time.current.iso8601,
          old_status: @project.status,
          new_status: @project.status,
          reviewer_id: current_user.id,
          reviewer_name: current_user.name,
          message: "Submitted to Airtable with #{hour_override > 0 ? "#{hour_override}h override" : "no override"}. #{justification}"
        }

        new_logs = @project.logs + [ log_entry ]
        @project.update!(logs: new_logs)

        redirect_to admin_weekly_overview_user_path(@selected_week, @user.id), notice: "Successfully submitted project to Airtable!"
      else
        redirect_to admin_weekly_overview_user_path(@selected_week, @user.id), alert: "Failed to submit to Airtable: #{airtable_response[:error]}"
      end
    rescue => e
      Rails.logger.error "Error submitting to Airtable: #{e.message}"
      redirect_to admin_weekly_overview_user_path(@selected_week, @user.id), alert: "Error submitting to Airtable: #{e.message}"
    end
  end

  def shop_purchases
    begin
      @purchases = ShopPurchase.includes(:user)
                              .order(purchased_at: :desc)

      # Filter by fulfillment status if requested
      if params[:fulfilled] == "false"
        @purchases = @purchases.unfulfilled
      elsif params[:fulfilled] == "true"
        @purchases = @purchases.fulfilled
      end

      # Filter by item name if requested
      if params[:item_name].present?
        @purchases = @purchases.by_item(params[:item_name])
      end

      # Filter by digital status if requested
      if params[:digital].present?
        if params[:digital] == "true"
          # Show only digital physical items
          digital_item_names = PhysicalItem.where(digital: true).pluck(:name)
          @purchases = @purchases.where(item_name: digital_item_names)
        elsif params[:digital] == "false"
          # Show only non-digital items (exclude digital physical items)
          digital_item_names = PhysicalItem.where(digital: true).pluck(:name)
          @purchases = @purchases.where.not(item_name: digital_item_names)
        end
        # "all" or empty - no filter applied
      end
    rescue NameError => e
      Rails.logger.error "Could not load ShopPurchase model: #{e.message}"
      @purchases = []
      redirect_to admin_path, alert: "Shop purchases feature is temporarily unavailable."
      return
    end

    # Filter by user name if requested
    if params[:user_name].present?
      escaped_user = ActiveRecord::Base.connection.quote_string(params[:user_name])
      @purchases = @purchases.joins(:user).where("users.name ILIKE ?", "%#{escaped_user}%")
    end
  end

  def shop_purchase_details
    begin
      @purchase = ShopPurchase.includes(:user).find(params[:id])
    rescue NameError => e
      Rails.logger.error "Could not load ShopPurchase model: #{e.message}"
      redirect_to admin_path, alert: "Shop purchases feature is temporarily unavailable."
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_shop_purchases_path, alert: "Purchase not found."
    end
  end

  def update_purchase_fulfillment
    begin
      @purchase = ShopPurchase.find(params[:id])

      if @purchase.update(fulfilled: params[:fulfilled] == "true")
        redirect_to admin_shop_purchases_path, notice: "Purchase fulfillment status updated successfully."
      else
        redirect_to admin_shop_purchases_path, alert: "Failed to update fulfillment status."
      end
    rescue NameError => e
      Rails.logger.error "Could not load ShopPurchase model: #{e.message}"
      redirect_to admin_path, alert: "Shop purchases feature is temporarily unavailable."
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_shop_purchases_path, alert: "Purchase not found."
    end
  end

  def delete_shop_purchase
    begin
      @purchase = ShopPurchase.find(params[:id])
    user = @purchase.user
    user_name = user.name
    item_name = @purchase.item_name

    # Handle special item effects before deleting
    case item_name
    when "Unlock Orange Meeple"
      # Remove orange meeple color from user's unlocked colors
      if user.meeple&.color_unlocked?("orange")
        # If user currently has orange selected, change to blue first
        if user.meeple.color == "orange"
          user.meeple.update!(color: "blue")
        end
        # Remove orange from unlocked colors
        user.meeple.relock_color("orange")
      end
    when "Mercenary"
      # Mercenaries don't have permanent effects, so no reversal needed
    when "Random Sticker"
      # Random stickers don't have permanent effects, so no reversal needed
    end

      @purchase.destroy!
      redirect_to admin_shop_purchases_path, notice: "Purchase '#{item_name}' by #{user_name} has been deleted successfully."
    rescue NameError => e
      Rails.logger.error "Could not load ShopPurchase model: #{e.message}"
      redirect_to admin_path, alert: "Shop purchases feature is temporarily unavailable."
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_shop_purchases_path, alert: "Purchase not found."
    end
  end

  def refund_shop_purchase
    begin
      @purchase = ShopPurchase.find(params[:id])
    user = @purchase.user
    user_name = user.name
    item_name = @purchase.item_name
    coins_to_refund = @purchase.coins_spent

    # Handle special item effects before refunding
    case item_name
    when "Unlock Orange Meeple"
      # Remove orange meeple color from user's unlocked colors
      if user.meeple&.color_unlocked?("orange")
        # If user currently has orange selected, change to blue first
        if user.meeple.color == "orange"
          user.meeple.update!(color: "blue")
        end
        # Remove orange from unlocked colors
        user.meeple.relock_color("orange")
      end
    when "Mercenary"
      # Mercenaries don't have permanent effects, so no reversal needed
    when "Random Sticker"
      # Random stickers don't have permanent effects, so no reversal needed
    end

    # Refund the coins to the user
    current_coins = user.coins || 0
    user.update!(coins: current_coins + coins_to_refund)

      # Delete the purchase
      @purchase.destroy!

      redirect_to admin_shop_purchases_path, notice: "Purchase '#{item_name}' by #{user_name} has been refunded and deleted. #{coins_to_refund} coins have been returned to #{user_name}."
    rescue NameError => e
      Rails.logger.error "Could not load ShopPurchase model: #{e.message}"
      redirect_to admin_path, alert: "Shop purchases feature is temporarily unavailable."
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_shop_purchases_path, alert: "Purchase not found."
    end
  end

  def analytics
    # User funnel data
    total_users = User.count
    users_with_address = User.joins(:address).count
    users_with_projects = User.joins(:projects).distinct.count

    # Users with hackatime attached to a project
    users_with_hackatime = User.joins(:projects)
                               .where("json_array_length(projects.hackatime_projects) > 0")
                               .distinct.count

    # Pre-fetch hackatime data for users to avoid N+1 queries
    users_with_hackatime_ids = User.joins(:projects)
                                   .where("json_array_length(projects.hackatime_projects) > 0")
                                   .distinct.pluck(:id)

    # Create a cache of hackatime data for each user
    user_hackatime_cache = {}

    # Preload all users and their projects with hackatime data to avoid N+1 queries
    users_with_hackatime_objects = User.includes(:projects).where(id: users_with_hackatime_ids)

    # Preload all projects with hackatime data for these users
    projects_with_hackatime = Project.where(user_id: users_with_hackatime_ids)
                                   .where("json_array_length(hackatime_projects) > 0")
                                   .includes(:user)

    # Group projects by user_id for efficient lookup
    projects_by_user = projects_with_hackatime.group_by(&:user_id)

    users_with_hackatime_objects.each do |user|
      user_hackatime_cache[user.id] = {}

      # Get all projects for this user with hackatime data from preloaded data
      user_projects = projects_by_user[user.id] || []
      user_projects.each do |project|
        range = project.effective_time_range
        next unless range

        cache_key = [ range[0], range[1] ]
        unless user_hackatime_cache[user.id][cache_key]
          user_hackatime_cache[user.id][cache_key] = view_context.hackatime_projects_for_user(user, *range)
        end
      end
    end

    # Users who've submitted at least one project
    users_submitted = User.joins(:projects)
                         .where(projects: { status: [ "submitted", "pending_voting", "finished" ] })
                         .distinct.count

    # Pre-fetch all projects with hackatime data to avoid N+1 queries
    all_projects_with_hackatime = Project.includes(:user)
                                        .where("json_array_length(hackatime_projects) > 0")

    # Group projects by week for efficient processing
    projects_by_week = {}
    all_projects_with_hackatime.each do |project|
      week_num = view_context.week_number_for_date(project.created_at.to_date)
      next unless week_num && week_num >= 4 && week_num <= 13

      projects_by_week[week_num] ||= []
      projects_by_week[week_num] << project
    end

    # Users who've completed each week 4-13 (project with 10+ hours)
    users_completed_by_week = {}
    weeks_4_to_13 = (4..13).to_a

    weeks_4_to_13.each do |week_num|
      week_projects = projects_by_week[week_num] || []

      completed_users = 0
      week_projects.each do |project|
        next unless project.user

        # Use cached hackatime data instead of making individual API calls
        range = project.effective_time_range
        next unless range

        cache_key = [ range[0], range[1] ]
        cached_data = user_hackatime_cache.dig(project.user.id, cache_key) || []

        # Calculate time for this project using cached data
        total_seconds = 0
        project.hackatime_projects.each do |project_name|
          match = cached_data.find { |p| p["name"].to_s == project_name.to_s }
          total_seconds += match&.dig("total_seconds") || 0
        end

        if total_seconds >= 36000 # 10 hours
          completed_users += 1
        end
      end

      users_completed_by_week[week_num] = completed_users
    end

    @funnel_data = {
      total_users: total_users,
      users_with_address: users_with_address,
      users_with_projects: users_with_projects,
      users_with_hackatime: users_with_hackatime,
      users_submitted: users_submitted,
      users_completed_by_week: users_completed_by_week
    }

    # Total users over time (weekly snapshots) - optimized to avoid N+1
    @user_growth_data = []
    current_week = view_context.current_week_number

    # Get all users ordered by creation date for cumulative counting
    all_users_by_date = User.order(:created_at).pluck(:created_at)

    (1..current_week).each do |week_num|
      week_range = view_context.week_date_range(week_num)
      next unless week_range

      week_end = Date.parse(week_range[1]).end_of_day
      # Count users created up to this week end using in-memory data
      user_count_at_week_end = all_users_by_date.count { |created_at| created_at <= week_end }

      @user_growth_data << {
        week: week_num,
        users: [ user_count_at_week_end, 1000 ].min # Cap at 1000
      }
    end

    # Group all projects by week for hours calculation
    all_projects_by_week = {}
    all_projects_with_hackatime.each do |project|
      week_num = view_context.week_number_for_date(project.created_at.to_date)
      next unless week_num && week_num >= 1 && week_num <= current_week

      all_projects_by_week[week_num] ||= []
      all_projects_by_week[week_num] << project
    end

    # Total hours spent per week (with breakdown by project status)
    @hours_per_week_data = []

    (1..current_week).each do |week_num|
      week_projects = all_projects_by_week[week_num] || []

      total_seconds = 0
      submitted_seconds = 0
      airtable_synced_seconds = 0
      total_coins = 0

      week_projects.each do |project|
        next unless project.user

        # Use cached hackatime data instead of making individual API calls
        range = project.effective_time_range
        next unless range

        cache_key = [ range[0], range[1] ]
        cached_data = user_hackatime_cache.dig(project.user.id, cache_key) || []

        # Calculate time for this project using cached data
        project_seconds = 0
        project.hackatime_projects.each do |project_name|
          match = cached_data.find { |p| p["name"].to_s == project_name.to_s }
          project_seconds += match&.dig("total_seconds") || 0
        end

        total_seconds += project_seconds

        # Add to submitted hours if project is submitted, pending_voting, or finished
        if project.status.in?([ "submitted", "pending_voting", "finished" ])
          submitted_seconds += project_seconds
          
          # Only add coin value for submitted projects (divided by 10 to keep bars reasonable)
          total_coins += (project.coin_value || 0) / 10.0
        end
        
        # Add to Airtable synced hours if project has been synced to Airtable AND is finished
        if project.in_airtable? && project.status == "finished"
          airtable_synced_seconds += project_seconds
        end
      end

      total_hours = (total_seconds / 3600.0).round(1)
      submitted_hours = (submitted_seconds / 3600.0).round(1)
      airtable_synced_hours = (airtable_synced_seconds / 3600.0).round(1)

      @hours_per_week_data << {
        week: week_num,
        total_hours: total_hours,
        submitted_hours: submitted_hours,
        airtable_synced_hours: airtable_synced_hours,
        total_coins: total_coins.round(1)
      }
    end

    # Daily hours spent on Siege projects
    @daily_hours_data = []

    # Get the date range for the last 30 days
    end_date = Date.current
    start_date = end_date - 29.days

    (start_date..end_date).each do |date|
      daily_seconds = 0

      # Find all projects that were active on this date
      all_projects_with_hackatime.each do |project|
        next unless project.user

        # Check if project was active on this date
        project_start = project.created_at.to_date
        project_end = project.updated_at.to_date

        next unless date >= project_start && date <= project_end

        # Use cached hackatime data
        range = project.effective_time_range
        next unless range

        cache_key = [ range[0], range[1] ]
        cached_data = user_hackatime_cache.dig(project.user.id, cache_key) || []

        # Calculate time for this project on this specific date
        project.hackatime_projects.each do |project_name|
          match = cached_data.find { |p| p["name"].to_s == project_name.to_s }
          next unless match

          # Get daily breakdown from hackatime data
          daily_data = match["daily_data"] || []
          day_entry = daily_data.find { |d| Date.parse(d["date"]) == date }

          if day_entry
            daily_seconds += day_entry["total_seconds"] || 0
          end
        end
      end

      daily_hours = (daily_seconds / 3600.0).round(1)

      @daily_hours_data << {
        date: date.strftime("%Y-%m-%d"),
        display_date: date.strftime("%m/%d"),
        hours: daily_hours
      }
    end
  end

  def destroy_project
    @project = Project.find(params[:id])
    
    if @project.destroy
      redirect_to admin_projects_path, notice: "Project '#{@project.name}' was successfully deleted."
    else
      redirect_to admin_projects_path, alert: "Failed to delete project '#{@project.name}'."
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_projects_path, alert: "Project not found."
  end

  def hide_project
    unless current_user&.super_admin?
      redirect_to admin_projects_path, alert: "Access denied. Super admin privileges required."
      return
    end

    @project = Project.find(params[:id])
    
    # Skip screenshot validation when hiding project
    @project.skip_screenshot_validation!
    
    if @project.update(hidden: true)
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_projects_path, notice: "Project '#{@project.name}' has been hidden." }
        format.json { render json: { success: true, message: "Project hidden successfully" } }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_projects_path, alert: "Failed to hide project." }
        format.json { render json: { success: false, error: "Failed to hide project" } }
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_back fallback_location: admin_projects_path, alert: "Project not found." }
      format.json { render json: { success: false, error: "Project not found" } }
    end
  end

  def unhide_project
    unless current_user&.super_admin?
      redirect_to admin_projects_path, alert: "Access denied. Super admin privileges required."
      return
    end

    @project = Project.find(params[:id])
    
    # Skip screenshot validation when unhiding project
    @project.skip_screenshot_validation!
    
    if @project.update(hidden: false)
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_projects_path, notice: "Project '#{@project.name}' has been unhidden." }
        format.json { render json: { success: true, message: "Project unhidden successfully" } }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_projects_path, alert: "Failed to unhide project." }
        format.json { render json: { success: false, error: "Failed to unhide project" } }
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_back fallback_location: admin_projects_path, alert: "Project not found." }
      format.json { render json: { success: false, error: "Project not found" } }
    end
  end

  def update_fraud_status
    @project = Project.find(params[:id])

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
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "Project not found" }
  end
   
  private

  def require_admin_access
    unless can_access_admin?
      redirect_to keep_path, alert: "Access denied. Admin privileges required."
    end
  end

  def address_params
    params.require(:address).permit(:first_name, :last_name, :birthday, :shipping_name, :line_one, :line_two, :city, :state, :postcode, :country)
  end

  def ballot_params
    params.require(:ballot).permit(:week, :voted, :reasoning)
  end

  def find_user_safely
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "[Admin] User with ID #{params[:id]} not found, requested by admin #{current_user&.id}"
    respond_to do |format|
      format.html { redirect_to admin_users_path, alert: "User not found." }
      format.json { render json: { error: "User not found" }, status: :not_found }
    end
    nil
  end

  def get_hackatime_trust_status(user)
    return { status: "unknown", value: nil, color: "gray" } unless user.slack_id.present?

    # Use the existing hackatime data cache and extract trust factor
    current_week_number = view_context.current_week_number
    week_range = view_context.week_date_range(current_week_number)

    if week_range
      start_date_str = week_range[0]
      end_date_str = week_range[1]

      # Get the full cached hackatime stats data using the existing helper
      hackatime_data = view_context.hackatime_projects_for_user(user, start_date_str, end_date_str) { |data| data }

      # Extract trust factor from the cached data
      if hackatime_data.respond_to?(:dig) && hackatime_data.present?
        trust_factor = hackatime_data["trust_factor"]

        if trust_factor && trust_factor["trust_value"]
          trust_value = trust_factor["trust_value"]

          case trust_value
          when 0
            { status: "neutral", value: trust_value, color: "blue" }
          when 1
            { status: "banned", value: trust_value, color: "red" }
          when 2
            { status: "trusted", value: trust_value, color: "green" }
          else
            { status: "unknown", value: trust_value, color: "gray" }
          end
        else
          { status: "unknown", value: nil, color: "gray", message: "No trust value in response" }
        end
      else
        { status: "unknown", value: nil, color: "gray", message: "No hackatime data available" }
      end
    else
      { status: "unknown", value: nil, color: "gray", message: "Week range not available" }
    end
  rescue => e
    Rails.logger.error "Failed to get Hackatime trust status for user #{user.id}: #{e.message}"
    { status: "error", value: nil, color: "gray", message: e.message }
  end

  def extract_github_username(repo_url)
    return nil unless repo_url.present?

    # Match various Git hosting service URL patterns and extract username
    # Pattern matches: github.com, gitlab.com, bitbucket.org, codeberg.org, sourceforge.net, dev.azure.com, git.hackclub.app
    if match = repo_url.match(%r{(?:github\.com|gitlab\.com|bitbucket\.org|codeberg\.org|sourceforge\.net|dev\.azure\.com|git\.hackclub\.app)/([^/]+)})
      match[1]
    else
      nil
    end
  end

  def build_override_justification(project, new_justification)
    justifications = []

    # Add existing logs
    if project.logs.any?
      project.logs.each do |log|
        log_entry = []
        log_entry << Time.parse(log["timestamp"]).strftime("%Y-%m-%d")

        # Add reviewer name if available
        if log["reviewer_name"].present?
          log_entry << "by #{log['reviewer_name']}"
        end

        # Add status change if present
        if log["old_status"].present? && log["new_status"].present? && log["old_status"] != log["new_status"]
          log_entry << "Status: #{log['old_status']} → #{log['new_status']}"
        end

        # Add message if present
        if log["message"].present?
          log_entry << log["message"]
        end

        justifications << log_entry.join(" | ")
      end
    end

    # Add new justification at the top
    if new_justification.present?
      new_entry = []
      new_entry << Time.current.strftime("%Y-%m-%d")
      new_entry << "by #{current_user.name}"
      new_entry << new_justification

      # Put new entry at the top, then add line breaks, then historical logs
      all_entries = [ new_entry.join(" | "), "", "" ] + justifications
      return all_entries.join("\n")
    end

    justifications.join("\n")
  end

  def submit_project_to_airtable(data)
    begin
      # Get Airtable credentials
      api_key = Rails.application.credentials.dig(:airtable, :api_key)
      base_id = Rails.application.credentials.dig(:airtable, :base_id)
      table_id = Rails.application.credentials.dig(:airtable, :table_id) || "Projects"

      unless api_key && base_id
        Rails.logger.error "Airtable credentials not configured"
        return { success: false, error: "Airtable credentials not configured" }
      end

      # Prepare data for Airtable
      airtable_data = {
        "Code URL" => data[:code_url],
        "Playable URL" => data[:playable_url],
        "First Name" => data[:first_name],
        "Last Name" => data[:last_name],
        "Email" => data[:email],
        "Screenshot" => data[:screenshot],
        "Description" => data[:description],
        "GitHub Username" => data[:github_username],
        "Address (Line 1)" => data[:address_line_1],
        "Address (Line 2)" => data[:address_line_2],
        "City" => data[:city],
        "State / Province" => data[:state],
        "Country" => data[:country],
        "ZIP / Postal Code" => data[:zip],
        "Birthday" => data[:birthday],
        "Optional - Override Hours Spent" => data[:override_hours],
        "Optional - Override Hours Spent Justification" => data[:override_justification],
        "Slack Username" => data[:slack_username],
        "Hours estimate" => data[:hours_estimate],
        "idv_rec" => data[:idv_rec],
        "Shipping Name" => data[:shipping_name]
      }.compact

      # Make HTTP request to Airtable API
      uri = URI("https://api.airtable.com/v0/#{base_id}/#{table_id}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = { fields: airtable_data }.to_json

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        response_data = JSON.parse(response.body)
        Rails.logger.info "Successfully submitted to Airtable: #{response_data['id']}"
        { success: true, id: response_data["id"] }
      else
        Rails.logger.error "Airtable API error: #{response.code} - #{response.body}"
        { success: false, error: "HTTP #{response.code}: #{response.body}" }
      end

    rescue => e
      Rails.logger.error "Airtable submission error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: e.message }
    end
  end
  
  private

  def filter_users_by_age(users, min_age, max_age)
    # Convert to integers and validate
    min_age = min_age.to_i if min_age.present?
    max_age = max_age.to_i if max_age.present?

    # Filter users who have addresses with birthdays
    users_with_birthdays = users.joins(:address).where.not(addresses: { birthday: nil })

    # Apply age filters
    if min_age.present? && max_age.present?
      # Both min and max age specified
      min_birthday = Date.current - max_age.years
      max_birthday = Date.current - min_age.years
      users_with_birthdays.where(addresses: { birthday: min_birthday..max_birthday })
    elsif min_age.present?
      # Only minimum age specified
      max_birthday = Date.current - min_age.years
      users_with_birthdays.where("addresses.birthday <= ?", max_birthday)
    elsif max_age.present?
      # Only maximum age specified
      min_birthday = Date.current - max_age.years
      users_with_birthdays.where("addresses.birthday >= ?", min_birthday)
    else
      users_with_birthdays
    end
  end

  def add_cosmetic
    return unless find_user_safely
    cosmetic_id = params[:cosmetic_id]
    
    cosmetic = Cosmetic.find_by(id: cosmetic_id)
    if cosmetic.nil?
      render json: { success: false, error: "Cosmetic not found" }
      return
    end
    
    # Ensure user has a meeple
    meeple = @user.meeple || @user.create_meeple(color: "blue", cosmetics: [])
    
    # Check if cosmetic is already unlocked
    if meeple.unlocked_cosmetics.exists?(cosmetic: cosmetic)
      render json: { success: false, error: "User already has this cosmetic unlocked" }
      return
    end
    
    # Unlock the cosmetic
    meeple.unlock_cosmetic(cosmetic)
    
    # Log the action
    @user.add_audit_log(
      action: "Cosmetic unlocked by admin",
      actor: current_user,
      details: {
        "cosmetic_name" => cosmetic.name,
        "cosmetic_id" => cosmetic.id,
        "cosmetic_type" => cosmetic.type
      }
    )
    
    render json: { 
      success: true, 
      message: "Successfully unlocked #{cosmetic.name} for #{@user.name}" 
    }
  rescue => e
    Rails.logger.error "Error adding cosmetic: #{e.message}"
    render json: { success: false, error: "Failed to add cosmetic" }
  end

  def remove_cosmetic
    return unless find_user_safely
    cosmetic_id = params[:cosmetic_id]
    
    cosmetic = Cosmetic.find_by(id: cosmetic_id)
    if cosmetic.nil?
      render json: { success: false, error: "Cosmetic not found" }
      return
    end
    
    # Check if user has a meeple
    if @user.meeple.nil?
      render json: { success: false, error: "User has no meeple" }
      return
    end
    
    # Find and remove the meeple cosmetic
    meeple_cosmetic = @user.meeple.meeple_cosmetics.find_by(cosmetic: cosmetic)
    if meeple_cosmetic.nil?
      render json: { success: false, error: "User doesn't have this cosmetic" }
      return
    end
    
    # Remove the cosmetic
    meeple_cosmetic.destroy!
    
    # Log the action
    @user.add_audit_log(
      action: "Cosmetic removed by admin",
      actor: current_user,
      details: {
        "cosmetic_name" => cosmetic.name,
        "cosmetic_id" => cosmetic.id,
        "cosmetic_type" => cosmetic.type
      }
    )
    
    render json: { 
      success: true, 
      message: "Successfully removed #{cosmetic.name} from #{@user.name}",
      cosmetic_name: cosmetic.name,
      cosmetic_type: cosmetic.type.capitalize
    }
  rescue => e
    Rails.logger.error "Error removing cosmetic: #{e.message}"
    render json: { success: false, error: "Failed to remove cosmetic" }
  end

end
