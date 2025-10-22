class MystereepleWindow < ApplicationRecord
  validates :name, presence: true
  validates :window_type, presence: true
  validates :days_available, presence: true

  scope :enabled, -> { where(enabled: true) }

  def available_today?
    return false unless enabled
    days_available.include?(Date.current.wday)
  end

  def self.available_windows_today
    enabled.select(&:available_today?)
  end
end
