class CreateHackatimeDays < ActiveRecord::Migration[8.0]
  def change
    create_table :hackatime_days do |t|
      t.date :date, null: false
      t.float :total_hours, default: 0.0, null: false
      t.json :user_ids, default: []

      t.timestamps
    end

    add_index :hackatime_days, :date, unique: true
  end
end
