class AddMarketDataIntegrityConstraints < ActiveRecord::Migration[8.0]
  def change
    # Ensure shop purchases have positive amounts
    add_check_constraint :shop_purchases, "coins_spent > 0", name: "check_positive_purchase_amount"

    # Add unique constraint for one-time purchases
    add_index :shop_purchases, [ :user_id, :item_name ],
              where: "item_name IN ('Unlock Orange Meeple', 'Random Sticker')",
              unique: true,
              name: "index_shop_purchases_unique_one_time"

    # Note: Weekly mercenary limit enforced in application logic due to PostgreSQL immutability requirements
  end

  def down
    remove_check_constraint :shop_purchases, name: "check_positive_purchase_amount"
    remove_index :shop_purchases, name: "index_shop_purchases_unique_one_time"
  end
end
