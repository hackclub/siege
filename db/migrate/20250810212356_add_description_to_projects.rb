class AddDescriptionToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :description, :string, null: false
  end
end
