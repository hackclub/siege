class AddDigitalToPhysicalItems < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!
  
  def change
    add_column :physical_items, :digital, :boolean, default: false, null: false
    add_index :physical_items, :digital, algorithm: :concurrently
  end
end
