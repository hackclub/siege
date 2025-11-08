class RaffleTicket < ApplicationRecord
  belongs_to :user
  belongs_to :raffle_drawing, optional: true

  validates :raffle_item_name, presence: true
  validates :purchased_at, presence: true
  validates :coins_spent, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :for_item, ->(item_name) { where(raffle_item_name: item_name) }
  scope :unused, -> { where(used: false) }
  scope :used, -> { where(used: true) }
  scope :winners, -> { where(winner: true) }
  scope :granted, -> { where(granted_by_admin: true) }
  scope :purchased, -> { where(granted_by_admin: false) }
  scope :recent, -> { order(purchased_at: :desc) }

  def self.stats_for_item(item_name)
    tickets = for_item(item_name)
    {
      total: tickets.count,
      unused: tickets.unused.count,
      used: tickets.used.count,
      purchased: tickets.purchased.count,
      granted: tickets.granted.count,
      total_coins_spent: tickets.sum(:coins_spent),
      participants: tickets.select(:user_id).distinct.count
    }
  end

  def self.user_stats_for_item(item_name)
    for_item(item_name)
      .group(:user_id)
      .select('user_id, COUNT(*) as total_tickets, 
               SUM(CASE WHEN used = false THEN 1 ELSE 0 END) as unused_tickets,
               SUM(coins_spent) as total_spent,
               MAX(CASE WHEN granted_by_admin = true THEN 1 ELSE 0 END) as has_granted_tickets')
  end
end
