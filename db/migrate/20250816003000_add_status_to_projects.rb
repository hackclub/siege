class AddStatusToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :status, :string, default: 'building', null: false
    add_index :projects, :status
  end
end
