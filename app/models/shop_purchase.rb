class ShopPurchase < ApplicationRecord
  belongs_to :user
  belongs_to :user_week, optional: true
  belongs_to :mystereeple_shop_item, optional: true

  validates :item_name, presence: true
  validates :coins_spent, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :purchased_at, presence: true

  after_create :associate_with_user_week

  scope :fulfilled, -> { where(fulfilled: true) }
  scope :unfulfilled, -> { where(fulfilled: false) }
  scope :this_week, -> { 
    # Use Siege week dates (based on event start date) instead of calendar weeks
    week_range = ApplicationController.helpers.week_date_range(ApplicationController.helpers.current_week_number)
    if week_range
      week_start = Date.parse(week_range[0])
      week_end = Date.parse(week_range[1])
      where(purchased_at: week_start.beginning_of_day..week_end.end_of_day)
    else
      none
    end
  }
  scope :by_item, ->(item_name) { where(item_name: item_name) }

  def self.weekly_purchases_count(user, item_name)
    where(user: user, item_name: item_name)
      .this_week
      .count
  end

  def self.can_purchase_mercenary?(user)
    weekly_purchases_count(user, "Mercenary") < 10
  end

  def self.mercenary_price(user)
    base_price = 30
    current_week = ApplicationController.helpers.current_week_number
    user_week = UserWeek.find_by(user: user, week: current_week)
    purchased_this_week = user_week&.mercenary_offset || 0
    base_price + purchased_this_week
  end

  def self.time_travelling_mercenary_quantity(user)
    Rails.logger.info "[TIME TRAVEL] Starting calculation for user #{user.id} (#{user.name})"
    Rails.logger.info "[TIME TRAVEL] User status: #{user.status}, working?: #{user.working?}, out?: #{user.out?}"
    
    # Don't show item at all if user is working
    if user.working?
      Rails.logger.info "[TIME TRAVEL] User is working, returning 0"
      return 0
    end
    
    # Only show if user is out
    unless user.out?
      Rails.logger.info "[TIME TRAVEL] User is not out, returning 0"
      return 0
    end
    
    current_week = ApplicationController.helpers.current_week_number
    Rails.logger.info "[TIME TRAVEL] Current week: #{current_week}"
    
    if current_week < 6
      Rails.logger.info "[TIME TRAVEL] Current week < 6, returning 0"
      return 0
    end
    
    # Look at weeks from 5 to (current_week - 1)
    start_week = 5
    end_week = current_week - 1
    Rails.logger.info "[TIME TRAVEL] Checking weeks #{start_week} to #{end_week}"
    
    # Preload all user_weeks for the range to avoid N+1
    user_weeks_by_week = UserWeek.where(user: user, week: start_week..end_week).index_by(&:week)
    
    # Get date range for all weeks to preload projects
    first_week_range = ApplicationController.helpers.week_date_range(start_week)
    last_week_range = ApplicationController.helpers.week_date_range(end_week)
    
    if first_week_range && last_week_range
      # Preload all projects in the entire date range to avoid N+1
      all_projects = user.projects.where(
        "created_at >= ? AND created_at <= ?",
        Date.parse(first_week_range[0]).beginning_of_day,
        Date.parse(last_week_range[1]).end_of_day
      ).to_a
    else
      all_projects = []
    end
    
    total_hours_under = 0
    
    (start_week..end_week).each do |week|
      Rails.logger.info "[TIME TRAVEL] --- Checking week #{week} ---"
      user_week = user_weeks_by_week[week]
      effective_goal = user_week&.effective_hour_goal || (week == 5 ? 9 : 10)
      Rails.logger.info "[TIME TRAVEL] Effective goal for week #{week}: #{effective_goal}h"
      
      # Get user's actual hours for that week
      # Use the helper to calculate total seconds, then convert to hours
      time_range = ApplicationController.helpers.week_date_range(week)
      unless time_range
        Rails.logger.info "[TIME TRAVEL] No time range for week #{week}, skipping"
        next
      end
      Rails.logger.info "[TIME TRAVEL] Time range: #{time_range[0]} to #{time_range[1]}"
      
      # Filter preloaded projects for this week
      week_start = Date.parse(time_range[0]).beginning_of_day
      week_end = Date.parse(time_range[1]).end_of_day
      projects = all_projects.select do |project|
        project.created_at >= week_start && project.created_at <= week_end
      end
      
      total_seconds = 0
      projects.each do |project|
        # Get hackatime time for this project
        if project.hackatime_projects.present? && project.effective_time_range
          projs = ApplicationController.helpers.hackatime_projects_for_user(
            user,
            *project.effective_time_range
          )
          
          project.hackatime_projects.each do |project_name|
            match = projs.find { |p| p["name"].to_s == project_name.to_s }
            total_seconds += match&.dig("total_seconds") || 0
          end
        end
      end
      
      actual_hours = total_seconds / 3600.0
      Rails.logger.info "[TIME TRAVEL] Week #{week} actual hours: #{actual_hours.round(2)}h"
      
      # If under goal, add the rounded up difference
      if actual_hours < effective_goal
        hours_under = effective_goal - actual_hours
        hours_under_rounded = hours_under.ceil
        Rails.logger.info "[TIME TRAVEL] Week #{week} UNDER by #{hours_under.round(2)}h (rounded: #{hours_under_rounded})"
        total_hours_under += hours_under_rounded
      else
        Rails.logger.info "[TIME TRAVEL] Week #{week} met or exceeded goal"
      end
    end
    
    Rails.logger.info "[TIME TRAVEL] FINAL: Total hours under = #{total_hours_under}"
    total_hours_under
  end

  def self.time_travelling_mercenary_inventory_count(user)
    # Count only unfulfilled time travelling mercenaries
    where(user: user, item_name: "Time travelling mercenary", fulfilled: false).count
  end

  def self.one_time_items
    [ "Unlock Orange Meeple" ]
  end

  def self.is_one_time_item?(item_name)
    one_time_items.include?(item_name)
  end

  private

  def associate_with_user_week
    return unless item_name == "Mercenary"
    
    week_number = ApplicationController.helpers.week_number_for_date(purchased_at.to_date)
    return unless week_number && week_number >= 1 && week_number <= 14
    
    # Find or create UserWeek for this user and week
    user_week = UserWeek.find_or_create_by(user: user, week: week_number) do |uw|
      uw.arbitrary_offset = 0
      uw.mercenary_offset = 0
    end
    
    # Associate this purchase with the UserWeek
    update!(user_week: user_week)
    
    # Update the mercenary offset count
    user_week.increment!(:mercenary_offset)
  end
end
