class AddReviewerMultiplierToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :reviewer_multiplier, :decimal, precision: 3, scale: 1, default: 2.0
  end
end
