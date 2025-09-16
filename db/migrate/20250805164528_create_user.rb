class CreateUser < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :slack_id, null: false
      t.string :email
      t.string :name
      t.string :team_id
      t.string :team_name
      t.timestamps
    end

    add_index :users, :slack_id, unique: true
  end
end
