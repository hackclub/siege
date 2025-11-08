class Admin::MystereepleController < AdminController
  def index
    @windows = MystereepleWindow.all.order(:name)
    @shop_items = MystereepleShopItem.all.order(:name)
    @current_week = ApplicationController.helpers.current_week_number
  end

  def windows
    @windows = MystereepleWindow.all.order(:name)
  end

  def update_window_days
    window = MystereepleWindow.find(params[:id])
    window.update!(days_available: params[:days_available])
    
    current_user.add_audit_log(
      action: "updated_mystereeple_window",
      actor: current_user,
      details: { window_id: window.id, window_name: window.name, days_available: params[:days_available] }
    )
    
    render json: { success: true }
  rescue => e
    Rails.logger.error "Failed to update window days: #{e.message}"
    render json: { success: false, message: e.message }, status: :unprocessable_entity
  end

  def toggle_window
    window = MystereepleWindow.find(params[:id])
    window.update!(enabled: !window.enabled)
    
    current_user.add_audit_log(
      action: "toggled_mystereeple_window",
      actor: current_user,
      details: { window_id: window.id, window_name: window.name, enabled: window.enabled }
    )
    
    render json: { success: true, enabled: window.enabled }
  rescue => e
    Rails.logger.error "Failed to toggle window: #{e.message}"
    render json: { success: false, message: e.message }, status: :unprocessable_entity
  end

  # Raffle management
  def raffle
    @raffle_item_name = "Felt Gingereeple"
    
    # Get comprehensive stats
    @stats = RaffleTicket.stats_for_item(@raffle_item_name)
    
    # Get all tickets with users
    @all_tickets = RaffleTicket.for_item(@raffle_item_name).includes(:user).recent
    @unused_tickets = @all_tickets.unused
    
    # Get user-level stats
    user_ids = RaffleTicket.for_item(@raffle_item_name).select(:user_id).distinct.pluck(:user_id)
    users = User.where(id: user_ids).index_by(&:id)
    
    @users_with_tickets = user_ids.map do |user_id|
      user = users[user_id]
      next unless user
      
      user_tickets = @all_tickets.select { |t| t.user_id == user_id }
      unused = user_tickets.count { |t| !t.used }
      
      {
        user: user,
        total_tickets: user_tickets.count,
        unused_tickets: unused,
        purchased_tickets: user_tickets.count { |t| !t.granted_by_admin },
        granted_tickets: user_tickets.count { |t| t.granted_by_admin },
        coins_spent: user_tickets.sum(&:coins_spent),
        win_chance: @stats[:unused] > 0 ? (unused.to_f / @stats[:unused] * 100).round(2) : 0
      }
    end.compact.sort_by { |h| -h[:total_tickets] }
    
    # Get drawing history
    @past_drawings = RaffleDrawing.for_item(@raffle_item_name).recent.limit(10).includes(:winner, :drawn_by)
    
    # Recent activity
    @recent_tickets = @all_tickets.limit(20)
  end

  def grant_raffle_ticket
    user = User.find(params[:user_id])
    raffle_item_name = params[:raffle_item_name] || "Felt Gingereeple"
    
    ticket = RaffleTicket.create!(
      user: user,
      raffle_item_name: raffle_item_name,
      coins_spent: 0,
      purchased_at: Time.current,
      granted_by_admin: true,
      notes: "Granted by #{current_user.name}"
    )
    
    current_user.add_audit_log(
      action: "granted_raffle_ticket",
      actor: current_user,
      details: { user_id: user.id, user_name: user.name, raffle_item: raffle_item_name, ticket_id: ticket.id }
    )
    
    redirect_to admin_mystereeple_raffle_path, notice: "Granted ticket to #{user.name}"
  rescue => e
    Rails.logger.error "Failed to grant raffle ticket: #{e.message}"
    redirect_to admin_mystereeple_raffle_path, alert: "Failed to grant ticket: #{e.message}"
  end

  def refund_raffle_ticket
    user = User.find(params[:user_id])
    raffle_item_name = params[:raffle_item_name] || "Felt Gingereeple"
    
    # Find the most recent unused ticket for this user and item
    ticket = RaffleTicket.for_item(raffle_item_name).unused.where(user: user).recent.first
    
    unless ticket
      redirect_to admin_mystereeple_raffle_path, alert: "No unused tickets found for #{user.name}"
      return
    end
    
    ActiveRecord::Base.transaction do
      # Refund the coins if they were spent
      if ticket.coins_spent > 0
        user.update!(coins: user.coins + ticket.coins_spent)
      end
      
      # Delete the ticket
      ticket.destroy!
      
      current_user.add_audit_log(
        action: "refunded_raffle_ticket",
        actor: current_user,
        details: { user_id: user.id, user_name: user.name, raffle_item: raffle_item_name, coins_refunded: ticket.coins_spent, ticket_id: ticket.id }
      )
    end
    
    redirect_to admin_mystereeple_raffle_path, notice: "Refunded ticket for #{user.name}"
  rescue => e
    Rails.logger.error "Failed to refund raffle ticket: #{e.message}"
    redirect_to admin_mystereeple_raffle_path, alert: "Failed to refund ticket: #{e.message}"
  end

  def pick_raffle_winner
    raffle_item_name = params[:raffle_item_name] || "Felt Gingereeple"
    
    Rails.logger.info "[RAFFLE] Starting winner selection for #{raffle_item_name}"
    
    # Get all unused tickets
    unused_tickets = RaffleTicket.for_item(raffle_item_name).unused.includes(:user).to_a
    
    Rails.logger.info "[RAFFLE] Found #{unused_tickets.count} unused tickets"
    
    if unused_tickets.empty?
      Rails.logger.warn "[RAFFLE] No unused tickets available"
      redirect_to admin_mystereeple_raffle_path, alert: "No unused tickets available"
      return
    end
    
    # Pick a random ticket
    winning_ticket = unused_tickets.sample
    winner = winning_ticket.user
    
    Rails.logger.info "[RAFFLE] Selected winning ticket ##{winning_ticket.id} for user #{winner.name}"
    
    # Create the drawing record (this marks all tickets as used)
    drawing = RaffleDrawing.create_drawing!(raffle_item_name, winning_ticket, current_user)
    
    Rails.logger.info "[RAFFLE] Created drawing ##{drawing.id}"
    
    current_user.add_audit_log(
      action: "picked_raffle_winner",
      actor: current_user,
      details: { 
        winner_id: winner.id, 
        winner_name: winner.name, 
        raffle_item: raffle_item_name,
        drawing_id: drawing.id,
        total_tickets: drawing.total_tickets,
        winner_ticket_count: unused_tickets.count { |t| t.user_id == winner.id }
      }
    )
    
    Rails.logger.info "[RAFFLE] Winner selection complete"
    
    redirect_to admin_mystereeple_raffle_path, notice: "🎉 Winner picked: #{winner.name}! (had #{unused_tickets.count { |t| t.user_id == winner.id }} tickets out of #{drawing.total_tickets} total)"
  rescue => e
    Rails.logger.error "[RAFFLE] Failed to pick raffle winner: #{e.class} - #{e.message}"
    Rails.logger.error "[RAFFLE] Backtrace: #{e.backtrace.first(5).join("\n")}"
    redirect_to admin_mystereeple_raffle_path, alert: "Failed to pick winner: #{e.message}"
  end

  def mark_all_raffle_tickets_used
    raffle_item_name = params[:raffle_item_name] || "Felt Gingereeple"
    
    unused_tickets = RaffleTicket.for_item(raffle_item_name).unused
    count = unused_tickets.count
    
    if count == 0
      redirect_to admin_mystereeple_raffle_path, alert: "No unused tickets to mark"
      return
    end
    
    unused_tickets.update_all(used: true)
    
    current_user.add_audit_log(
      action: "marked_all_raffle_tickets_used",
      actor: current_user,
      details: { raffle_item: raffle_item_name, ticket_count: count }
    )
    
    redirect_to admin_mystereeple_raffle_path, notice: "Marked #{count} tickets as used"
  rescue => e
    Rails.logger.error "Failed to mark tickets as used: #{e.message}"
    redirect_to admin_mystereeple_raffle_path, alert: "Failed to mark tickets: #{e.message}"
  end
end
