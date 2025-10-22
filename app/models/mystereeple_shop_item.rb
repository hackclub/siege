class MystereepleShopItem < ApplicationRecord
  validates :name, presence: true
  validates :cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :limit, presence: true, numericality: { greater_than: 0 }
  validate :image_must_be_attached

  has_one_attached :image
  has_many :shop_purchases, dependent: :nullify

  scope :enabled, -> { where(enabled: true) }

  def remaining_quantity
    limit - shop_purchases.count
  end

  def available?
    enabled && remaining_quantity > 0
  end

  private

  def image_must_be_attached
    return if image.attached?

    errors.add(:image, 'must be attached')
  end
end
