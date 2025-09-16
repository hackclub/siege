class AddLogsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :logs, :json, default: [], null: false
  end
end
