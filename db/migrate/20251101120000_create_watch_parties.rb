class CreateWatchParties < ActiveRecord::Migration[8.0]
  def change
    create_table :watch_parties do |t|
      t.string :title
      t.float :current_time, default: 0.0
      t.boolean :is_playing, default: false
      t.datetime :last_updated_at

      t.timestamps
    end
  end
end
