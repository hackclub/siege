class AddHiddenToProjects < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!
  
  def change
    add_column :projects, :hidden, :boolean, null: false, default: false
    add_index :projects, :hidden, algorithm: :concurrently
  end
end
