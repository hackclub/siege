class CreatePersonalBets < ActiveRecord::Migration[8.0]
  def change
    create_table :personal_bets do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :week
      t.decimal :coin_amount
      t.decimal :estimated_payout
      t.integer :hours_goal

      t.timestamps
    end
  end
end
