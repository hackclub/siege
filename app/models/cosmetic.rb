class Cosmetic < ApplicationRecord
  # Disable Single Table Inheritance since we use 'type' for cosmetic categories
  self.inheritance_column = nil

  validates :name, presence: true
  validates :type, presence: true
  validates :cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :image_must_be_attached

  has_one_attached :image
  has_many :meeple_cosmetics, dependent: :destroy
  has_many :meeples, through: :meeple_cosmetics

  scope :by_type, ->(type) { where(type: type) }
  scope :purchasable, -> { where(purchasable: true) }

  private

  def image_must_be_attached
    return if image.attached?

    errors.add(:image, "must be attached")
  end
end
