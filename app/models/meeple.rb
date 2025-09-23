class Meeple < ApplicationRecord
  belongs_to :user

  validates :color, presence: true, inclusion: { in: %w[blue red pink green orange purple cyan yellow] }
  validate :color_must_be_unlocked

  has_many :meeple_cosmetics, dependent: :destroy
  has_many :cosmetics, through: :meeple_cosmetics

  # Ensure unlocked_colors is always an array
  def unlocked_colors
    super || [ "blue", "red", "green", "purple" ]
  end

  def unlock_color(color)
    return false unless %w[blue red pink green orange purple cyan yellow].include?(color)

    current_colors = unlocked_colors
    unless current_colors.include?(color)
      update!(unlocked_colors: current_colors + [ color ])
    end
    true
  end

  def relock_color(color)
    return false unless %w[blue red pink green orange purple cyan yellow].include?(color)

    current_colors = unlocked_colors

    # Cannot relock the current color - user would be stuck
    return false if color == self.color

    # Remove color from unlocked colors if it exists
    if current_colors.include?(color)
      update!(unlocked_colors: current_colors - [ color ])
      true
    else
      false # Color was not unlocked anyway
    end
  end

  def color_unlocked?(color)
    unlocked_colors.include?(color)
  end

  def unlocked_cosmetics
    meeple_cosmetics.where(unlocked: true).includes(:cosmetic)
  end

  def equipped_cosmetics
    meeple_cosmetics.where(equipped: true).includes(:cosmetic)
  end

  # Safe serialization for voting - only expose minimal necessary data
  def safe_attributes_for_voting
    {
      color: color
      # Don't include cosmetics, unlocked_colors, or other sensitive data
    }
  end

  def unlock_cosmetic(cosmetic)
    meeple_cosmetic = meeple_cosmetics.find_or_initialize_by(cosmetic: cosmetic)
    meeple_cosmetic.unlocked = true
    meeple_cosmetic.save!
  end

  def equip_cosmetic(cosmetic)
    return unless unlocked_cosmetics.exists?(cosmetic: cosmetic)

    # Handle mutually exclusive cosmetics (back and cloak)
    if cosmetic.type == 'back' || cosmetic.type == 'cloak'
      # Unequip both back and cloak cosmetics
      meeple_cosmetics.joins(:cosmetic)
                     .where(cosmetics: { type: ['back', 'cloak'] })
                     .update_all(equipped: false)
    else
      # Unequip other cosmetics of the same type
      meeple_cosmetics.joins(:cosmetic)
                     .where(cosmetics: { type: cosmetic.type })
                     .update_all(equipped: false)
    end

    # Equip the new cosmetic
    meeple_cosmetics.find_by(cosmetic: cosmetic).update!(equipped: true)
  end

  def unequip_cosmetic(cosmetic)
    meeple_cosmetics.find_by(cosmetic: cosmetic)&.update!(equipped: false)
  end

  private

  def color_must_be_unlocked
    return unless color.present?

    unless color_unlocked?(color)
      errors.add(:color, "is not unlocked for this meeple")
    end
  end
end
