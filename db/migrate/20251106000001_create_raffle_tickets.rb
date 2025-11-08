class CreateRaffleTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :raffle_tickets do |t|
      t.references :user, null: false, foreign_key: true
      t.string :raffle_item_name, null: false
      t.datetime :purchased_at, null: false
      t.boolean :used, default: false, null: false
      t.integer :coins_spent, default: 1, null: false
      t.boolean :granted_by_admin, default: false, null: false
      t.boolean :winner, default: false, null: false
      t.bigint :raffle_drawing_id
      t.text :notes

      t.timestamps
    end

    add_index :raffle_tickets, [:raffle_item_name, :used]
    add_index :raffle_tickets, [:raffle_item_name, :winner]
    add_index :raffle_tickets, :purchased_at
    add_index :raffle_tickets, :raffle_drawing_id
  end
end
