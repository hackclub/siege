class MarketController < ApplicationController
  before_action :require_authentication
  before_action :require_address, only: [ :purchase, :set_main_device ]
  before_action :check_market_enabled
  before_action :check_not_banned

  def index
    # Get user's purchase history to determine which one-time items to hide
    @purchased_one_time_items = current_user.shop_purchases
                                           .where(item_name: ShopPurchase.one_time_items)
                                           .pluck(:item_name)

    # Get purchasable cosmetics that haven't been purchased yet
    purchased_cosmetic_names = current_user.shop_purchases
                                          .where(item_name: Cosmetic.purchasable.pluck(:name))
                                          .pluck(:item_name)
    @purchasable_cosmetics = Cosmetic.purchasable
                                    .where.not(name: purchased_cosmetic_names)
    
    # Get all purchasable physical items (can be bought multiple times)
    @purchasable_physical_items = PhysicalItem.purchasable
    
    # Check if user is in supported region for regular tech tree
    @user_in_supported_region = user_in_supported_region?
  end

  def mercenary_price
    price = ShopPurchase.mercenary_price(current_user)
    count = ShopPurchase.weekly_purchases_count(current_user, "Mercenary")
    render json: { price: price, count: count }
  end

  def user_coins
    render json: { coins: current_user.coins }
  end

  def purchase
    item_name = params[:item_name]
    coins_spent = params[:coins_spent].to_i

    # Validate the purchase
    case item_name
    when "Mercenary"
      unless ShopPurchase.can_purchase_mercenary?(current_user)
        render json: { success: false, error: "You've already purchased 10 mercenaries this week!" }
        return
      end
      coins_spent = ShopPurchase.mercenary_price(current_user)
    when "Unlock Orange Meeple"
      if current_user.meeple&.unlocked_colors&.include?("orange")
        render json: { success: false, error: "You already have the orange meeple color!" }
        return
      end
      coins_spent = 50
    when "Random Sticker"
      # No special validation needed
      coins_spent = 15
    else
      # Check if it's a tech tree item
      tech_tree_item = get_tech_tree_item(item_name)
      if tech_tree_item
        # Check if user already purchased this tech tree item
        if tech_tree_item[:maxPurchases].nil?
          # Infinite purchases (like grants) - no purchase limit
        elsif tech_tree_item[:maxPurchases] && tech_tree_item[:maxPurchases] > 1
          # Multi-purchase item with limit
          purchased_count = current_user.shop_purchases.where(item_name: item_name).count
          if purchased_count >= tech_tree_item[:maxPurchases]
            render json: { success: false, error: "You've already purchased the maximum amount of this item!" }
            return
          end
        else
          # Single purchase item
          if current_user.shop_purchases.exists?(item_name: item_name)
            render json: { success: false, error: "You already own this item!" }
            return
          end
        end

        # Check prerequisites for tech tree items
        if tech_tree_item[:requires]
          required_items = tech_tree_item[:requires].split(",").map(&:strip)
          missing_items = required_items.reject do |required_item|
            current_user.shop_purchases.exists?(item_name: required_item)
          end

          if missing_items.any?
            error_message = if missing_items.size == 1
              "You must purchase #{missing_items.first} first!"
            else
              "You must purchase #{missing_items.join(' and ')} first!"
            end
            render json: { success: false, error: error_message }
            return
          end
        end

        coins_spent = tech_tree_item[:price]
      else
        # Check if it's a cosmetic
        cosmetic = Cosmetic.purchasable.find_by(name: item_name)
        if cosmetic
          # Check if user already purchased this cosmetic
          if current_user.shop_purchases.exists?(item_name: item_name)
            render json: { success: false, error: "You already own this cosmetic!" }
            return
          end
          coins_spent = cosmetic.cost
        else
          # Check if it's a physical item
          physical_item = PhysicalItem.purchasable.find_by(name: item_name)
          if physical_item
            # Physical items can be purchased multiple times, no purchase check needed
            coins_spent = physical_item.cost
          else
            render json: { success: false, error: "Unknown item!" }
            return
          end
        end
      end
    end

    # Use transaction with locking to prevent race conditions
    current_user.with_lock do
      # Reload user to get latest coin balance
      current_user.reload

      # Check if user has enough coins (prevent user-driven negative balances)
      if current_user.coins < coins_spent
        render json: { success: false, error: "Not enough coins! You have #{current_user.coins} coins." }
        return
      end

      # Create the purchase record
      purchase = ShopPurchase.create!(
        user: current_user,
        item_name: item_name,
        coins_spent: coins_spent,
        purchased_at: Time.current,
        fulfilled: auto_fulfill?(item_name)
      )

      # Deduct coins from user
      current_user.update!(coins: current_user.coins - coins_spent)
    end

    # Handle special item effects
    case item_name
    when "Unlock Orange Meeple"
      current_user.meeple ||= current_user.build_meeple
      unlocked_colors = current_user.meeple.unlocked_colors || []
      unlocked_colors << "orange" unless unlocked_colors.include?("orange")
      current_user.meeple.update!(unlocked_colors: unlocked_colors)
    end

    # Calculate remaining mercenary purchases for response
    remaining_mercenaries = 0
    if item_name == "Mercenary"
      purchased_this_week = ShopPurchase.weekly_purchases_count(current_user, "Mercenary")
      remaining_mercenaries = [ 0, 10 - purchased_this_week ].max
    end

    render json: {
      success: true,
      message: "Successfully purchased #{item_name}!",
      remaining_mercenaries: remaining_mercenaries
    }
  rescue => e
    Rails.logger.error "Purchase error: #{e.message}"
    render json: { success: false, error: "Purchase failed. Please try again." }
  end

  def set_main_device
    device_id = params[:device_id]

    if current_user.set_main_device(device_id)
      render json: { success: true, message: "Main device updated successfully" }
    else
      render json: { success: false, error: "Invalid device selection" }
    end
  end

  def get_main_device
    render json: {
      main_device: current_user.main_device,
      main_device_name: current_user.main_device_name,
      has_main_device: current_user.has_main_device?
    }
  end

  def refund_item
    item_name = params[:item_name]
    refund_amount = params[:refund_amount].to_i

    # Find all purchases of this item
    purchases = current_user.shop_purchases.where(item_name: item_name)

    if purchases.any?
      # Add coins back to user
      current_user.increment!(:coins, refund_amount)

      # Delete all purchases of this item
      purchases.destroy_all

      render json: { success: true, message: "Item refunded successfully", refund_amount: refund_amount }
    else
      render json: { success: false, error: "No purchases found for this item" }
    end
  end

  def user_purchases
    # Group purchases by item_name and sum coins_spent for refunds
    purchases_by_item = current_user.shop_purchases.group(:item_name).sum(:coins_spent)
    purchases_count = current_user.shop_purchases.group(:item_name).count

    purchases = purchases_by_item.map do |item_name, total_coins_spent|
      {
        item_name: item_name,
        quantity: purchases_count[item_name] || 0,
        total_coins_spent: total_coins_spent
      }
    end

    render json: { purchases: purchases }
  end

  def user_region_info
    render json: {
      in_supported_region: user_in_supported_region?,
      total_grant_amount: get_user_total_grant_amount
    }
  end

  def tech_tree_data
    tech_tree_data = JSON.parse(File.read(Rails.root.join("config", "tech_tree_data.json")))

    render json: tech_tree_data
  end

  private

  def check_market_enabled
    unless Flipper.enabled?(:market_enabled, current_user)
      redirect_to keep_path, alert: "The market is currently disabled."
    end
  end

  def auto_fulfill?(item_name)
    case item_name
    when "Mercenary", "Unlock Orange Meeple"
      true
    else
      # Check if it's a tech tree item
      tech_tree_item = get_tech_tree_item(item_name)
      if tech_tree_item
        true # Tech tree items are auto-fulfilled
      else
        # Check if it's a cosmetic
        cosmetic = Cosmetic.purchasable.find_by(name: item_name)
        if cosmetic.present?
          true
        else
          # Check if it's a physical item - these are NOT auto-fulfilled
          physical_item = PhysicalItem.purchasable.find_by(name: item_name)
          physical_item.present? ? false : false
        end
      end
    end
  end

  def get_tech_tree_item(item_name)
    # Load from JSON file instead of hardcoded hash
    tech_tree_data = JSON.parse(File.read(Rails.root.join("config", "tech_tree_data.json")))

    # Search through all categories and devices to find the item
    tech_tree_data.each do |category_name, category_data|
      next unless category_data["branches"]

      category_data["branches"].each do |device_name, device_branches|
        device_branches.each do |direction, item|
          if item["title"] == item_name
            return {
              price: item["price"] || 0,
              maxPurchases: item["maxPurchases"],
              requires: item["requires"]
            }.compact
          end
        end
      end
    end

    nil
  end

  def user_in_supported_region?
    return false unless current_user.address&.country

    # List of supported country codes (ISO 3166-1 alpha-2)
    supported_countries = %w[
      US CA GB DE FR IE NL AT AU IT ES BE TW PL DK SE FI GR EE LV LT LU MT CY SI HR PT SK HU BG RO CZ
    ]

    supported_countries.include?(current_user.address.country)
  end



  def get_user_total_grant_amount
    base_amount = 650
    grant_purchases = current_user.shop_purchases.where(
      item_name: [ "+$10 Grant", "+$50 Grant", "+$100 Grant" ]
    )

    additional_amount = grant_purchases.sum do |purchase|
      case purchase.item_name
      when "+$10 Grant"
        10
      when "+$50 Grant"
        50
      when "+$100 Grant"
        100
      else
        0
      end
    end

    base_amount + additional_amount
  end

  def multiply_prices_by_factor(data, factor)
    data.each do |category_name, category_data|
      next unless category_data["branches"]

      category_data["branches"].each do |device_name, device_branches|
        device_branches.each do |direction, item|
          if item["price"] && item["price"] > 0
            item["price"] = (item["price"] * factor).to_i
          end
        end
      end
    end
  end
end
