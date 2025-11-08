class CreateRaffleDrawings < ActiveRecord::Migration[8.0]
  def change
    create_table :raffle_drawings do |t|
      t.string :raffle_item_name, null: false
      t.references :winner, null: false, foreign_key: { to_table: :users }
      t.references :winning_ticket, null: false, foreign_key: { to_table: :raffle_tickets }
      t.datetime :drawn_at, null: false
      t.integer :total_tickets, null: false
      t.integer :total_participants, null: false
      t.references :drawn_by, foreign_key: { to_table: :users }
      t.text :notes

      t.timestamps
    end

    add_index :raffle_drawings, :raffle_item_name
    add_index :raffle_drawings, :drawn_at
    
    # Now that raffle_drawings exists, add the foreign key from raffle_tickets
    add_foreign_key :raffle_tickets, :raffle_drawings
  end
end
