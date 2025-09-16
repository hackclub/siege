class CreateBallots < ActiveRecord::Migration[8.0]
  def change
    create_table :ballots do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :week, null: false
      t.text :reasoning

      t.timestamps
    end

    add_index :ballots, [ :user_id, :week ], unique: true
  end
end
