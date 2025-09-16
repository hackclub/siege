class CreateCosmetics < ActiveRecord::Migration[8.0]
  def change
    create_table :cosmetics do |t|
      t.string :image_path, null: false
      t.string :name, null: false
      t.text :description
      t.string :type, null: false

      t.timestamps
    end

    add_index :cosmetics, :type
  end
end
