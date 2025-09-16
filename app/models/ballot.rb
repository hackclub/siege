class Ballot < ApplicationRecord
  belongs_to :user
  has_many :votes, dependent: :destroy

  validates :week, presence: true, numericality: { only_integer: true }
  validates :user_id, uniqueness: { scope: :week, message: "can only have one ballot per week" }
  validates :reasoning, presence: true, if: :voted?

  # Helper method to check if ballot has been voted on
  def voted?
    voted
  end
end
