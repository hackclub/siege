class CreateShopPurchases < ActiveRecord::Migration[8.0]
  def change
    create_table :shop_purchases do |t|
      t.references :user, null: false, foreign_key: true
      t.string :item_name, null: false
      t.integer :coins_spent, null: false
      t.datetime :purchased_at, null: false
      t.boolean :fulfilled, default: false, null: false

      t.timestamps
    end

    add_index :shop_purchases, [ :user_id, :purchased_at ]
    add_index :shop_purchases, :fulfilled
    add_index :shop_purchases, :item_name
  end
end
