class AddRankToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :rank, :string, default: 'user', null: false

    add_index :users, :rank
  end
end
