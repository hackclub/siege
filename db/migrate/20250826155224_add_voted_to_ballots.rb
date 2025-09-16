class AddVotedToBallots < ActiveRecord::Migration[8.0]
  def change
    add_column :ballots, :voted, :boolean, default: false, null: false
  end
end
