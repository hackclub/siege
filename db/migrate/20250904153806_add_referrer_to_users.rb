class AddReferrerToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :referrer_id, :integer
    add_index :users, :referrer_id
    add_foreign_key :users, :users, column: :referrer_id
  end
end
