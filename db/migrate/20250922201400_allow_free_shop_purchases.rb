class AllowFreeShopPurchases < ActiveRecord::Migration[7.1]
  def up
    safety_assured do
      # Remove the existing check constraint that requires coins_spent > 0
      remove_check_constraint :shop_purchases, name: "check_positive_purchase_amount"
      
      # Add new check constraint that allows coins_spent >= 0
      add_check_constraint :shop_purchases, "coins_spent >= 0", name: "check_non_negative_purchase_amount"
    end
  end

  def down
    safety_assured do
      # Remove the new constraint
      remove_check_constraint :shop_purchases, name: "check_non_negative_purchase_amount"
      
      # Restore the original constraint
      add_check_constraint :shop_purchases, "coins_spent > 0", name: "check_positive_purchase_amount"
    end
  end
end
