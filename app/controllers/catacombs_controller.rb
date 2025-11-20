class CatacombsController < ApplicationController
  before_action :check_user_eligibility, except: [:index]
  before_action :check_betting_window_available, only: [:place_personal_bet, :place_global_bet, :collect_personal_bet, :collect_global_bet]
  before_action :check_shop_window_available, only: [:shop_items, :purchase_shop_item]
  before_action :check_raffle_window_available, only: [:raffle_info, :purchase_raffle_ticket]

  def index
    # Redirect banned users away from catacombs
    if current_user&.banned?
      redirect_to root_path, alert: "You cannot access the catacombs."
      return
    end
    
    @betting_enabled = Flipper.enabled?(:betting, current_user)
    @current_week = ApplicationController.helpers.current_week_number
    @personal_bet = current_user.personal_bets.find_by(week: @current_week) if current_user
    @global_bet = current_user.global_bets.find_by(week: @current_week) if current_user
    @is_betting_day = (1..4).include?(Date.current.wday)
    
    # Check which mystereeple windows are available today
    @available_windows = MystereepleWindow.available_windows_today
    @mystereeple_visible = @available_windows.any?
    
    # Check if user has active bets (for bet progress widget when betting window closed)
    @has_active_bets = @personal_bet.present? || @global_bet.present?
    @betting_window_open = @available_windows.any? { |w| w.window_type == 'betting' } && @betting_enabled
    @show_bet_widget = @has_active_bets && !@betting_window_open
    
    # Pass rune unlock status and current runes to the view
    if current_user
      @ruby_unlocked = current_user.ruby_unlocked
      @emerald_unlocked = current_user.emerald_unlocked
      @amethyst_unlocked = current_user.amethyst_unlocked
      @current_runes = current_user.current_runes
      @user_is_out = current_user.out?
    end
    
    # Calculate current hours for personal bet if exists
    if @personal_bet
      @current_week_hours = @personal_bet.current_hours
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

  def current_progress
    current_week = ApplicationController.helpers.current_week_number
    
    # Calculate personal progress - only count hours from Siege projects
    week_range = ApplicationController.helpers.week_date_range(current_week)
    if week_range
      # Get user's projects for this week
      user_projects = current_user.projects.where("created_at >= ? AND created_at <= ?", week_range[0], week_range[1])
      
      total_seconds = 0
      user_projects.each do |project|
        range = project.effective_time_range
        next unless range && range[0] && range[1]
        
        projs = ApplicationController.helpers.hackatime_projects_for_user(current_user, *range)
        
        project.hackatime_projects.each do |project_name|
          match = projs.find { |p| p["name"].to_s == project_name.to_s }
          total_seconds += match&.dig("total_seconds") || 0
        end
      end
      
      personal_hours = (total_seconds / 3600.0).round(1)
    else
      personal_hours = 0
    end
    
    # Calculate global progress
    global_hours = calculate_week_global_hours(current_week)
    
    render json: { 
      personal_hours: personal_hours,
      global_hours: global_hours
    }
  end

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
    
    # Create bet and deduct coins
    begin
      ActiveRecord::Base.transaction do
        current_user.reload
        
        # Check if user has enough coins inside transaction
        if current_user.coins < coin_amount
          render json: { success: false, message: "Not enough coins" }, status: :unprocessable_entity
          return
        end
        
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
    
    # Create bet and deduct coins
    begin
      ActiveRecord::Base.transaction do
        current_user.reload
        
        # Check if user has enough coins inside transaction
        if current_user.coins < coin_amount
          render json: { success: false, message: "Not enough coins" }, status: :unprocessable_entity
          return
        end
        
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
    unless bet.goal_reached?
      render json: { success: false, message: "Goal not reached yet. You have #{bet.current_hours}h / #{bet.hours_goal}h" }, status: :unprocessable_entity
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
    current_global_hours = calculate_week_global_hours(current_week)
    
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

  def shop_items
    items = MystereepleShopItem.where(enabled: true).map do |item|
      purchased_count = ShopPurchase.where(mystereeple_shop_item_id: item.id).count
      remaining = [item.limit - purchased_count, 0].max
      
      {
        id: item.id,
        name: item.name,
        description: item.description,
        cost: item.cost.to_i,
        limit: item.limit,
        remaining: remaining,
        image_url: item.image.attached? ? url_for(item.image) : nil
      }
    end
    
    render json: { items: items, user_coins: current_user.coins }
  end

  def purchase_shop_item
    item = MystereepleShopItem.find(params[:item_id])
    
    unless item.enabled
      render json: { success: false, message: "Item not available" }, status: :unprocessable_entity
      return
    end
    
    # Check stock
    purchased_count = ShopPurchase.where(mystereeple_shop_item_id: item.id).count
    remaining = item.limit - purchased_count
    
    if remaining <= 0
      render json: { success: false, message: "Item out of stock" }, status: :unprocessable_entity
      return
    end
    
    begin
      ActiveRecord::Base.transaction do
        current_user.reload
        
        # Check coins inside transaction with fresh data
        if current_user.coins < item.cost
          render json: { success: false, message: "Not enough coins" }, status: :unprocessable_entity
          return
        end
        purchase = ShopPurchase.create!(
          user: current_user,
          mystereeple_shop_item_id: item.id,
          coins_spent: item.cost.to_i,
          item_name: item.name,
          purchased_at: Time.current,
          fulfilled: false
        )
        
        current_user.update!(coins: current_user.coins - item.cost.to_i)
        current_user.add_audit_log(
          action: "purchased_mystereeple_item",
          actor: current_user,
          details: { item_id: item.id, item_name: item.name, cost: item.cost.to_i }
        )
      end
      
      render json: { success: true, new_balance: current_user.coins }
    rescue => e
      Rails.logger.error "Failed to purchase shop item: #{e.message}"
      render json: { success: false, message: "Failed to purchase: #{e.message}" }, status: :unprocessable_entity
    end
  end

  # Raffle endpoints
  def raffle_info
    raffle_item_name = "Felt Gingereeple"
    user_tickets = RaffleTicket.for_item(raffle_item_name).unused.where(user: current_user).count
    
    render json: { 
      raffle_item_name: raffle_item_name,
      user_tickets: user_tickets,
      user_coins: current_user.coins
    }
  end

  def purchase_raffle_ticket
    raffle_item_name = "Felt Gingereeple"
    ticket_cost = 1
    
    begin
      ActiveRecord::Base.transaction do
        current_user.reload
        
        if current_user.coins < ticket_cost
          render json: { success: false, message: "Not enough coins" }, status: :unprocessable_entity
          return
        end
        ticket = RaffleTicket.create!(
          user: current_user,
          raffle_item_name: raffle_item_name,
          coins_spent: ticket_cost,
          purchased_at: Time.current,
          granted_by_admin: false
        )
        
        current_user.update!(coins: current_user.coins - ticket_cost)
        current_user.add_audit_log(
          action: "purchased_raffle_ticket",
          actor: current_user,
          details: { raffle_item: raffle_item_name, cost: ticket_cost, ticket_id: ticket.id }
        )
      end
      
      new_ticket_count = RaffleTicket.for_item(raffle_item_name).unused.where(user: current_user).count
      render json: { success: true, new_balance: current_user.coins, ticket_count: new_ticket_count }
    rescue => e
      Rails.logger.error "Failed to purchase raffle ticket: #{e.message}"
      render json: { success: false, message: "Failed to purchase: #{e.message}" }, status: :unprocessable_entity
    end
  end

  def log_runes
    rune_text = params[:runes]
    
    Rails.logger.info "User #{current_user.id} (#{current_user.name}) typed runes: #{rune_text}"
    
    # Save the current runes to the user
    current_user.update(current_runes: rune_text)
    
    # Generate random digits based on the runes
    # Use the rune text as a seed for consistent randomness per input
    random = Random.new(rune_text.bytes.sum)
    digits = (1..5).map { random.rand(0..9) }.join
    
    render json: { success: true, digits: digits }
  end

  private

  def check_user_eligibility
    if current_user&.out?
      render json: { success: false, message: "You cannot use catacombs actions while out of Siege" }, status: :forbidden
    end
  end

  def check_betting_window_available
    betting_window = MystereepleWindow.find_by(window_type: 'betting')
    unless betting_window&.available_today? && Flipper.enabled?(:betting, current_user)
      render json: { success: false, message: "Betting is not available at this time" }, status: :forbidden
    end
  end

  def check_shop_window_available
    shop_window = MystereepleWindow.find_by(window_type: 'shop')
    unless shop_window&.available_today?
      render json: { success: false, message: "The shop is not available at this time" }, status: :forbidden
    end
  end

  def check_raffle_window_available
    raffle_window = MystereepleWindow.find_by(window_type: 'raffle')
    unless raffle_window&.available_today?
      render json: { success: false, message: "The raffle is not available at this time" }, status: :forbidden
    end
  end
end
