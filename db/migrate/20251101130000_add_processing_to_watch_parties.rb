class AddProcessingToWatchParties < ActiveRecord::Migration[8.0]
  def change
    add_column :watch_parties, :processing_status, :string, default: "pending"
  end
end
