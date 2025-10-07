class PopulateUserWeeksAndMigrateMercenaries < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Create UserWeek records for all users for weeks 1-14
    User.find_each do |user|
      (1..14).each do |week|
        # Find project for this week if it exists
        week_range = ApplicationController.helpers.week_date_range(week)
        project = nil
        
        if week_range
          week_start_date = Date.parse(week_range[0])
          week_end_date = Date.parse(week_range[1])
          project = user.projects.where(
            created_at: week_start_date.beginning_of_day..week_end_date.end_of_day
          ).first
        end
        
        # Count mercenaries for this week
        mercenary_count = 0
        if week_range
          week_start = Date.parse(week_range[0]).beginning_of_day
          week_end = Date.parse(week_range[1]).end_of_day
          mercenary_count = user.shop_purchases
            .where(item_name: "Mercenary")
            .where(purchased_at: week_start..week_end)
            .count
        end
        
        # Create UserWeek record
        UserWeek.create!(
          user: user,
          week: week,
          project: project,
          arbitrary_offset: 0,
          mercenary_offset: mercenary_count
        )
      end
    end
    
    # Add user_week_id to shop_purchases table
    add_reference :shop_purchases, :user_week, null: true, index: { algorithm: :concurrently }
    add_foreign_key :shop_purchases, :user_weeks, validate: false
    
    # Associate existing mercenary purchases with UserWeeks
    ShopPurchase.where(item_name: "Mercenary").find_each do |purchase|
      # Find the UserWeek for this purchase's week
      week_number = ApplicationController.helpers.week_number_for_date(purchase.purchased_at.to_date)
      if week_number && week_number >= 1 && week_number <= 14
        user_week = UserWeek.find_by(user: purchase.user, week: week_number)
        if user_week
          purchase.update!(user_week: user_week)
        end
      end
    end
  end

  def down
    # Remove user_week_id from shop_purchases
    remove_reference :shop_purchases, :user_week, foreign_key: true
    
    # Drop all UserWeek records
    UserWeek.delete_all
  end
end
