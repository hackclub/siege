class AddFraudTeamToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :on_fraud_team, :boolean, default: false, null: false
  end
end
