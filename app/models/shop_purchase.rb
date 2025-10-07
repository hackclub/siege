class ShopPurchase < ApplicationRecord
  belongs_to :user
  belongs_to :user_week, optional: true

  validates :item_name, presence: true
  validates :coins_spent, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :purchased_at, presence: true

  after_create :associate_with_user_week

  scope :fulfilled, -> { where(fulfilled: true) }
  scope :unfulfilled, -> { where(fulfilled: false) }
  scope :this_week, -> { 
    # Use Siege week dates (based on event start date) instead of calendar weeks
    week_range = ApplicationController.helpers.week_date_range(ApplicationController.helpers.current_week_number)
    if week_range
      week_start = Date.parse(week_range[0])
      week_end = Date.parse(week_range[1])
      where(purchased_at: week_start.beginning_of_day..week_end.end_of_day)
    else
      none
    end
  }
  scope :by_item, ->(item_name) { where(item_name: item_name) }

  def self.weekly_purchases_count(user, item_name)
    where(user: user, item_name: item_name)
      .this_week
      .count
  end

  def self.can_purchase_mercenary?(user)
    weekly_purchases_count(user, "Mercenary") < 10
  end

  def self.mercenary_price(user)
    base_price = 30
    current_week = ApplicationController.helpers.current_week_number
    user_week = UserWeek.find_by(user: user, week: current_week)
    purchased_this_week = user_week&.mercenary_offset || 0
    base_price + purchased_this_week
  end

  def self.one_time_items
    [ "Unlock Orange Meeple" ]
  end

  def self.is_one_time_item?(item_name)
    one_time_items.include?(item_name)
  end

  private

  def associate_with_user_week
    return unless item_name == "Mercenary"
    
    week_number = ApplicationController.helpers.week_number_for_date(purchased_at.to_date)
    return unless week_number && week_number >= 1 && week_number <= 14
    
    # Find or create UserWeek for this user and week
    user_week = UserWeek.find_or_create_by(user: user, week: week_number) do |uw|
      uw.arbitrary_offset = 0
      uw.mercenary_offset = 0
    end
    
    # Associate this purchase with the UserWeek
    update!(user_week: user_week)
    
    # Update the mercenary offset count
    user_week.increment!(:mercenary_offset)
  end
end
