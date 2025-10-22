class CreateMystereepleWindows < ActiveRecord::Migration[8.0]
  def change
    create_table :mystereeple_windows do |t|
      t.string :name, null: false
      t.string :window_type, null: false
      t.json :days_available, default: [], null: false
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end

    add_index :mystereeple_windows, :window_type
    add_index :mystereeple_windows, :enabled
  end
end
