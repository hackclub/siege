class AddMainDeviceToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :main_device, :string
  end
end
