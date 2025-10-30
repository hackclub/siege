class RemoveUniqueIndexFromBallots < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!
  
  def change
    remove_index :ballots, [ :user_id, :week ], unique: true
    add_index :ballots, [ :user_id, :week ], algorithm: :concurrently
  end
end
