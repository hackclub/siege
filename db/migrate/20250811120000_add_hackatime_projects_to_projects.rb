class AddHackatimeProjectsToProjects < ActiveRecord::Migration[7.1]
  def change
    # Use PostgreSQL's native JSON column type. Default to empty array.
    add_column :projects, :hackatime_projects, :json, default: []
  end
end
