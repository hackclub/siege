class CreateMeeplesForExistingUsers < ActiveRecord::Migration[8.0]
  def up
    User.find_each do |user|
      unless user.meeple.present?
        user.create_meeple(color: 'blue', cosmetics: [])
      end
    end
  end

  def down
    Meeple.destroy_all
  end
end
