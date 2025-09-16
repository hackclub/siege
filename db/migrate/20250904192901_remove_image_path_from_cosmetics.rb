class RemoveImagePathFromCosmetics < ActiveRecord::Migration[8.0]
  def change
    remove_column :cosmetics, :image_path, :string
  end
end
