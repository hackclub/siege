class AddPersonalDetailsToAddresses < ActiveRecord::Migration[8.0]
  def change
    add_column :addresses, :first_name, :string
    add_column :addresses, :last_name, :string
    add_column :addresses, :birthday, :date
    add_column :addresses, :shipping_name, :string
  end
end
