class AddTimeOverrideDaysToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :time_override_days, :integer, default: nil
  end
end
