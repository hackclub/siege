class CreateMeeples < ActiveRecord::Migration[8.0]
  def change
    create_table :meeples do |t|
      t.references :user, null: false, foreign_key: true
      t.string :color

      t.timestamps
    end
  end
end
