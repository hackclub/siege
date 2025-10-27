class MystereepleWindow < ApplicationRecord
  validates :name, presence: true
  validates :window_type, presence: true
  validate :days_available_is_array

  scope :enabled, -> { where(enabled: true) }

  def available_today?
    return false unless enabled
    days_available.include?(Date.current.wday)
  end

  def self.available_windows_today
    enabled.select(&:available_today?)
  end

  private

  def days_available_is_array
    unless days_available.is_a?(Array)
      errors.add(:days_available, "must be an array")
    end
  end
end
