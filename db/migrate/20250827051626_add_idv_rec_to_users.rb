class AddIdvRecToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :idv_rec, :string
  end
end
