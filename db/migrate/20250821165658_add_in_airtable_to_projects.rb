class AddInAirtableToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :in_airtable, :boolean, default: false, null: false
  end
end
