class MakeStateInAddressesMandatory < ActiveRecord::Migration[8.0]
  def change
    change_column_null :addresses, :state, false
  end
end
