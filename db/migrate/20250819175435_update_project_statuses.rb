class UpdateProjectStatuses < ActiveRecord::Migration[8.0]
  def up
    # Update existing project statuses to new names
    execute "UPDATE projects SET status = 'pending_voting' WHERE status = 'pending'"
    execute "UPDATE projects SET status = 'finished' WHERE status = 'approved'"
  end

  def down
    # Revert back to old status names
    execute "UPDATE projects SET status = 'pending' WHERE status = 'pending_voting'"
    execute "UPDATE projects SET status = 'approved' WHERE status = 'finished'"
  end
end
