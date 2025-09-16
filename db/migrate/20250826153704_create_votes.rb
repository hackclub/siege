class CreateVotes < ActiveRecord::Migration[8.0]
  def change
    create_table :votes do |t|
      t.references :ballot, null: false, foreign_key: true
      t.integer :week, null: false
      t.references :project, null: true, foreign_key: true
      t.boolean :voted, default: false
      t.integer :star_count, default: 0

      t.timestamps
    end

    # Allow multiple votes per project - no unique constraint
    # Each ballot can vote on multiple projects, and each project can receive multiple votes
    add_index :votes, [ :ballot_id, :project_id ]
  end
end
