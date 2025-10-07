class CreateUserWeeks < ActiveRecord::Migration[8.0]
  def change
    create_table :user_weeks do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :week, null: false
      t.references :project, null: true, foreign_key: true
      t.integer :arbitrary_offset, null: false, default: 0
      t.integer :mercenary_offset, null: false, default: 0

      t.timestamps
    end

    add_index :user_weeks, [:user_id, :week], unique: true
    add_index :user_weeks, :week
    add_index :user_weeks, :project_id
  end
end
