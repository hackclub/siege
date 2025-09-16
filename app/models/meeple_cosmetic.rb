class MeepleCosmetic < ApplicationRecord
  belongs_to :meeple
  belongs_to :cosmetic

  validates :meeple_id, uniqueness: { scope: :cosmetic_id }
end
