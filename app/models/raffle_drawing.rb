class RaffleDrawing < ApplicationRecord
  belongs_to :winner, class_name: 'User'
  belongs_to :winning_ticket, class_name: 'RaffleTicket'
  belongs_to :drawn_by, class_name: 'User', optional: true
  has_many :raffle_tickets

  validates :raffle_item_name, presence: true
  validates :drawn_at, presence: true
  validates :total_tickets, presence: true, numericality: { greater_than: 0 }
  validates :total_participants, presence: true, numericality: { greater_than: 0 }

  scope :for_item, ->(item_name) { where(raffle_item_name: item_name) }
  scope :recent, -> { order(drawn_at: :desc) }

  def self.create_drawing!(item_name, winning_ticket, admin_user)
    unused_tickets = RaffleTicket.for_item(item_name).unused
    
    transaction do
      # Count before we modify anything!
      total_tickets_count = unused_tickets.count
      total_participants_count = unused_tickets.select(:user_id).distinct.count
      
      # Create drawing record first
      drawing = create!(
        raffle_item_name: item_name,
        winner: winning_ticket.user,
        winning_ticket: winning_ticket,
        drawn_at: Time.current,
        total_tickets: total_tickets_count,
        total_participants: total_participants_count,
        drawn_by: admin_user
      )
      
      # Mark winning ticket
      winning_ticket.update!(winner: true)
      
      # Mark all tickets as used and associate with drawing
      unused_tickets.update_all(used: true, raffle_drawing_id: drawing.id)
      
      drawing
    end
  end
end
