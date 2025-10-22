class AddPaidOutToPersonalBets < ActiveRecord::Migration[8.0]
  def change
    add_column :personal_bets, :paid_out, :boolean, default: false, null: false
  end
end
