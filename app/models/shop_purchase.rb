class ShopPurchase < ApplicationRecord
  belongs_to :user

  validates :item_name, presence: true
  validates :coins_spent, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :purchased_at, presence: true

  scope :fulfilled, -> { where(fulfilled: true) }
  scope :unfulfilled, -> { where(fulfilled: false) }
  scope :this_week, -> { where(purchased_at: Date.current.beginning_of_week..Date.current.end_of_week) }
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
    purchased_this_week = weekly_purchases_count(user, "Mercenary")
    base_price + purchased_this_week
  end

  def self.one_time_items
    [ "Unlock Orange Meeple" ]
  end

  def self.is_one_time_item?(item_name)
    one_time_items.include?(item_name)
  end
end
