class AddUnlockedColorsToMeeples < ActiveRecord::Migration[8.0]
  def change
    add_column :meeples, :unlocked_colors, :json, default: [ "blue", "red", "green", "purple" ], null: false

    # Update existing meeples to have the default unlocked colors
    reversible do |dir|
      dir.up do
        Meeple.update_all(unlocked_colors: [ "blue", "red", "green", "purple" ])
      end
    end
  end
end
