class UnlockPurchasedCosmetics < ActiveRecord::Migration[7.1]
  def up
    # Find all cosmetic purchases and unlock them for the users
    ShopPurchase.joins("LEFT JOIN cosmetics ON shop_purchases.item_name = cosmetics.name")
                .where.not("cosmetics.id": nil)
                .find_each do |purchase|
      
      cosmetic = Cosmetic.find_by(name: purchase.item_name)
      next unless cosmetic
      
      user = purchase.user
      next unless user
      
      # Ensure user has a meeple
      meeple = user.meeple || user.create_meeple(color: "blue", cosmetics: [])
      
      # Check if cosmetic is already unlocked
      meeple_cosmetic = meeple.meeple_cosmetics.find_or_initialize_by(cosmetic: cosmetic)
      unless meeple_cosmetic.unlocked?
        meeple_cosmetic.unlocked = true
        meeple_cosmetic.save!
        puts "Unlocked #{cosmetic.name} for user #{user.name} (ID: #{user.id})"
      end
    end
  end

  def down
    # This migration cannot be easily reversed since we don't want to
    # remove cosmetics that users legitimately purchased
    raise ActiveRecord::IrreversibleMigration
  end
end
