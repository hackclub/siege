class Ballot < ApplicationRecord
  belongs_to :user
  has_many :votes, dependent: :destroy

  validates :week, presence: true, numericality: { only_integer: true }
  validates :user_id, uniqueness: { scope: :week, message: "can only have one ballot per week" }, unless: :multiple_ballots_allowed?
  validates :reasoning, presence: true, if: :voted?
  validate :cannot_resubmit_voted_ballot, on: :update

  # Helper method to check if ballot has been voted on
  def voted?
    voted
  end
  
  def multiple_ballots_allowed?
    user && Flipper.enabled?(:allow_multiple_ballots, user)
  end

  private

  def cannot_resubmit_voted_ballot
    if voted_was && voted?
      errors.add(:voted, "cannot resubmit an already voted ballot")
    end
  end
end
