class UserWeek < ApplicationRecord
  belongs_to :user
  belongs_to :project, optional: true
  
  validates :week, presence: true, inclusion: { in: 1..14 }
  validates :arbitrary_offset, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :mercenary_offset, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: { scope: :week }
  
  # Calculate total offset (mercenary + arbitrary)
  def total_offset
    mercenary_offset + arbitrary_offset
  end
  
  # Get effective hour goal for this week (base goal - total offset)
  def effective_hour_goal
    base_goal = week == 5 ? 9 : 10
    [base_goal - total_offset, 0].max
  end
  
  # Get effective hour goal in seconds
  def effective_hour_goal_seconds
    effective_hour_goal * 3600
  end
  
  # Scope to find UserWeek for a specific user and week
  scope :for_user_and_week, ->(user, week_num) { where(user: user, week: week_num) }
  
  # Scope to find all UserWeeks for a specific week
  scope :for_week, ->(week_num) { where(week: week_num) }
  
  # Scope to find all UserWeeks for a specific user
  scope :for_user, ->(user) { where(user: user) }
end
