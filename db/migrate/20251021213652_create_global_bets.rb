class CreateGlobalBets < ActiveRecord::Migration[8.0]
  def change
    create_table :global_bets do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :week
      t.decimal :coin_amount
      t.decimal :estimated_payout
      t.decimal :predicted_hours

      t.timestamps
    end
  end
end
