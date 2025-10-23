class AddRuneTrackingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :ruby_unlocked, :boolean, default: false, null: false
    add_column :users, :emerald_unlocked, :boolean, default: false, null: false
    add_column :users, :amethyst_unlocked, :boolean, default: false, null: false
    add_column :users, :current_runes, :string, default: "", null: false
  end
end
