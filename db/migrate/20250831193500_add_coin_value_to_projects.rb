class AddCoinValueToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :coin_value, :decimal, precision: 10, scale: 2, default: 0, null: false
  end
end
