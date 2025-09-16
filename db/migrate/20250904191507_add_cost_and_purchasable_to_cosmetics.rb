class AddCostAndPurchasableToCosmetics < ActiveRecord::Migration[8.0]
  def change
    add_column :cosmetics, :cost, :integer, default: 0
    add_column :cosmetics, :purchasable, :boolean, default: false
  end
end
