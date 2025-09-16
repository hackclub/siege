class CreatePhysicalItems < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!
  
  def change
    create_table :physical_items do |t|
      t.string :name, null: false
      t.text :description
      t.integer :cost, null: false, default: 0
      t.boolean :purchasable, null: false, default: true

      t.timestamps
    end

    add_index :physical_items, :name, algorithm: :concurrently
    add_index :physical_items, :purchasable, algorithm: :concurrently
  end
end
