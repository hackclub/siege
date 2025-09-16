class AddStonemasonFeedbackToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :stonemason_feedback, :text
  end
end
