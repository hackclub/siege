class CreateMystereepleShopItems < ActiveRecord::Migration[8.0]
  def change
    create_table :mystereeple_shop_items do |t|
      t.string :name, null: false
      t.text :description
      t.integer :cost, default: 0, null: false
      t.integer :limit, null: false
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end

    add_index :mystereeple_shop_items, :name
    add_index :mystereeple_shop_items, :enabled
  end
end
