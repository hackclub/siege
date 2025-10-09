class HackatimeDay < ApplicationRecord
  validates :date, presence: true, uniqueness: true
  
  # Get users who coded on this day
  def users
    User.where(id: user_ids || [])
  end
  
  # Calculate average hours per user
  def average_hours
    return 0.0 if user_ids.blank? || user_ids.empty?
    total_hours / user_ids.size
  end
  
  # Get total user count
  def user_count
    (user_ids || []).size
  end
end
