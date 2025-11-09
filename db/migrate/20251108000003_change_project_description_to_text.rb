class ChangeProjectDescriptionToText < ActiveRecord::Migration[8.0]
  def change
    change_column :projects, :description, :text, null: false
  end
end
