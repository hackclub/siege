class SeedMystereepleWindows < ActiveRecord::Migration[8.0]
  def up
    MystereepleWindow.create([
      {
        name: 'Betting Window',
        window_type: 'betting',
        days_available: [1, 2, 3, 4], # Monday through Thursday
        enabled: true
      },
      {
        name: 'Shop Window',
        window_type: 'shop',
        days_available: [5, 6], # Friday and Saturday
        enabled: true
      }
    ])
  end

  def down
    MystereepleWindow.where(window_type: ['betting', 'shop']).destroy_all
  end
end
