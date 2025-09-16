class RemoveUniqueIndexFromProjectsUserId < ActiveRecord::Migration[8.0]
  def change
    remove_index :projects, column: :user_id, unique: true
    add_index :projects, :user_id
  end
end
