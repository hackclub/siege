class AddOutToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :out, :boolean, default: false, null: false
  end
end
