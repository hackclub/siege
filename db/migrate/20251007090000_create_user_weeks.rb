class CreateUserWeeks < ActiveRecord::Migration[8.0]
  def change
    create_table :user_weeks, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: true, foreign_key: true
      t.integer :week, null: false
      t.integer :arbitrary_offset, null: false, default: 0
      t.integer :mercenary_offset, null: false, default: 0

      t.timestamps
    end

    add_index :user_weeks, [:user_id, :week], unique: true, if_not_exists: true
    add_index :user_weeks, :week, if_not_exists: true
    add_index :user_weeks, :project_id, if_not_exists: true
  end
end
