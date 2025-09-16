class MakeStateOptionalInAddresses < ActiveRecord::Migration[8.0]
  def change
    change_column_null :addresses, :state, true
  end
end
