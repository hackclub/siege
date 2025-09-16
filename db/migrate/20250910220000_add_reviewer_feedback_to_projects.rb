class AddReviewerFeedbackToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :reviewer_feedback, :text
  end
end
