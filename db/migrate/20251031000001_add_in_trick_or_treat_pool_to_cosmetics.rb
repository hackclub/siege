class AddInTrickOrTreatPoolToCosmetics < ActiveRecord::Migration[8.0]
  def change
    add_column :cosmetics, :in_trick_or_treat_pool, :boolean, default: false, null: false
  end
end
