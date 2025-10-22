class AddPaidOutToGlobalBets < ActiveRecord::Migration[8.0]
  def change
    add_column :global_bets, :paid_out, :boolean, default: false, null: false
  end
end
