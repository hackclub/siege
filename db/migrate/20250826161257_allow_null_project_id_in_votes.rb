class AllowNullProjectIdInVotes < ActiveRecord::Migration[8.0]
  def change
    change_column_null :votes, :project_id, true
  end
end
