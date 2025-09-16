class AddIsUpdateToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :is_update, :boolean, default: false
  end
end
