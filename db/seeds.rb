# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Mystereeple Windows
[
  { name: 'Betting Window', window_type: 'betting', days_available: [1, 2, 3, 4], enabled: false },
  { name: 'Shop Window', window_type: 'shop', days_available: [5, 6], enabled: false },
  { name: 'Merch Raffle', window_type: 'raffle', days_available: [1, 2, 3, 4], enabled: false },
  { name: 'Secret Window', window_type: 'secret', days_available: [], enabled: false }
].each do |window_attrs|
  MystereepleWindow.find_or_create_by!(window_type: window_attrs[:window_type]) do |window|
    window.name = window_attrs[:name]
    window.days_available = window_attrs[:days_available]
    window.enabled = window_attrs[:enabled]
  end
end
