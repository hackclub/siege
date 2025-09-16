class CreateMeepleCosmetics < ActiveRecord::Migration[8.0]
  def change
    create_table :meeple_cosmetics do |t|
      t.references :meeple, null: false, foreign_key: true
      t.references :cosmetic, null: false, foreign_key: true
      t.boolean :unlocked, default: false
      t.boolean :equipped, default: false

      t.timestamps
    end

    add_index :meeple_cosmetics, [ :meeple_id, :cosmetic_id ], unique: true
    add_index :meeple_cosmetics, :unlocked
    add_index :meeple_cosmetics, :equipped
  end
end
