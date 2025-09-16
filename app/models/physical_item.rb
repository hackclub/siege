class PhysicalItem < ApplicationRecord
  validates :name, presence: true
  validates :cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :image_must_be_attached

  has_one_attached :image

  scope :purchasable, -> { where(purchasable: true) }

  private

  def image_must_be_attached
    return if image.attached?

    errors.add(:image, 'must be attached')
  end
end
