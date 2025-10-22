class AddMystereepleShopItemToShopPurchases < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!
  
  def change
    add_reference :shop_purchases, :mystereeple_shop_item, index: { algorithm: :concurrently }
  end
end
