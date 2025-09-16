class Vote < ApplicationRecord
  belongs_to :ballot
  belongs_to :project, optional: true

  validates :week, presence: true, numericality: { only_integer: true }
  validates :star_count, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }
  # Removed unique constraint to allow multiple votes per project
end
