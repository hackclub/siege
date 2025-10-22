class CatacombsController < ApplicationController

  def index
    @betting_enabled = Flipper.enabled?(:betting, current_user)
    @current_week = ApplicationController.helpers.current_week_number
    @personal_bet = current_user.personal_bets.find_by(week: @current_week) if current_user
    @global_bet = current_user.global_bets.find_by(week: @current_week) if current_user
    @is_betting_day = (1..4).include?(Date.current.wday)
    
    # Calculate current hours for personal bet if exists
    if @personal_bet
      week_range = ApplicationController.helpers.week_date_range(@current_week)
      if week_range
        projs = ApplicationController.helpers.hackatime_projects_for_user(current_user, *week_range)
        @current_week_seconds = projs.sum { |p| p["total_seconds"] || 0 }
        @current_week_hours = (@current_week_seconds / 3600.0).round(1)
      else
        @current_week_hours = 0
      end
    end
    
    # Calculate current global hours if global bet exists
    if @global_bet
      @current_global_hours = calculate_current_week_global_hours
    end
  end

  private

  def calculate_current_week_global_hours
    calculate_week_global_hours(@current_week)
  end

  public

  def last_week_hours
    # Get previous Siege week number
    current_week = ApplicationController.helpers.current_week_number
    previous_week = current_week - 1
    
    # Calculate hours for the previous week
    total_hours = if previous_week >= 1
      calculate_week_global_hours(previous_week)
    else
      0
    end
    
    render json: { hours: total_hours }
  end
  
  def calculate_week_global_hours(week_number)
    # Match analytics calculation exactly - filter by week_number_for_date
    # Include all projects (even hidden) with hackatime data
    all_projects = Project.unscoped
      .includes(:user)
      .where("json_array_length(hackatime_projects) > 0")
    
    # Filter to only projects in this week with submitted status
    week_projects = all_projects.select do |project|
      project_week = ApplicationController.helpers.week_number_for_date(project.created_at.to_date)
      project_week == week_number &&
        project.status.in?(["submitted", "pending_voting", "waiting_for_review", "finished"])
    end
    
    # Calculate total hours using same logic as analytics
    total_seconds = 0
    week_projects.each do |project|
      next unless project.user
      
      range = project.effective_time_range
      next unless range && range[0] && range[1]
      
      projs = ApplicationController.helpers.hackatime_projects_for_user(project.user, *range)
      
      project.hackatime_projects.each do |project_name|
        match = projs.find { |p| p["name"].to_s == project_name.to_s }
        total_seconds += match&.dig("total_seconds") || 0
      end
    end
    
    (total_seconds / 3600.0).round(1)
  end

  def place_personal_bet
    # Check if betting is enabled
    unless Flipper.enabled?(:betting, current_user)
      render json: { success: false, message: "Betting is not currently available" }, status: :forbidden
      return
    end
    
    # Check if it's Monday-Thursday (1-4 in Ruby's Date.wday, where 0=Sunday, 1=Monday, etc.)
    unless (1..4).include?(Date.current.wday)
      render json: { success: false, message: "Bets can only be placed Monday through Thursday" }, status: :unprocessable_entity
      return
    end
    
    current_week = ApplicationController.helpers.current_week_number
    
    # Check if user already has a bet for this week
    if current_user.personal_bets.exists?(week: current_week)
      render json: { success: false, message: "You already have a personal bet for this week" }, status: :unprocessable_entity
      return
    end
    
    coin_amount = params[:coin_amount].to_i
    hours_goal = params[:hours_goal].to_i
    multiplier = params[:multiplier].to_f
    estimated_payout = (coin_amount * multiplier).floor
    
    # Validate coin amount
    if coin_amount < 1 || coin_amount > 50
      render json: { success: false, message: "Bet amount must be between 1 and 50 coins" }, status: :unprocessable_entity
      return
    end
    
    # Check if user has enough coins
    if current_user.coins < coin_amount
      render json: { success: false, message: "Not enough coins" }, status: :unprocessable_entity
      return
    end
    
    # Create bet and deduct coins
    begin
      ActiveRecord::Base.transaction do
        bet = current_user.personal_bets.create!(
          week: current_week,
          coin_amount: coin_amount,
          estimated_payout: estimated_payout,
          hours_goal: hours_goal
        )
        
        current_user.update!(coins: current_user.coins - coin_amount)
        current_user.add_audit_log(
          action: "placed_personal_bet",
          actor: current_user,
          details: { coin_amount: coin_amount, hours_goal: hours_goal, week: current_week }
        )
      end
      
      render json: { success: true, remaining_coins: current_user.coins }
    rescue => e
      Rails.logger.error "Failed to place personal bet: #{e.message}"
      render json: { success: false, message: "Failed to place bet: #{e.message}" }, status: :unprocessable_entity
    end
  end

  def place_global_bet
    # Check if betting is enabled
    unless Flipper.enabled?(:betting, current_user)
      render json: { success: false, message: "Betting is not currently available" }, status: :forbidden
      return
    end
    
    # Check if it's Monday-Thursday
    unless (1..4).include?(Date.current.wday)
      render json: { success: false, message: "Bets can only be placed Monday through Thursday" }, status: :unprocessable_entity
      return
    end
    
    current_week = ApplicationController.helpers.current_week_number
    
    # Check if user already has a bet for this week
    if current_user.global_bets.exists?(week: current_week)
      render json: { success: false, message: "You already have a global bet for this week" }, status: :unprocessable_entity
      return
    end
    
    coin_amount = params[:coin_amount].to_i
    predicted_hours = params[:predicted_hours].to_f
    multiplier = params[:multiplier].to_f
    estimated_payout = (coin_amount * multiplier).floor
    
    # Validate coin amount
    if coin_amount < 1 || coin_amount > 200
      render json: { success: false, message: "Bet amount must be between 1 and 200 coins" }, status: :unprocessable_entity
      return
    end
    
    # Check if user has enough coins
    if current_user.coins < coin_amount
      render json: { success: false, message: "Not enough coins" }, status: :unprocessable_entity
      return
    end
    
    # Create bet and deduct coins
    begin
      ActiveRecord::Base.transaction do
        bet = current_user.global_bets.create!(
          week: current_week,
          coin_amount: coin_amount,
          estimated_payout: estimated_payout,
          predicted_hours: predicted_hours
        )
        
        current_user.update!(coins: current_user.coins - coin_amount)
        current_user.add_audit_log(
          action: "placed_global_bet",
          actor: current_user,
          details: { coin_amount: coin_amount, predicted_hours: predicted_hours, week: current_week }
        )
      end
      
      render json: { success: true, remaining_coins: current_user.coins }
    rescue => e
      Rails.logger.error "Failed to place global bet: #{e.message}"
      render json: { success: false, message: "Failed to place bet: #{e.message}" }, status: :unprocessable_entity
    end
  end

  def collect_personal_bet
    current_week = ApplicationController.helpers.current_week_number
    bet = current_user.personal_bets.find_by(week: current_week)
    
    unless bet
      render json: { success: false, message: "No personal bet found for this week" }, status: :not_found
      return
    end
    
    if bet.paid_out?
      render json: { success: false, message: "Bet already collected" }, status: :unprocessable_entity
      return
    end
    
    # Check if goal is reached
    week_range = ApplicationController.helpers.week_date_range(current_week)
    if week_range
      projs = ApplicationController.helpers.hackatime_projects_for_user(current_user, *week_range)
      current_seconds = projs.sum { |p| p["total_seconds"] || 0 }
      current_hours = (current_seconds / 3600.0).round(1)
    else
      current_hours = 0
    end
    
    unless current_hours >= bet.hours_goal
      render json: { success: false, message: "Goal not reached yet. You have #{current_hours}h / #{bet.hours_goal}h" }, status: :unprocessable_entity
      return
    end
    
    # Pay out bet
    begin
      ActiveRecord::Base.transaction do
        current_user.update!(coins: current_user.coins + bet.estimated_payout.to_i)
        current_user.add_audit_log(
          action: "collected_personal_bet",
          actor: current_user,
          details: { bet_id: bet.id, payout: bet.estimated_payout.to_i, week: current_week }
        )
        bet.update!(paid_out: true)
      end
      
      render json: { success: true, payout: bet.estimated_payout.to_i, new_balance: current_user.coins }
    rescue => e
      Rails.logger.error "Failed to collect personal bet: #{e.message}"
      render json: { success: false, message: "Failed to collect bet: #{e.message}" }, status: :unprocessable_entity
    end
  end

  def collect_global_bet
    current_week = ApplicationController.helpers.current_week_number
    bet = current_user.global_bets.find_by(week: current_week)
    
    unless bet
      render json: { success: false, message: "No global bet found for this week" }, status: :not_found
      return
    end
    
    if bet.paid_out?
      render json: { success: false, message: "Bet already collected" }, status: :unprocessable_entity
      return
    end
    
    # Check if goal is reached
    current_global_hours = calculate_current_week_global_hours
    
    unless current_global_hours >= bet.predicted_hours
      render json: { success: false, message: "Goal not reached yet. Currently #{current_global_hours}h / #{bet.predicted_hours.to_i}h" }, status: :unprocessable_entity
      return
    end
    
    # Pay out bet
    begin
      ActiveRecord::Base.transaction do
        current_user.update!(coins: current_user.coins + bet.estimated_payout.to_i)
        current_user.add_audit_log(
          action: "collected_global_bet",
          actor: current_user,
          details: { bet_id: bet.id, payout: bet.estimated_payout.to_i, week: current_week }
        )
        bet.update!(paid_out: true)
      end
      
      render json: { success: true, payout: bet.estimated_payout.to_i, new_balance: current_user.coins }
    rescue => e
      Rails.logger.error "Failed to collect global bet: #{e.message}"
      render json: { success: false, message: "Failed to collect bet: #{e.message}" }, status: :unprocessable_entity
    end
  end
end
